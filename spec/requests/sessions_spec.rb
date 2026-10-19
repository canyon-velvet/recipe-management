require "rails_helper"

RSpec.describe "Logging in", type: :request do
  let!(:user) { create(:user, username: "home_cook") }
  # The test env's cache stores nothing; the limits need one that counts.
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(SessionsController.cache_store).to receive(:increment) { |*args, **options| cache.increment(*args, **options) }
  end

  def log_in(username, password, from:)
    post login_path, params: { username: username, password: password }, env: { "REMOTE_ADDR" => from }
  end

  it "stops guesses at one account's password after 10 in 15 minutes, even from different addresses" do
    10.times { |n| log_in("Home_Cook", "wrong", from: "203.0.113.#{n}") }

    log_in(user.username, "password", from: "198.51.100.1")
    expect(response).to redirect_to(login_path)
    expect(flash[:alert]).to eq "Too many attempts. Please try again later."
    expect(session[:user_id]).to be_nil

    log_in(create(:user).username, "password", from: "198.51.100.1") # another account isn't held up
    expect(session[:user_id]).to be_present

    travel 16.minutes do
      log_in(user.username, "password", from: "198.51.100.2")
      expect(session[:user_id]).to eq user.id
    end
  end

  it "stops an address after 10 tries in 3 minutes, whichever accounts it tries" do
    10.times { |n| log_in("cook#{n}", "wrong", from: "203.0.113.1") }

    log_in(user.username, "password", from: "203.0.113.1")
    expect(response).to redirect_to(login_path)
    expect(session[:user_id]).to be_nil
  end
end

RSpec.describe "Logging out", type: :request do
  it "ends the whole session but keeps the chosen language" do
    user = create(:user)
    patch locale_path, params: { locale: "zh-CN" }
    post login_path, params: { username: user.username, password: "password" }
    session_id = session.id

    delete logout_path

    expect(session[:user_id]).to be_nil
    expect(session[:locale]).to eq "zh-CN"
    expect(session.id).not_to eq session_id
  end

  it "keeps the user logged in for 30 days from their last visit, also in an app added to the iPhone's Home Screen" do
    user = create(:user)

    freeze_time do
      post login_path, params: { username: user.username, password: "password" }

      # Without an expiry the cookie lasts until the browser closes, and iOS drops it whenever a Home Screen app quits
      session_cookie = response.headers["Set-Cookie"].lines.find { |line| line.start_with?("_recipe_management_session=") }
      expect(session_cookie).to include("expires=#{(Time.now.utc + 30.days.to_i).httpdate}")
    end
  end
end
