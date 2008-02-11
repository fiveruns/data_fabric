require 'active_record'

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
# Since sharding is an application-level concern, your application must set the shard to use based on the current request or environment.  The current shard for a group is set on a thread local variable.  For example, you can set the shard in an ActionController begin_filter based on the user as follows:
# 
# class ApplicationController < ActionController::Base
#   begin_filter :select_shard
#   
#   private
#   def select_shard
#     DataFabric.activate_shard(:city, @current_user.city)
#   end
# end
module DataFabric

  def self.activate_shard(group, instance)
    Thread.current[:shards] = {} unless Thread.current[:shards]
    Thread.current[:shards][group.to_s] = instance
  end
  
  def self.active_shard(group)
    raise ArgumentException, 'No shard has been activated' unless Thread.current[:shards]

    returning(Thread.current[:shards][group.to_s]) do |shard|
      raise ArgumentError, "No active shard for #{group}" unless shard
    end
  end
  
  def self.included(model)
    model.extend ClassMethods
  end

  def self.init
    ActiveRecord::Base.send(:include, DataFabric)
  end

  module ClassMethods
    def connection_topology(options)
      ActiveRecord::Base.active_connections[name] = DataFabric::ConnectionProxy.new(self, options)
    end
  end
  
  class InstanceProxy
    def to_s
      DataFabric.active_shard(@shard_group)
    end
  end

  class ConnectionProxy
    def initialize(model_class, options)
      @replicated = Boolean(options[:replicated])
      @shard_group = options[:shard_by]
      @prefix = options[:name]
      model_class.send :include, ActiveRecordConnectionMethods
      @current = ActiveRecord::Base.configurations[current_connection_name]
    end
    
    def current_connection_name
      clauses = []
      clauses << @prefix if @prefix
      clauses << @shard_group if @shard_group
      clauses << instance_proxy if @shard_group
      clauses << RAILS_ENV
      clauses << role_proxy if @replicated
    end
    
    def instance_proxy
      
    end
    
    def master
      @current
    end
  
    def with_master
      set_to_master!
      yield
    ensure
      set_to_slave!
    end

    def set_to_master!
      @current = @master
    end
  
    def set_to_slave!
      @current = @slave
    end
  
    delegate :insert, :update, :delete, :create_table, :rename_table, :drop_table, :add_column, :remove_column, 
      :change_column, :change_column_default, :rename_column, :add_index, :remove_index, :initialize_schema_information,
      :dump_schema_information, :to => :master
  
    def transaction(start_db_transaction = true, &block)
      with_master { @current.transaction(start_db_transaction, &block) }
    end

    def method_missing(method, *args, &block)
      @current.send(method, *args, &block)
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