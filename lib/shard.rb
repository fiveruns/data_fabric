require 'active_record'

module Shard
  def activate(group, instance)
    Thread[:shards][group.to_s] = instance
  end
  
  def active_instance(group)
    Thread[:shards][group.to_s]
  end
end

ActiveRecord::Base.include(Shard::ActiveRecord::Base)