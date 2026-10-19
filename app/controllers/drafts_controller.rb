class DraftsController < ApplicationController
  def index
    @drafts = current_user.drafts.newest_first
  end

  # Try again: a failed import is read again, as it was imported (its link or its pasted text), in the same draft.
  def read_again
    result = StartImportService.new(user: current_user, draft: current_user.drafts.failed.find(params[:id])).call
    flash = result.success? ? { notice: t("flash.draft_retried") } : { alert: t("imports.errors.#{result.error}") }
    redirect_to drafts_path, status: :see_other, **flash
  end

  def destroy
    current_user.drafts.find(params[:id]).destroy
    redirect_to drafts_path, notice: t("flash.draft_discarded"), status: :see_other
  end
end
