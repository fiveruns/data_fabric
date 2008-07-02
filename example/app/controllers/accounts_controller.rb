class AccountsController < ApplicationController
  layout 'application'

  def index
    @accounts = Account.find(:all)
  end
  
  def choose
    @account = Account.find(params[:id])
    if @account
      session[:account_id] = @account.id
      flash[:notice] = "Selected account: #{@account.name}"
    end
    redirect_to '/'
  end
  
  def create
    Account.create!(params[:acct])
    flash[:notice] = "Account created successfully"
    redirect_to '/'
  end
end
