require "rails_helper"

RSpec.describe "The jobs dashboard", type: :system do
  it "opens from an admin's account menu, within the page's security policy" do
    log_in_as create(:user, :admin, username: "home_cook")

    click_button "home_cook"
    click_link "Background jobs"

    expect(page).to have_current_path(%r{\A/jobs})
    expect(page).to have_text("Queues") # and no CSP violation in the console (spec/support/capybara.rb)
  end
end
