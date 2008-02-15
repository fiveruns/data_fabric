require File.join(File.dirname(__FILE__), 'test_helper')

class ShardTest < Test::Unit::TestCase

  def test_activation_should_persist_in_thread
    DataFabric.activate_shard(:city => 'austin')
    assert_equal 'austin', DataFabric.active_shard(:city)
  end
  
  def test_activation_in_one_thread_does_not_change_another
    assert_raises ArgumentError do
       DataFabric.active_shard(:city)
     end
    DataFabric.activate_shard(:city => 'austin')

    Thread.new do
      assert_raises ArgumentError do
         DataFabric.active_shard(:city)
       end
      DataFabric.activate_shard(:city => 'dallas')
      assert_equal 'dallas', DataFabric.active_shard(:city)
    end.join
  end
end