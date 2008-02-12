require File.join(File.dirname(__FILE__), 'test_helper')
require 'flexmock/test_unit'

class PrefixModel < ActiveRecord::Base
  connection_topology :prefix => 'prefix'
end

class ShardModel < ActiveRecord::Base
  connection_topology :shard_by => :city
end

class AdapterMock < ActiveRecord::ConnectionAdapters::AbstractAdapter
end

class ConnectionTest < Test::Unit::TestCase

  def test_should_install_into_arbase
    assert PrefixModel.methods.include?('connection_topology')
  end
  
  def test_prefix_connection_name
    setup_configuration_for 'prefix_test'
    assert_equal 'prefix_test', PrefixModel.connection.connection_name
  end
  
  def test_shard_connection_name
    setup_configuration_for 'city_austin_test'
    assert_raises ArgumentError do
      ShardModel.connection.connection_name
    end
    DataFabric.activate_shard(:city, 'austin') do
      assert_equal 'city_austin_test', ShardModel.connection.connection_name
    end
  end
  
  private
  
  def setup_configuration_for(name)
    flexmock(PrefixModel).should_receive(:mysql_connection).and_return(AdapterMock.new(nil))
    ActiveRecord::Base.configurations = { name => { :adapter => 'mysql', :database => name, :host => 'localhost'} }
  end
end