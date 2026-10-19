require "rails_helper"

# The assistant end to end, with nothing stubbed: real Claude replies, and a real import fetched from the web. One
# chat shows each agent: the router answering a cooking question itself, Recommend picking from the user's recipes,
# Import reading a link into a draft, and the router offering to update a preference. Replies differ from run to run,
# so it checks who wrote each one and what it showed, not the wording. It costs Claude calls and depends on the
# recipe site being up, so it only runs when asked:
#
#   LIVE_ASSISTANT=1 bundle exec rspec spec/system/ask_the_assistant_spec.rb
#
# Add RECORD_VIDEO=1 to also record the README demo. Everything it saves is rolled back with the test database.
RSpec.describe "Asking the assistant", type: :system do
  let(:user) { create(:user, username: "home_cook") }

  before do
    skip "live assistant: set LIVE_ASSISTANT=1 to call Claude" unless ENV["LIVE_ASSISTANT"]
    unless CleanRecipeService.available?
      raise "LIVE_ASSISTANT needs an Anthropic API key (Rails credentials or ANTHROPIC_API_KEY)"
    end

    tags = { "dinner" => "meal", "breakfast" => "meal", "soup" => "meal", "chinese" => "cuisine",
             "italian" => "cuisine", "vegetarian" => "diet", "spicy" => "flavor", "quick" => "convenience" }
           .to_h { |key, kind| [ key, create(:tag, key: key, kind: kind) ] }
    recipes = {
      "Tomato and egg stir-fry" => [ 15, %w[chinese dinner quick vegetarian],
                                     { "Tomatoes" => "produce", "Eggs" => "dairy_eggs", "Scallions" => "produce" } ],
      "Shakshuka" => [ 25, %w[dinner vegetarian],
                       { "Tomatoes" => "produce", "Eggs" => "dairy_eggs", "Bell pepper" => "produce" } ],
      "Pasta al pomodoro" => [ 20, %w[italian dinner quick vegetarian],
                               { "Spaghetti" => "pantry", "Tomatoes" => "produce", "Basil" => "produce" } ],
      "Mapo tofu" => [ 30, %w[chinese dinner spicy],
                       { "Tofu" => "produce", "Ground pork" => "meat_seafood", "Doubanjiang" => "spices_seasonings" } ],
      "Chicken noodle soup" => [ 45, %w[soup dinner],
                                 { "Chicken" => "meat_seafood", "Egg noodles" => "pantry", "Carrots" => "produce" } ],
      "Overnight oats" => [ 5, %w[breakfast quick vegetarian],
                            { "Rolled oats" => "pantry", "Milk" => "dairy_eggs", "Blueberries" => "produce" } ]
    }
    recipes.each do |name, (minutes, tag_keys, ingredients)|
      create_recipe user, name, tags: tags.values_at(*tag_keys), ingredients: ingredients, total_minutes: minutes,
                                servings: 2
    end
    create(:preference, user: user, category: "household", value: "2 people")
  end

  # Write the replies and read the import in the background in this process (the test env only records jobs), so the
  # panel streams and updates live, as it does with Solid Queue.
  around do |example|
    queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :async
    example.run
  ensure
    # Let a job still running (say, after a failed wait) finish before the test data is rolled back.
    ActiveJob::Base.queue_adapter.shutdown
    ActiveJob::Base.queue_adapter = queue_adapter
  end

  it "answers, recommends, imports and updates a preference", video: "ask_the_assistant" do
    log_in_as user
    click_link "All Recipes"
    click_button "Open assistant"

    # The router answers a cooking question itself
    reply = ask("How long should I boil an egg for a runny yolk?", agent: "router")

    # Recommend picks from the user's recipes, saying why each fits, and offers to save the diet it heard
    reply = ask("We're vegetarian — what can I cook tonight with eggs and tomatoes?", agent: "recommend")
    within(reply) do
      expect(page).to have_css(".assistant-recipe-why")
      within(first(".assistant-suggestion", text: /Diet: .*vegetarian/im)) { click_button "Save" }
      expect(page).to have_link("✓ Saved to Preferences")
    end

    # Import reads a link into a draft, and its card follows the import until it's ready to review
    reply = ask("Can you import https://www.yummytoddlerfood.com/apple-oatmeal-cake/", agent: "import")
    # (Fetching the page and Claude's cleanup take a while. Stop waiting as soon as it's done either way, so a failed
    # import shows its reason right away.)
    within(reply) do
      expect(page).to have_css("[class^='assistant-draft-']"), -> { "No import started: #{text}" }
      using_wait_time(120) { expect(page).to have_css(".assistant-draft-ready, .assistant-recipe-warning") }
      expect(page).to have_css(".assistant-draft-ready"), -> { "Import failed: #{text}" }
    end

    # The router hears a new household size and offers to replace the one saved
    reply = ask("There are 4 of us at home now.", agent: "router")
    within(reply) do
      within(first(".assistant-suggestion", text: /Household: .*4.*Replace “2 people”/m)) { click_button "Save" }
      click_link "✓ Saved to Preferences"
    end

    expect(page).to have_css("h1", text: "Preferences")
    expect(page).to have_css(".preference-chip", text: /vegetarian/i)
    expect(page).to have_css(".preference-chip", text: "4")
    expect(page).to have_no_css(".preference-chip", text: "2 people")
  end

  private

  # Sends the message and waits for the whole reply, which the given agent must have written. Returns its selector.
  def ask(message, agent:)
    fill_in "Ask about recipes…", with: message
    find_field("Ask about recipes…").send_keys(:enter)
    expect(page).to have_css(".assistant-message--user", text: message)

    reply = user.current_conversation.messages.assistant.last
    selector = "#message_#{reply.id}"
    using_wait_time(90) { expect(page).to have_css("#{selector}[aria-busy='false']") }
    expect(reply.reload).to have_attributes(status: "done", agent: agent), -> { "Run error: #{reply.run&.error}" }
    selector
  end
end
