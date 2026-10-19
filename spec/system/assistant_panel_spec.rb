require "rails_helper"

RSpec.describe "Assistant panel", type: :system do
  let(:user) { create(:user) }

  before { allow(CleanRecipeService).to receive(:available?).and_return(true) }

  it "opens beside the page, keeps the chat across pages and visits, and starts a new chat" do
    log_in_as user
    click_button "Open assistant"

    within(".assistant-panel") do
      expect(page).to have_text("Ask me what to cook tonight")
      # A starter fills in the box, for the user to finish
      click_button "Import a recipe link"
      expect(page).to have_field("Ask about recipes…", with: "Import this recipe: ", focused: true)

      fill_in "Ask about recipes…", with: "Dinner for 4?"
      find_field("Ask about recipes…").send_keys(:enter)

      expect(page).to have_css(".assistant-message--user", text: "Dinner for 4?")
      expect(page).to have_css(".assistant-message--assistant", text: "Thinking…")
      expect(page).to have_no_text("Ask me what to cook tonight")
      expect(page).to have_field("Ask about recipes…", with: "")
    end
    expect(page).to have_css("body.assistant-open")

    # Moving to another page keeps the panel and the chat. (Beside the open panel the navbar's links are in ☰.)
    click_button "Menu"
    click_link "All Recipes"
    expect(page).to have_css(".assistant-panel", text: "Dinner for 4?")
    expect(page).to have_css("body.assistant-open")

    # So does a full reload: the cookie brings it back open
    visit meal_plans_path
    expect(page).to have_css(".assistant-panel", text: "Dinner for 4?")

    within(".assistant-panel") do
      click_button "New chat"
      expect(page).to have_text("Ask me what to cook tonight")
      expect(page).to have_no_text("Dinner for 4?")
      click_button "Close assistant"
    end
    expect(page).to have_no_css(".assistant-panel")
    expect(page).to have_no_css("body.assistant-open")
  end

  it "keeps the page in step with the panel on Back, and gives focus back to ✦ on close" do
    log_in_as user
    click_link "All Recipes"
    expect(page).to have_current_path(recipes_path) # arrived, so the next click is a visit of its own in the history
    expect(page).to have_no_css("body.assistant-open")

    click_link "Meal Plans"
    expect(page).to have_current_path(meal_plans_path)
    click_button "Open assistant"
    expect(page).to have_css("body.assistant-open")

    # Back restores All Recipes from Turbo's cache, as it was when the panel was closed; the page follows the panel
    page.go_back
    expect(page).to have_current_path(recipes_path)
    expect(page).to have_css("body.assistant-open")
    expect(page).to have_css(".assistant-toggle[aria-expanded='true']")

    click_button "Close assistant"
    expect(page).to have_no_css("body.assistant-open")
    expect(page).to have_css(".assistant-toggle:focus")
  end

  it "covers the page instead of squeezing it on a medium screen" do
    page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: 1024, height: 800) }
    log_in_as user
    click_button "Menu" # the navbar's links are folded at this width
    click_link "All Recipes"
    click_button "Open assistant"

    expect(page).to have_css(".assistant-panel")
    expect(page.evaluate_script("getComputedStyle(document.body).paddingRight")).to eq "0px"
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 1024
    # No "Recipe ready" toasts beside the chat: a draft's card in the chat shows it instead
    expect(page).to have_css("#toasts", visible: :hidden)
  end

  context "with replies written in the background" do
    # Run WriteReplyJob in this process (the test env only records jobs), with a fake Claude that streams slowly.
    around do |example|
      queue_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :async
      example.run
    ensure
      ActiveJob::Base.queue_adapter.shutdown
      ActiveJob::Base.queue_adapter = queue_adapter
    end

    it "streams the reply into the panel, word by word" do
      claude = FakeClaude.new([ "Try ", "a **tomato ", "and egg** stir-fry", " tonight." ], delay: 0.4)
      allow(Anthropic::Client).to receive(:new).and_return(claude)

      log_in_as user
      click_button "Open assistant"
      fill_in "Ask about recipes…", with: "Dinner idea?"
      find_field("Ask about recipes…").send_keys(:enter)

      reply = ".assistant-message--assistant"
      expect(page).to have_css(reply, text: "Try a tomato")
      expect(page).to have_no_css(reply, text: "tonight.") # still streaming
      expect(page).to have_css("#{reply} strong", text: "tomato and egg")
      expect(page).to have_css("#{reply}[aria-busy='false']", text: "Try a tomato and egg stir-fry tonight.")
    end

    it "recommends the user's recipes as cards that open the recipe, flagging what the user avoids" do
      tofu = create(:recipe, user: user, name: "Mapo tofu", total_minutes: 30, servings: 4,
                             tags: [ create(:tag, key: "spicy", kind: "flavor") ])
      tofu.recipe_ingredients.create!(ingredient: create(:ingredient, user: user, name: "Chili oil"))
      create(:preference, user: user, category: "avoid", value: "chili")
      claude = FakeClaude.new(tool_uses: [ { name: "transfer_to_recommend", input: {} } ])
                         .and_then(tool_uses: [ { name: "search_recipes", input: { tags: [ "spicy" ] } } ])
                         .and_then([ "Try the ", "**Mapo tofu**." ], delay: 0.4,
                                   tool_uses: [ { name: "show_recipes",
                                                  input: { recipes: [ { id: tofu.id, why: "Numbing and hot." } ] } } ])
                         .and_then([])
      allow(Anthropic::Client).to receive(:new).and_return(claude)

      log_in_as user
      click_button "Open assistant"
      fill_in "Ask about recipes…", with: "Something spicy?"
      find_field("Ask about recipes…").send_keys(:enter)

      reply = ".assistant-message--assistant"
      expect(page).to have_css(reply, text: "Searching your recipes…")
      expect(page).to have_css("#{reply}[aria-busy='false']", text: "Try the Mapo tofu.")
      within(reply) { click_link "Mapo tofu 30 min · Serves 4 ⚠️ Contains chili Numbing and hot." }

      expect(page).to have_current_path(recipe_path(tofu))
      expect(page).to have_css(".assistant-panel", text: "Try the Mapo tofu.")
    end
  end

  it "saves a suggested preference only when the user clicks Save" do
    conversation = user.current_conversation!
    conversation.messages.create!(role: :user, content: "Something quick? My son is allergic to peanuts.")
    conversation.messages.create!(role: :assistant, agent: :recommend, content: "Here are some ideas.",
                                  preference_suggestions: [
                                    { "category" => "avoid", "value" => "peanut", "state" => "pending" },
                                    { "category" => "likes", "value" => "quick dinners", "state" => "pending" }
                                  ])
    log_in_as user
    click_button "Open assistant"

    within(".assistant-panel") do
      expect(page).to have_css(".assistant-suggestion", text: "Avoid: peanut")
      within(first(".assistant-suggestion")) { click_button "Save" }
      expect(page).to have_link("✓ Saved to Preferences")

      within(all(".assistant-suggestion").last) { click_button "Skip" }
      expect(page).to have_text("Not saved")
    end

    visit preferences_path
    expect(page).to have_css(".preference-chip", text: "peanut")
    expect(page).to have_no_css(".preference-chip", text: "quick dinners")
  end

  context "importing a link from the chat" do
    around do |example|
      queue_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :async
      example.run
    ensure
      ActiveJob::Base.queue_adapter.shutdown
      ActiveJob::Base.queue_adapter = queue_adapter
    end

    it "shows the draft under the reply, and follows it until it's ready to review" do
      link = "https://example.com/mapo-tofu"
      allow(ImportRecipeJob).to receive(:perform_later) # the import itself is read in the test below
      claude = FakeClaude.new(tool_uses: [ { name: "transfer_to_import", input: {} } ])
                         .and_then(tool_uses: [ { name: "import_recipe", input: { url: link } } ])
                         .and_then([ "Importing it now." ])
      allow(Anthropic::Client).to receive(:new).and_return(claude)

      log_in_as user
      click_button "Open assistant"
      fill_in "Ask about recipes…", with: "Import #{link}"
      find_field("Ask about recipes…").send_keys(:enter)

      reply = ".assistant-message--assistant"
      expect(page).to have_css("#{reply}[aria-busy='false']", text: "Importing it now.")
      expect(page).to have_css("#{reply} .assistant-recipe", text: "Reading…")

      # The import finishes in the background
      user.drafts.sole.update!(status: :ready, data: { "name" => "Mapo tofu" })

      expect(page).to have_css("#{reply} .assistant-recipe", text: /Mapo tofu\s+Ready to review/)
      expect(page).to have_css("#toasts", visible: :hidden) # no toast beside the open chat
      within(reply) { click_link "Mapo tofu Ready to review" }
      expect(page).to have_current_path(new_recipe_path(draft_id: user.drafts.sole.id))
    end
  end

  it "shows the daily limit notice and keeps what was typed" do
    conversation = user.current_conversation!
    Message::DAILY_LIMIT.times { conversation.messages.create!(role: :user, content: "Hi") }
    log_in_as user
    click_button "Open assistant"

    fill_in "Ask about recipes…", with: "One more?"
    find_field("Ask about recipes…").send_keys(:enter)

    expect(page).to have_css(".assistant-notice", text: "50 messages in the last 24 hours")
    expect(page).to have_field("Ask about recipes…", with: "One more?")

    # Trying again moves the notice rather than stacking another
    find_field("Ask about recipes…").send_keys(:enter)
    expect(page).to have_css(".assistant-notice", count: 1)
  end

  it "sends on Enter but adds a line on Shift+Enter" do
    log_in_as user
    click_button "Open assistant"

    field = find_field("Ask about recipes…")
    field.send_keys("Eggs", %i[shift enter], "tomatoes")
    expect(user.conversations).to be_empty

    field.send_keys(:enter)
    expect(page).to have_css(".assistant-message--user", text: "Eggs\ntomatoes")
  end
end
