require File.join(File.dirname(__FILE__), 'test_helper')
require 'flexmock/test_unit'

class TestModel < ActiveRecord::Base
  shard_by :city
end

class ShardTest < Test::Unit::TestCase

  def test_should_install_into_arbase
    assert ActiveRecord::Base.methods.include?('shard_by')
  end
  
  def test_activation_should_persist_in_thread
    Shard.activate(:city, 'austin')
    assert_equal 'austin', Shard.active_instance(:city)
  end
  
  def test_activation_in_one_thread_does_not_change_another
    Shard.activate(:city, 'austin')

    Thread.new do
      assert_nil Shard.active_instance(:city)
      Shard.activate(:city, 'dallas')
      assert_equal 'dallas', Shard.active_instance(:city)
    end.join
  end
  
  def test_connection_name
#    ActiveRecord::Base.configurations = { 
#      'city_austin_test' => { :adapter => 'mysql', :host => 'localhost' },
#      'test' => { :adapter => 'mysql', :host => 'somewhere-else' }
#    }
#    ActiveRecord::Base.establish_connection
    Shard.activate(:city, 'austin')
    TestModel.find(1)
  end

end