module Shard
  module ActiveRecord
    module Base
      class ClassMethods
        def uses_shard(group)
          @@shard = group.to_s
        end

        # We duck punch this method in AR's ConnectionSpecification mixin
        # so that the active_connection for a given model is shard-aware.
        def active_connection_name
          [@@shard, Shard.active_instance(@@shard), RAILS_ENV].join('_')
        end
      end
      
      class InstanceMethods
      end
    end
  end
end