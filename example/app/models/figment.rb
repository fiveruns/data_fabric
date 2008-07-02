class Figment < ActiveRecord::Base
	connection_topology :shard_by => 'shard', :replicated => true
	belongs_to :account
end
