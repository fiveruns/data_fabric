class Figment < ActiveRecord::Base
	data_fabric :shard_by => 'shard', :replicated => false
	belongs_to :account
end
