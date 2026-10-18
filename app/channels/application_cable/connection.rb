module ApplicationCable
  # Who's on the other end of a live-update connection (the assistant's replies, the Draft box): the logged-in user,
  # from the same session cookie as their pages. Anyone else is refused, so a signed stream name copied out of a
  # page is no use without the session that rendered it.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = User.find_by(id: request.session[:user_id]) || reject_unauthorized_connection
    end
  end
end
