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

    if ActiveRecord::VERSION::STRING < '2.2.0'
      require 'data_fabric/ar20'
    else
      require 'data_fabric/ar22'
    end
    ActiveRecord::Base.send(:include, DataFabric::Extensions)
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
  
  def self.shard_active_for?(group)
    return true unless group
    Thread.current[:shards] and Thread.current[:shards][group.to_s]
  end

  def self.ensure_setup
    Thread.current[:shards] = {} unless Thread.current[:shards]
  end

  def self.log(level=Logger::INFO, &block)
    logger && logger.add(level, &block)
  end

end
