require "rails_helper"

RSpec.describe "Inviting someone", type: :system do
  let(:admin) { create(:user, :admin, username: "home_cook") }

  it "an admin creates an invite link, and the person signs up with it" do
    log_in_as admin
    find(".account-toggle").click
    click_link "Invites"

    fill_in "Who it's for", with: "Mum"
    click_button "Create invite link"
    expect(page).to have_text("Invite link created.")
    link = find_field("Invite link").value

    find(".account-toggle").click
    click_link "Log out"
    expect(page).to have_text("Logged out.") # done, before the sign-up starts a new session
    expect(page).to have_no_link("Sign up")

    visit link
    fill_in "Username", with: "mum"
    fill_in "Password", with: "secret123"
    fill_in "Confirm password", with: "secret123"
    click_button "Sign up"

    expect(page).to have_text("Account created.")
    expect(page).to have_css(".account-toggle", text: "mum")
    expect(Invite.sole.used_by.username).to eq "mum"
  end
end
