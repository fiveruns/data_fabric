require 'test_helper'

class AccountsControllerTest < ActionController::TestCase
  fixtures :accounts
  
  # Replace this with your real tests.
  def test_index
    get :index
    assert_response 200
    assert assigns(:accounts)
  end
end
