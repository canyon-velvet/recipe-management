# The web app manifest, which lets a phone add the app to its home screen. Served here rather than by Rails' own
# PwaController so the app's name follows the visitor's language. Open to all: the login page links it too.
class PwaController < ApplicationController
  skip_before_action :authenticate_user!

  def manifest = render(layout: false)
end
