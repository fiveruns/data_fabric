require 'active_record'

# DataFabric adds a new level of flexibility to ActiveRecord connection handling.
# You need to describe the topology for your database infrastructure in your model(s).  As with ActiveRecord normally, different models can use different topologies.
# 
# class MyHugeVolumeOfDataModel < ActiveRecord::Base
#   connection_topology :replicated => true, :shard_by => :city
# end
# 
# There are four supported modes of operation, depending on the options given to the connection_topology method.  The plugin will look for connections in your config/database.yml with the following convention:
# 
# No connection topology:
# #{environment} - this is the default, as with ActiveRecord, e.g. "production"
# 
# connection_topology :replicated => true
# #{environment}_#{role} - no sharding, just replication, where role is "master" or "slave", e.g. "production_master"
# 
# connection_topology :shard_by => :city
# #{group}_#{shard}_#{environment} - sharding, no replication, e.g. "city_austin_production"
# 
# connection_topology :replicated => true, :shard_by => :city
# #{group}_#{shard}_#{environment}_#{role} - sharding with replication, e.g. "city_austin_production_master"
# 
# 
# When marked as replicated, all write and transactional operations for the model go to the master, whereas read operations go to the slave.
# 
# Since sharding is an application-level concern, your application must set the shard to use based on the current request or environment.  The current shard for a group is set on a thread local variable.  For example, you can set the shard in an ActionController around_filter based on the user as follows:
# 
# class ApplicationController < ActionController::Base
#   around_filter :select_shard
#   
#   private
#   def select_shard(&action_block)
#     DataFabric.activate_shard(:city => @current_user.city, &action_block)
#   end
# end
module DataFabric
  
  def self.init
    ActiveRecord::Base.send(:include, self)
  end
  
  def self.activate_shard(shards, &block)
    ensure_setup
    shards.each do |key, value|
      Thread.current[:shards][key.to_s] = value.to_s
    end
    if block_given?
      begin
        yield
      ensure
        shards.each do |key, value|
          Thread.current[:shards].delete(key.to_s)
        end
      end
    end
  end
  
  # For cases where you can't pass a block to activate_shards, you can
  # clean up the thread local settings by calling this method at the
  # end of processing
  def self.deactivate_shard(group)
    ensure_setup
    Thread.current[:shards].delete(group.to_s)
  end
  
  def self.active_shard(group)
    raise ArgumentError, 'No shard has been activated' unless Thread.current[:shards]

    returning(Thread.current[:shards][group.to_s]) do |shard|
      raise ArgumentError, "No active shard for #{group}" unless shard
    end
  end
  
  def self.included(model)
    # Wire up ActiveRecord::Base
    model.extend ClassMethods
  end

  def self.ensure_setup
    Thread.current[:shards] = {} unless Thread.current[:shards]
  end


  # Class methods injected into ActiveRecord::Base
  module ClassMethods
    def connection_topology(options)
      proxy = DataFabric::ConnectionProxy.new(self, options)
      ActiveRecord::Base.active_connections[name] = proxy
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

  class ConnectionProxy
    def initialize(model_class, options)
      @model_class = model_class      
      @replicated = options[:replicated]
      @shard_group = options[:shard_by]
      @prefix = options[:prefix]
      @current_role = 'slave' if @replicated
      @current_connection_name_builder = connection_name_builder
      @cached_connection = nil
      @current_connection_name = nil

      @model_class.send :include, ActiveRecordConnectionMethods if @replicated
    end

    delegate :insert, :update, :delete, :create_table, :rename_table, :drop_table, :add_column, :remove_column, 
      :change_column, :change_column_default, :rename_column, :add_index, :remove_index, :initialize_schema_information,
      :dump_schema_information, :to => :master
    
    def transaction(start_db_transaction = true, &block)
      with_master { raw_connection.transaction(start_db_transaction, &block) }
    end

    def method_missing(method, *args, &block)
      unless @cached_connection
        raw_connection
      end
      @cached_connection.send(method, *args, &block) 
    end
    
    def connection_name
      @current_connection_name_builder.join('_')
    end
    
    def disconnect!
      @cached_connection.disconnect! if @cached_connection
      @cached_connection = nil
    end
    
    def verify!(arg)
      @cached_connection.verify!(0) if @cached_connection
    end
    
    def with_master
      set_role('master')
      yield
    ensure
      set_role('slave')
    end

    private
    
    def connection_name_builder
      clauses = []
      clauses << @prefix if @prefix
      clauses << @shard_group if @shard_group
      clauses << StringProxy.new { DataFabric.active_shard(@shard_group) } if @shard_group
      clauses << RAILS_ENV
      clauses << StringProxy.new { @current_role } if @replicated
      clauses
    end
    
    def raw_connection
      conn_name = connection_name
      unless already_connected_to? conn_name 
        @cached_connection = begin 
          config = ActiveRecord::Base.configurations[conn_name]
          raise ArgumentError, "Unknown database config: #{conn_name}, have #{ActiveRecord::Base.configurations.inspect}" unless config
          @model_class.establish_connection config
          @current_connection_name = conn_name
          conn = @model_class.connection
#          conn.verify! 0
          conn
        end
        @model_class.active_connections[@model_class.name] = self
      end
      @cached_connection
    end
    
    def already_connected_to?(conn_name)
      conn_name == @current_connection_name and @cached_connection
    end
    
    def set_role(role)
      if @replicated and @current_role != role
#        puts "Role: #{role}"
        @current_role = role
        @cached_connection = nil
      end
    end
    
    def master
      set_role('master')
      return raw_connection
    ensure
      set_role('slave')
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
end