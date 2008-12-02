require File.join(File.dirname(__FILE__), 'test_helper')
require 'flexmock/test_unit'
require 'erb'

class TheWholeBurrito < ActiveRecord::Base
  data_fabric :prefix => 'fiveruns', :replicated => true, :shard_by => :city
end

class DatabaseTest < Test::Unit::TestCase
  
  def setup
    ActiveRecord::Base.configurations = load_database_yml
    if ar22?
      DataFabric::ConnectionProxy.shard_pools.clear
    end
  end

  def test_ar22_features
    return unless ar22?

    DataFabric.activate_shard :city => :dallas do
      assert_equal 'fiveruns_city_dallas_test_slave', TheWholeBurrito.connection.connection_name

      assert_raises RuntimeError do
        TheWholeBurrito.connection_pool
      end

      assert !TheWholeBurrito.connected?

      # Should use the slave
      burrito = TheWholeBurrito.find(1)
      assert_match 'vr_dallas_slave', burrito.name

      assert TheWholeBurrito.connected?
    end
  end

  def test_live_burrito
    DataFabric.activate_shard :city => :dallas do
      assert_equal 'fiveruns_city_dallas_test_slave', TheWholeBurrito.connection.connection_name

      # Should use the slave
      burrito = TheWholeBurrito.find(1)
      assert_match 'vr_dallas_slave', burrito.name

      # Should use the master
      burrito.reload
      assert_match 'vr_dallas_master', burrito.name

      # ...but immediately set it back to default to the slave
      assert_equal 'fiveruns_city_dallas_test_slave', TheWholeBurrito.connection.connection_name

      # Should use the master
      TheWholeBurrito.transaction do
        burrito = TheWholeBurrito.find(1)
        assert_match 'vr_dallas_master', burrito.name
        burrito.name = 'foo'
        burrito.save!
      end
    end
  end
end
