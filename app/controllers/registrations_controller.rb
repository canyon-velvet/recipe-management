# Signing up, by invitation only: the form opens from an invite link (see Invite), which the account uses up.
class RegistrationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create ]
  rate_limit to: 5, within: 1.hour, only: :create,
             with: -> { redirect_to register_path(invite_token: params[:invite_token]), alert: t("flash.rate_limited") }
  before_action :set_invite

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @invite.redeem(@user)
      log_in(@user)
      redirect_to root_path, notice: t("flash.registered")
    elsif @user.errors.any?
      render :new, status: :unprocessable_entity
    else
      # Someone else signed up with the link, or it expired, while the form was open.
      render :invite_only, status: :not_found
    end
  end

  private

  def set_invite
    @invite = Invite.usable.find_by(token: params[:invite_token].to_s)
    render :invite_only, status: :not_found unless @invite
  end

  def user_params
    params.expect(user: [ :username, :password, :password_confirmation ])
  end
end
