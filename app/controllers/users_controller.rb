class UsersController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    normalized_email = @user.email&.downcase&.strip

    if normalized_email && User.exists?(email: normalized_email)
      flash[:alert] = "An account with this email already exists."
      render :new, status: :unprocessable_content
    elsif @user.save
      flash[:notice] = "Account created successfully!"
      redirect_to root_path
    else
      flash[:alert] = @user.errors.full_messages.join(", ")
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
