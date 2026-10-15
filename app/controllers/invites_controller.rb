# Invite links, for admins: create one for someone to sign up with, or delete one that hasn't been used.
class InvitesController < ApplicationController
  before_action :require_admin

  def index
    @invite = Invite.new
    @invites = Invite.includes(:used_by).newest_first
  end

  def create
    @invite = Invite.new(params.expect(invite: [ :note ]).merge(created_by: current_user))
    if @invite.save
      redirect_to invites_path, notice: t("flash.invite_created")
    else
      @invites = Invite.includes(:used_by).newest_first
      render :index, status: :unprocessable_entity
    end
  end

  # A used invite stays, as the record of who joined with it.
  def destroy
    invite = Invite.find(params[:id])
    return redirect_to invites_path, alert: t("flash.invite_used") if invite.used?

    invite.destroy
    redirect_to invites_path, notice: t("flash.invite_deleted")
  end
end
