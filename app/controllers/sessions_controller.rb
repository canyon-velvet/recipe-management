class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create ]
  # Per address, and per account, so guessing one account's password from many addresses is slowed down too. (Someone
  # typing wrong passwords for an account holds its owner up as well, for up to 15 minutes.)
  rate_limit to: 10, within: 3.minutes, only: :create, with: :too_many_attempts
  rate_limit to: 10, within: 15.minutes, only: :create, with: :too_many_attempts,
             name: "username", by: -> { params[:username].to_s.strip.downcase }

  def new
  end

  def create
    user = User.find_by("LOWER(username) = ?", params[:username].to_s.downcase)
    if user&.authenticate(params[:password])
      log_in(user)
      redirect_to root_path, notice: t("flash.logged_in")
    else
      flash.now[:alert] = t("flash.invalid_login")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session_keeping_locale
    redirect_to login_path, notice: t("flash.logged_out")
  end

  private

  def too_many_attempts = redirect_to(login_path, alert: t("flash.rate_limited"))
end
