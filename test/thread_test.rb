require File.join(File.dirname(__FILE__), 'test_helper')
require 'erb'

class ThreadTest < Test::Unit::TestCase
  
  MUTEX = Mutex.new
  
  def test_concurrency_not_allowed
    assert_raise ArgumentError do
      Object.class_eval %{
        class ThreadedEnchilada < ActiveRecord::Base
          self.allow_concurrency = true
          set_table_name :enchiladas
          connection_topology :prefix => 'fiveruns', :replicated => true, :shard_by => :city
        end
      }
    end
  end
  
  def xtest_class_and_instance_connections
    filename = File.join(File.dirname(__FILE__), "database.yml")
    ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read(filename)).result)

    cconn = ThreadedEnchilada.connection
    iconn = ThreadedEnchilada.new.connection
    assert_equal cconn, iconn
  end
  
  def xtest_threaded_access
    clear_databases

    filename = File.join(File.dirname(__FILE__), "database.yml")
    ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read(filename)).result)

    counts = {:austin => 0, :dallas => 0}
    threads = []
    10.times do
      threads << Thread.new do
        begin
          200.times do
            city = rand(1_000_000) % 2 == 0 ? :austin : :dallas
            DataFabric.activate_shard :city => city do
              #puts Enchilada.connection.to_s
              #assert_equal "fiveruns_city_#{city}_test_slave", Enchilada.connection.connection_name
              ThreadedEnchilada.create!(:name => "#{city}")
              MUTEX.synchronize do
                counts[city] += 1
              end
            end
          end
        rescue => e
          puts e.message
          puts e.backtrace.join("\n\t")
        end
      end
    end
    threads.each { |thread| thread.join }
    
    counts.each_pair do |city, count| 
      DataFabric.activate_shard(:city => city) do
        # slave should be empty
        #assert_equal "fiveruns_city_#{city}_test_slave", ThreadedEnchilada.connection.connection_name
        assert_equal 0, ThreadedEnchilada.count
        ThreadedEnchilada.transaction do
          #assert_equal "fiveruns_city_#{city}_test_master", Enchilada.connection.connection_name
          # master should have the counts we expect
          assert_equal count, ThreadedEnchilada.count
        end
      end
    end
  end
  
  private
  
  def clear_databases
    ActiveRecord::Base.configurations = { 'test' => { :adapter => 'mysql', :host => 'localhost', :database => 'mysql' } }
    ActiveRecord::Base.establish_connection 'test'
    databases = %w( vr_austin_master vr_austin_slave vr_dallas_master vr_dallas_slave )
    databases.each do |db|
      using_connection do
        execute "use #{db}"
        execute "delete from the_whole_burritos"
      end
    end
    ActiveRecord::Base.clear_active_connections!
  end
  
  def using_connection(&block)
    ActiveRecord::Base.connection.instance_eval(&block)
  end
end