# The time zone section of the Preferences page: picking one saves it, and the section comes back saying so.
class TimeZonesController < ApplicationController
  def update
    return head :unprocessable_entity unless current_user.update(params.require(:user).permit(:time_zone))

    render partial: "preferences/time_zone", locals: { user: current_user, saved: true }
  end
end
