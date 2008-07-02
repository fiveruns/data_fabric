class FigmentsController < ApplicationController
  
  def create
    @account.figments.create!(params[:figment])
    flash[:notice] = "Figment created"
    redirect_to '/'
  end
end
