# The account menu's Light / Dark / Auto switch. The page has already turned (appearance controller); this keeps the
# choice for the account, and redraws the switch to match, morphed so the chosen button keeps the keyboard's focus.
# Without JavaScript, the page comes back in it.
class AppearancesController < ApplicationController
  def update
    return head :unprocessable_entity unless current_user.update(appearance: params.expect(:appearance))

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("appearance", method: :morph, partial: "shared/appearance",
                                                                locals: { appearance: current_user.appearance })
      end
      format.html { redirect_back_or_to root_path }
    end
  end
end
