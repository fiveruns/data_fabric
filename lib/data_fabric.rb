require 'active_record'
require 'active_record/version'
require 'data_fabric/version'

# DataFabric adds a new level of flexibility to ActiveRecord connection handling.
# You need to describe the topology for your database infrastructure in your model(s).  As with ActiveRecord normally, different models can use different topologies.
# 
# class MyHugeVolumeOfDataModel < ActiveRecord::Base
#   data_fabric :replicated => true, :shard_by => :city
# end
# 
# There are four supported modes of operation, depending on the options given to the data_fabric method.  The plugin will look for connections in your config/database.yml with the following convention:
# 
# No connection topology:
# #{environment} - this is the default, as with ActiveRecord, e.g. "production"
# 
# data_fabric :replicated => true
# #{environment}_#{role} - no sharding, just replication, where role is "master" or "slave", e.g. "production_master"
# 
# data_fabric :shard_by => :city
# #{group}_#{shard}_#{environment} - sharding, no replication, e.g. "city_austin_production"
# 
# data_fabric :replicated => true, :shard_by => :city
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

  # Set this logger to log DataFabric operations.
  # The logger should quack like a standard Ruby Logger.
  mattr_accessor :logger

  def self.init
    logger = ActiveRecord::Base.logger unless logger
    log { "Loading data_fabric #{DataFabric::Version::STRING} with ActiveRecord #{ActiveRecord::VERSION::STRING}" }
    ActiveRecord::Base.send(:include, self)
  end
  
  def self.activate_shard(shards, &block)
    ensure_setup

    # Save the old shard settings to handle nested activation
    old = Thread.current[:shards].dup

    shards.each_pair do |key, value|
      Thread.current[:shards][key.to_s] = value.to_s
    end
    if block_given?
      begin
        yield
      ensure
        Thread.current[:shards] = old
      end
    end
  end
  
  # For cases where you can't pass a block to activate_shards, you can
  # clean up the thread local settings by calling this method at the
  # end of processing
  def self.deactivate_shard(shards)
    ensure_setup
    shards.each do |key, value|
      Thread.current[:shards].delete(key.to_s)
    end
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

  def self.log(level=Logger::INFO, &block)
    logger && logger.add(level, &block)
  end

  # Class methods injected into ActiveRecord::Base
  module ClassMethods
    def data_fabric(options)
      proxy = DataFabric::ConnectionProxy.new(self, options)
      ActiveRecord::Base.active_connections[name] = proxy
      
      raise ArgumentError, "data_fabric does not support ActiveRecord's allow_concurrency = true" if allow_concurrency
      DataFabric.log { "Creating data_fabric proxy for class #{name}" }
    end
    alias :connection_topology :data_fabric # legacy
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
      @replicated  = options[:replicated]
      @shard_group = options[:shard_by]
      @prefix      = options[:prefix]
      @role        = 'slave' if @replicated

      @model_class.send :include, ActiveRecordConnectionMethods if @replicated
    end
    
    delegate :insert, :update, :delete, :create_table, :rename_table, :drop_table, :add_column, :remove_column, 
      :change_column, :change_column_default, :rename_column, :add_index, :remove_index, :initialize_schema_information,
      :dump_schema_information, :execute, :execute_ignore_duplicate, :to => :master
    
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
      cached_connections[connection_name]
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
end
