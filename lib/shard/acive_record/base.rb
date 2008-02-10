module Shard
  module ActiveRecord
    module Base

      def included(model)
        model.extend ClassMethods
      end

      class ClassMethods
        def shard_by(group)
          @@shard_group = group.to_s
        end

        # We duck punch this method in AR's ConnectionSpecification mixin
        # so that the active_connection for a given model is shard-aware.
        def active_connection_name
          [@@shard_group, Shard.active_instance(@@shard_group), RAILS_ENV].join('_')
        end
      end
    end
  end
end