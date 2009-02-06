require File.join(File.dirname(__FILE__), 'test_helper')
require 'flexmock/test_unit'

class PrefixModel < ActiveRecord::Base
  data_fabric :prefix => 'prefix'
end

class ShardModel < ActiveRecord::Base
  data_fabric :shard_by => :city
end

class TheWholeEnchilada < ActiveRecord::Base
  data_fabric :prefix => 'fiveruns', :replicated => true, :shard_by => :city
end

class AdapterMock < ActiveRecord::ConnectionAdapters::AbstractAdapter
  # Minimum required to perform a find with no results
   def columns(table_name, name=nil)
     []
   end
   def select(sql, name=nil)
     []
   end
   def execute(sql, name=nil)
     0
   end
   
   def name
     'fake-db'
   end
  
   def method_missing(name, *args)
     raise ArgumentError, "#{self.class.name} missing '#{name}': #{args.inspect}"
   end
end

class RawConnection
  def method_missing(name, *args)
    puts "#{self.class.name} missing '#{name}': #{args.inspect}"
  end
end

class ConnectionTest < Test::Unit::TestCase

  def test_should_install_into_arbase
    # Ruby 1.8 vs 1.9 difference
    meth = PrefixModel.methods.first.is_a?(Symbol) ? :data_fabric : 'data_fabric'
    assert PrefixModel.methods.include?(meth)
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
    DataFabric.activate_shard(:city => 'austin', :category => 'art') do
      assert_equal 'city_austin_test', ShardModel.connection.connection_name
    end
    # ensure it got unset
    assert_raises ArgumentError do
      ShardModel.connection.connection_name
    end
  end
  
  def test_enchilada
    setup_configuration_for TheWholeEnchilada, 'fiveruns_city_dallas_test_slave'
    setup_configuration_for TheWholeEnchilada, 'fiveruns_city_dallas_test_master'
    DataFabric.activate_shard :city => :dallas do
      assert_equal 'fiveruns_city_dallas_test_slave', TheWholeEnchilada.connection.connection_name

      # Should use the slave
      assert_raises ActiveRecord::RecordNotFound do
        TheWholeEnchilada.find(1)
      end
      
      # Should use the master
      mmmm = TheWholeEnchilada.new
      mmmm.instance_variable_set(:@attributes, { 'id' => 1 })
      assert_raises ActiveRecord::RecordNotFound do
        mmmm.reload
      end
      # ...but immediately set it back to default to the slave
      assert_equal 'fiveruns_city_dallas_test_slave', TheWholeEnchilada.connection.connection_name
      
      # Should use the master
      TheWholeEnchilada.transaction do
        mmmm.save!
      end
    end
  end

  private
  
  def setup_configuration_for(clazz, name)
    if ar22?
      flexmock(ActiveRecord::ConnectionAdapters::ConnectionPool).new_instances.should_receive(:new_connection).and_return(AdapterMock.new(RawConnection.new))
    else
      flexmock(clazz).should_receive(:mysql_connection).and_return(AdapterMock.new(RawConnection.new))      
    end
    ActiveRecord::Base.configurations ||= HashWithIndifferentAccess.new
    ActiveRecord::Base.configurations[name] = HashWithIndifferentAccess.new({ :adapter => 'mysql', :database => name, :host => 'localhost'})
  end
end