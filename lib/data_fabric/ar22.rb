module DataFabric
  module Extensions
    def self.included(model)
      # Wire up ActiveRecord::Base
      model.extend ClassMethods
      ConnectionProxy.shard_pools = {}
    end

    # Class methods injected into ActiveRecord::Base
    module ClassMethods
      def data_fabric(options)
        DataFabric.log { "Creating data_fabric proxy for class #{name}" }
        @proxy = DataFabric::ConnectionProxy.new(self, options)
        
        class << self
          def connection
            @proxy
          end

          def connected?
            @proxy.connected?
          end

          def remove_connection(klass)
            raise "not implemented"
          end

          def connection_pool
            raise "dynamic connection switching means you cannot get direct access to a pool"
          end
        end
      end
    end
  end

  class ConnectionProxy
    cattr_accessor :shard_pools
    
    def initialize(model_class, options)
      @model_class = model_class      
      @replicated  = options[:replicated]
      @shard_group = options[:shard_by]
      @prefix      = options[:prefix]
      set_role('slave') if @replicated

      @model_class.send :include, ActiveRecordConnectionMethods if @replicated
    end

    delegate :insert, :update, :delete, :create_table, :rename_table, :drop_table, :add_column, :remove_column, 
      :change_column, :change_column_default, :rename_column, :add_index, :remove_index, :initialize_schema_information,
      :dump_schema_information, :execute, :execute_ignore_duplicate, :to => :master

    delegate :insert_many, :to => :master # ar-extensions bulk insert support

    def cache(&block)
      connection.cache(&block)
    end

    def transaction(start_db_transaction = true, &block)
      with_master { connection.transaction(start_db_transaction, &block) }
    end

    def method_missing(method, *args, &block)
      DataFabric.log(Logger::DEBUG) { "Calling #{method} on #{connection}" }
      connection.send(method, *args, &block)
    end

    def connection_name
      connection_name_builder.join('_')
    end

    def verify!(arg)
      connection.verify!(arg) if connected?
    end

    def with_master
      # Allow nesting of with_master.
      old_role = current_role
      set_role('master')
      yield
    ensure
      set_role(old_role)
    end
    
  private

    def current_pool
      name = connection_name
      self.class.shard_pools[name] ||= begin
        config = ActiveRecord::Base.configurations[name]
        raise ArgumentError, "Unknown database config: #{name}, have #{ActiveRecord::Base.configurations.inspect}" unless config
        ActiveRecord::ConnectionAdapters::ConnectionPool.new(spec_for(config))
      end
    end
    
    def spec_for(config)
      # XXX This looks pretty fragile.  Will break if AR changes how it initializes connections and adapters.
      config = config.symbolize_keys
      adapter_method = "#{config[:adapter]}_connection"
      initialize_adapter(config[:adapter])
      ActiveRecord::Base::ConnectionSpecification.new(config, adapter_method)
    end
    
    def initialize_adapter(adapter)
      begin
        require 'rubygems'
        gem "activerecord-#{adapter}-adapter"
        require "active_record/connection_adapters/#{adapter}_adapter"
      rescue LoadError
        begin
          require "active_record/connection_adapters/#{adapter}_adapter"
        rescue LoadError
          raise "Please install the #{adapter} adapter: `gem install activerecord-#{adapter}-adapter` (#{$!})"
        end
      end
    end      

    def connection_name_builder
      @connection_name_builder ||= begin
        clauses = []
        clauses << @prefix if @prefix
        clauses << @shard_group if @shard_group
        clauses << StringProxy.new { DataFabric.active_shard(@shard_group) } if @shard_group
        clauses << RAILS_ENV
        clauses << StringProxy.new { current_role } if @replicated
        clauses
      end
    end
    
    def connection
      current_pool.connection
    end

    def connected?
      DataFabric.shard_active_for?(@shard_group) and cached_connections[connection_name]
    end

    def set_role(role)
      Thread.current[:data_fabric_role] = role if @replicated
    end
    
    def current_role
      Thread.current[:data_fabric_role]
    end

    def master
      with_master { return connection }
    end
  end

  module ActiveRecordConnectionMethods
    def self.included(base)
      base.alias_method_chain :reload, :master
    end

    def reload_with_master(*args, &block)
      connection.with_master { reload_without_master }
    end
  end

  class StringProxy
    def initialize(&block)
      @proc = block
    end
    def to_s
      @proc.call
    end
  end
end