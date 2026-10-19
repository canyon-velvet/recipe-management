module DraftsHelper
  # The account menu shows these on every page, so they come from one grouped count, memoized per request.
  def draft_counts
    @draft_counts ||= current_user.drafts.group(:status).count
  end

  # Where a draft is from: its link's site, its screenshots, or pasted text
  def draft_source(draft)
    return draft.source_host || draft.source_url if draft.source_url
    return t("drafts.screenshots", count: draft.screenshot_count) if draft.screenshot_count.positive?

    t("drafts.pasted_text")
  end
end
