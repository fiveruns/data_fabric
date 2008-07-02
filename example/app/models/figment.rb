class Figment < ActiveRecord::Base
	connection_topology :shard_by => 'shard', :replicated => false
	belongs_to :account
end
