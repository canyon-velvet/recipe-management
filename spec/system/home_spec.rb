require "rails_helper"

RSpec.describe "The home page", type: :system do
  def navbar_color = page.evaluate_script("getComputedStyle(document.querySelector('header')).backgroundColor")

  it "has the navbar in the hero's cream, as every page does, parted from the page by a line once scrolled" do
    user = create(:user)
    create_list(:recipe, 4, user: user)
    log_in_as user

    expect(navbar_color).to eq "rgb(247, 242, 237)" # the hero's cream
    expect(page).to have_no_css("header.is-scrolled")
    page.execute_script("window.scrollTo(0, 400)")
    expect(page).to have_css("header.is-scrolled")

    click_link "All Recipes"
    expect(page).to have_css("h1", text: "Recipes")
    expect(navbar_color).to eq "rgb(247, 242, 237)"
  end
end
