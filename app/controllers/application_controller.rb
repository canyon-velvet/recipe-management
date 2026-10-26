class ApplicationController < ActionController::Base
  include Pagy::Method
  include Localization
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, unless: :open_to_any_browser?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!
  # "Today" and "this week" (the current meal plan) follow the user's time zone
  around_action :use_time_zone, if: :logged_in?

  helper_method :current_user, :logged_in?, :assistant_available?, :assistant_open?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  # The assistant needs Claude, so without an Anthropic API key it's left out entirely.
  def assistant_available?
    logged_in? && CleanRecipeService.available?
  end

  # The panel stays open from page to page and visit to visit; the assistant-panel controller keeps this cookie.
  def assistant_open?
    assistant_available? && cookies[:assistant_open] == "1"
  end

  # Starts a fresh session to prevent session fixation.
  def log_in(user)
    reset_session_keeping_locale
    session[:user_id] = user.id
  end

  # A new session, with nothing from the old one but the chosen language.
  def reset_session_keeping_locale
    locale = session[:locale]
    reset_session
    session[:locale] = locale
  end

  def authenticate_user!
    redirect_to login_path, alert: t("flash.login_required") unless logged_in?
  end

  def use_time_zone(&action)
    Time.use_zone(current_user.time_zone, &action)
  end

  # Pages anyone may be sent (a shared recipe) open in whatever browser they have
  def open_to_any_browser? = false

  def require_admin
    redirect_to root_path, alert: t("flash.admin_required") unless current_user&.admin?
  end
end
