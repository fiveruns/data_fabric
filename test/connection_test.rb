require File.join(File.dirname(__FILE__), 'test_helper')
require 'flexmock/test_unit'

class PrefixModel < ActiveRecord::Base
  connection_topology :prefix => 'prefix'
end

class ShardModel < ActiveRecord::Base
  connection_topology :shard_by => :city
end

class TheWholeEnchilada < ActiveRecord::Base
  connection_topology :prefix => 'fiveruns', :replicated => true, :shard_by => :city
end

class AdapterMock < ActiveRecord::ConnectionAdapters::AbstractAdapter
  # Minimum required to perform a find with no results
  def columns(table_name, name=nil)
    []
  end
  def select(sql, name = nil)
    []
  end
end

class ConnectionTest < Test::Unit::TestCase

  def test_should_install_into_arbase
    assert PrefixModel.methods.include?('connection_topology')
  end
  
  def test_prefix_connection_name
    setup_configuration_for PrefixModel, 'prefix_test'
    assert_equal 'prefix_test', PrefixModel.connection.connection_name
  end
  
  def test_shard_connection_name
    setup_configuration_for ShardModel, 'city_austin_test'
    # ensure unset means error
    assert_raises ArgumentError do
      ShardModel.connection.connection_name
    end
    DataFabric.activate_shard(:city, 'austin') do
      assert_equal 'city_austin_test', ShardModel.connection.connection_name
    end
    # ensure it got unset
    assert_raises ArgumentError do
      ShardModel.connection.connection_name
    end
  end
  
  def test_enchilada
    setup_configuration_for TheWholeEnchilada, 'fiveruns_city_dallas_test_slave'
    DataFabric.activate_shard :city, :dallas do
      assert_equal 'fiveruns_city_dallas_test_slave', TheWholeEnchilada.connection.connection_name
      assert_raises ActiveRecord::RecordNotFound do
        TheWholeEnchilada.find(1)
      end
    end
  end

  private
  
  def setup_configuration_for(clazz, name)
    flexmock(clazz).should_receive(:mysql_connection).and_return(AdapterMock.new(nil))
    ActiveRecord::Base.configurations = { name => { :adapter => 'mysql', :database => name, :host => 'localhost'} }
  end
end