require "rails_helper"

# Imports a real recipe page end to end: nothing is stubbed. The page is fetched from the web, Claude cleans it up, and
# the import job runs in the background while the Draft box updates live. It costs a Claude call and depends on the
# site being up, so it only runs when asked:
#
#   LIVE_IMPORT=1 bundle exec rspec spec/system/import_recipe_spec.rb
#
# Add RECORD_VIDEO=1 to also record the README demo. Everything it saves is rolled back with the test database.
RSpec.describe "Importing a recipe from a link", type: :system do
  let(:user) { create(:user, username: "home_cook") }

  before do
    skip "live import: set LIVE_IMPORT=1 to fetch real pages and call Claude" unless ENV["LIVE_IMPORT"]
    unless CleanRecipeService.available?
      raise "LIVE_IMPORT needs an Anthropic API key (Rails credentials or ANTHROPIC_API_KEY)"
    end
  end

  # Run the import job in the background in this process (the test env only records jobs), so the Draft box shows
  # Reading… and then updates live, as it does with Solid Queue.
  around do |example|
    queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :async
    example.run
  ensure
    # Let a job still running (say, after a failed wait) finish before the test data is rolled back.
    ActiveJob::Base.queue_adapter.shutdown
    ActiveJob::Base.queue_adapter = queue_adapter
  end

  it "reads a recipe page into a draft, then saves it as a recipe", video: "import_recipe" do
    log_in_as user
    click_link "All Recipes"
    click_link "Import recipe"
    fill_in "Recipe link", with: "https://www.yummytoddlerfood.com/apple-oatmeal-cake/"
    click_button "Import"

    expect(page).to have_text("Importing… the recipe will wait in your Draft box.")
    card = "#draft_#{user.drafts.sole.id}"
    # Fetching the page and Claude's cleanup take a while; the card shows Reading… and then updates live, without a
    # page reload. Stop waiting as soon as it's done either way, so a failed import shows its reason right away.
    expect(page).to have_css("#{card} .draft-status--reading")
    using_wait_time(120) { expect(page).to have_css("#{card} .draft-status--ready, #{card} .draft-status--failed") }
    expect(page).to have_css("#{card} .draft-status--ready"), -> { "Import failed: #{find(card).text}" }

    within(card) { click_link "Review" }
    expect(page).to have_css("h1", text: "Review draft")
    click_button "Create recipe"

    expect(page).to have_text("Recipe saved from your Draft box.")
    expect(page).to have_css("h1", text: /apple oatmeal cake/i)
    expect(user.drafts).to be_empty
  end
end
