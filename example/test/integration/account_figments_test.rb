require 'test_helper'

class AccountFigmentsTest < ActionController::IntegrationTest

  def test_create_account_and_figments
    conn0 = db_connection "shard_0_test"
    conn1 = db_connection "shard_1_test"
    assert_equal 0, conn0.count_for('figments')
    assert_equal 0, conn1.count_for('figments')

    new_session do |user|
      user.goes_home
      mike = user.creates_account('mike', '0')
      user.selects_account(mike)
      before = mike.figments.size
      user.creates_figment(14)
      mike.figments.reload!
      assert_equal before + 1, mike.figments.size
      assert_equal 14, mike.figments.first.value
    end

    # Bypass data_fabric and verify the table contents.
    assert_equal 1, conn0.count_for('figments')
    assert_equal 0, conn1.count_for('figments')
  end

  private
  
  def db_connection(conf)
    conn = ActiveRecord::Base.sqlite3_connection(HashWithIndifferentAccess.new(ActiveRecord::Base.configurations[conf]))
    def conn.count_for(table)
      Integer(execute("select count(*) as c from #{table}")[0]['c'])
    end
    conn
  end

  def new_session
    open_session do |sess|
      sess.extend(Operations)
      yield sess if block_given?
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

    def uploads_photo(user)
      assert_nil user.photo
      multipart_post user_url(accounts(:fiveruns), user), {:hidden_user_id => user.id, :_method => :put, :user => {:photo_data => fixture_file_upload("/photos/sam.jpg", "image/jpeg")}}
      assert_response :redirect
      follow_redirect!
      assert_response :success
      assert_template "users/show"

      user = User.find(user.id)
      assert_not_nil user.photo
      assert_not_nil user.photo.current_data
      assert_select 'img[alt=Photo]', {:count => 1} do
        assert_select "[src=?]", /^\/a\/fiveruns\/users\/[\d]+\/photo\?[\d]+$/
      end
    end

    def removes_photo(user)
      user = User.find(user.id)

      assert_not_nil user.photo
      post user_photo_url(accounts(:fiveruns), user), {:_method => :delete}
      assert_response :redirect
      follow_redirect!
      assert_response :success
      assert_template "users/edit"

      user = User.find(user.id)
      assert_nil user.photo

      assert_photo_is_nil
    end

    def assert_photo_is_nil
      assert_select 'img[alt=Photo]', {:count => 1} do
        assert_select "[src=?]", /^\/a\/fiveruns\/users\/[\d]+\/photo\?[\d]+$/
      end
    end
  end
end