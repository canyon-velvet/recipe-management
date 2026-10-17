require "rails_helper"

RSpec.describe "Logging in", type: :system do
  it "takes the user to the home page with their name in the account menu" do
    user = create(:user, password: "secret123")

    visit login_path
    expect(page).to have_css("h1", text: "Log in to your kitchen")
    expect(page).to have_text("Sign-up is by invitation")
    fill_in "Username", with: user.username
    fill_in "Password", with: "secret123"
    click_button "Log in"

    expect(page).to have_text("Logged in.")
    expect(page).to have_current_path(root_path)
    expect(page).to have_css(".account-toggle", text: user.username)
  end

  it "stays on the log-in page with a wrong password" do
    user = create(:user)

    visit login_path
    fill_in "Username", with: user.username
    fill_in "Password", with: "wrong-password"
    click_button "Log in"

    expect(page).to have_text("Incorrect username or password.")
    expect(page).to have_no_css(".account-toggle")
  end
end
