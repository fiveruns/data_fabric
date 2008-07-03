require 'test_helper'

class AccountsControllerTest < ActionController::TestCase
  fixtures :accounts
  
  def test_index
    get :index
    assert_response :success
    assert assigns(:accounts)
    assert_equal 4, assigns(:accounts).size
  end
end
