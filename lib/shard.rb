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
    def shard_by(group)
      @shard_group = group.to_s
    end

    # We duck punch this method in AR's ConnectionSpecification mixin
    # so that the active_connection for a given model is shard-aware.
    def connection
      acn = active_connection_name
      puts acn
      if conn = active_connections[acn]
        conn
      else
        # retrieve_connection sets the cache key.
        conn = retrieve_connection
        active_connections[acn] = conn
      end
    end

    def active_connection_name
      [@shard_group, Shard.active_instance(@shard_group), RAILS_ENV].join('_')
    end
  end
end