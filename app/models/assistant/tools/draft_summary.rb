module Assistant
  module Tools
    # How the tools describe a Draft to Claude: its title, where it is in the import (reading, ready to review in the
    # Draft box, or failed), and why it failed, in the user's language.
    module DraftSummary
      def self.of(draft)
        summary = { title: draft.title, status: draft.status, added: draft.created_at.iso8601 }
        summary[:why_it_failed] = draft.failure_message if draft.failed?
        summary
      end
    end
  end
end
