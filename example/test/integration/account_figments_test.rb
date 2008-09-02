require 'test_helper'

class AccountFigmentsTest < ActionController::IntegrationTest

  def test_create_account_and_figments
    conn0 = db_connection "shard_0_test"
    conn1 = db_connection "shard_1_test"
    conn0.clear 'figments'
    conn1.clear 'figments'
    assert_equal 0, conn0.count_for('figments')
    assert_equal 0, conn1.count_for('figments')

    new_session(0) do |user|
      user.goes_home
      mike = user.creates_account('mike', '0')
      user.selects_account(mike)
      before = mike.figments.size
      user.creates_figment(14)
      mike.figments.reload
      assert_equal before + 1, mike.figments.size
      assert_equal 14, mike.figments.first.value
    end

    # Bypass data_fabric and verify the figment went to shard 0.
    assert_equal 1, conn0.count_for('figments')
    assert_equal 0, conn1.count_for('figments')

    new_session(1) do |user|
      user.goes_home
      bob = user.creates_account('bob', '1')
      user.selects_account(bob)
      before = bob.figments.size
      user.creates_figment(66)
      bob.figments.reload
      assert_equal before + 1, bob.figments.size
      assert_equal 66, bob.figments.first.value
    end

    # Bypass data_fabric and verify the figment went to shard 1.
    assert_equal 1, conn0.count_for('figments')
    assert_equal 1, conn1.count_for('figments')
  end

  private
  
  def db_connection(conf)
    conn = ActiveRecord::Base.sqlite3_connection(HashWithIndifferentAccess.new(ActiveRecord::Base.configurations[conf]))
    def conn.count_for(table)
      Integer(execute("select count(*) as c from #{table}")[0]['c'])
    end
    def conn.clear(table)
      execute("delete from #{table}")
    end
    conn
  end

  def new_session(shard)
    open_session do |sess|
      DataFabric.activate_shard :shard => shard do
        sess.extend(Operations)
        yield sess if block_given?
      end
    end
  end

  module Operations
    def goes_home
      get accounts_path
      assert_response :success
    end

    def creates_account(name, shard)
      post accounts_path, :acct => { :name => name, :shard => shard }
      assert_response :redirect
      follow_redirect!
      assert_response :success
      assert_template "accounts/index"
      Account.find_by_name(name)
    end

    def selects_account(account)
      get choose_account_path(account)
      assert_response :redirect
      follow_redirect!
      assert_response :success
      assert_template "accounts/index"
    end
    
    def creates_figment(value)
      post figments_path, :figment => { :value => value }
      assert_response :redirect
      follow_redirect!
      assert_response :success
      assert_template "accounts/index"
    end
  end
end