require 'active_record'

module Shard

  def self.activate(group, instance)
    Thread.current[:shards] = {} unless Thread.current[:shards]
    Thread.current[:shards][group.to_s] = instance
  end
  
  def self.active_instance(group)
    Thread.current[:shards] = {} unless Thread.current[:shards]
    Thread.current[:shards][group.to_s]
  end
  
  def self.included(model)
    model.extend ClassMethods
  end

  def self.init
    ActiveRecord::Base.send(:include, Shard)
  end

  module ClassMethods
    def connection_topology(options)
      @replicated = options[:replicated] == true
      @sharded = options[:sharded] == true
    end
    def shard_by(group, options)
      @shard_group = group.to_s
    end

    def active_connection_name
      [@shard_group, Shard.active_instance(@shard_group), RAILS_ENV].join('_')
    end
  end
end

class ConnectionProxy
  def initialize(master, slave)
    @slave   = slave.connection
    @master  = master.connection
    @current = @slave
  end
  
  attr_accessor :slave, :master

  def self.setup!
    setup_for ActiveReload::MasterDatabase
  end
  
  def self.setup_for(master, slave = nil)
    slave ||= ActiveRecord::Base
    slave.send :include, ActiveRecordConnectionMethods
    ActiveRecord::Base.active_connections[slave.name] = new(master, slave)
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
