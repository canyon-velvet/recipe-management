class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create ]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to login_path, alert: t("flash.rate_limited") }

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
end
