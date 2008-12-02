module DataFabric
  module Extensions
    def self.included(model)
      # Wire up ActiveRecord::Base
      model.extend ClassMethods
    end

    # Class methods injected into ActiveRecord::Base
    module ClassMethods
      def data_fabric(options)
        proxy = DataFabric::ConnectionProxy.new(self, options)
        ActiveRecord::Base.active_connections[name] = proxy

        raise ArgumentError, "data_fabric does not support ActiveRecord's allow_concurrency = true" if allow_concurrency
        DataFabric.log { "Creating data_fabric proxy for class #{name}" }
      end
    end
  end

  class ConnectionProxy
    def initialize(model_class, options)
      @model_class = model_class      
      @replicated  = options[:replicated]
      @shard_group = options[:shard_by]
      @prefix      = options[:prefix]
      @role        = 'slave' if @replicated

      @model_class.send :include, ActiveRecordConnectionMethods if @replicated
    end

    delegate :insert, :update, :delete, :create_table, :rename_table, :drop_table, :add_column, :remove_column, 
      :change_column, :change_column_default, :rename_column, :add_index, :remove_index, :initialize_schema_information,
      :dump_schema_information, :execute, :execute_ignore_duplicate, :to => :master

    delegate :insert_many, :to => :master # ar-extensions bulk insert support

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

    def disconnect!
      if connected?
        connection.disconnect! 
        cached_connections[connection_name] = nil
      end
    end

    def verify!(arg)
      connection.verify!(arg) if connected?
    end

    def with_master
      # Allow nesting of with_master.
      old_role = @role
      set_role('master')
      yield
    ensure
      set_role(old_role)
    end

  private

    def cached_connections
      @cached_connections ||= {}
    end

    def connection_name_builder
      @connection_name_builder ||= begin
        clauses = []
        clauses << @prefix if @prefix
        clauses << @shard_group if @shard_group
        clauses << StringProxy.new { DataFabric.active_shard(@shard_group) } if @shard_group
        clauses << RAILS_ENV
        clauses << StringProxy.new { @role } if @replicated
        clauses
      end
    end

    def connection
      name = connection_name
      if not connected?
        config = ActiveRecord::Base.configurations[name]
        raise ArgumentError, "Unknown database config: #{name}, have #{ActiveRecord::Base.configurations.inspect}" unless config
        DataFabric.log { "Connecting to #{name}" }
        @model_class.establish_connection(config)
        cached_connections[name] = @model_class.connection
        @model_class.active_connections[@model_class.name] = self
      end
      cached_connections[name].verify!(3600)
      cached_connections[name]
    end

    def connected?
      DataFabric.shard_active_for?(@shard_group) and cached_connections[connection_name]
    end

    def set_role(role)
      @role = role if @replicated
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