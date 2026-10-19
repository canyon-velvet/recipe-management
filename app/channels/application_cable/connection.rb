module ApplicationCable
  # Who's on the other end of a live-update connection (the assistant's replies, the Draft box): the logged-in user,
  # from the same session cookie as their pages. Anyone not logged in is refused. Which streams a connection hears
  # rests on their signed names, which only the user's own pages carry: Turbo checks the signature, not the user.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = User.find_by(id: request.session[:user_id]) || reject_unauthorized_connection
    end
  end
end
