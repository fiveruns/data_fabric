# A data_fabric recipe for use with the FiveRuns Dash metrics service at 
# http://dash.fiveruns.com.
#
# Hook into your Rails application by adding the recipe in your 
# config/initializers/dash.rb, like so:
#
# require 'data_fabric/dash'
# Fiveruns::Dash::Rails.start :production => 'your-token' do |config|
#   config.add_recipe :data_fabric, :url => 'http://mikeperham.com'
# end
#
raise ArgumentError, "The Dash recipe for DataFabric is only supported on ActiveRecord 2.2 and greater" if ActiveRecord::VERSION::STRING < '2.2.0'

Fiveruns::Dash.register_recipe :data_fabric, :url => 'http://mikeperham.com' do |recipe|
  recipe.absolute :open_connections, 'Open Connections' do
    DataFabric::ConnectionProxy.shard_pools.values.map do |pool|
      (pool.instance_variable_get(:@checked_out) || []).size
    end.sum
  end
end
