class SessionsController < ApplicationController
  def new
  end

  def create
    normalized_email = params[:email]&.downcase&.strip
    user = User.find_by(email: normalized_email)

    if user.nil?
      flash[:alert] = "No account found with this email."
      render :new, status: :unprocessable_content
    elsif user.authenticate(params[:password])
      session[:user_id] = user.id
      flash[:notice] = "Signed in successfully!"
      redirect_to root_path
    else
      flash[:alert] = "Incorrect password."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    session[:user_id] = nil
    flash[:notice] = "Signed out successfully!"
    redirect_to root_path
  end
end
