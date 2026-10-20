require "rails_helper"

RSpec.describe "The recipe list", type: :system do
  let(:user) { create(:user) }
  let!(:chinese) { create(:tag, key: "chinese", kind: "cuisine") }
  let!(:italian) { create(:tag, key: "italian", kind: "cuisine") }
  let!(:soup) { create(:tag, key: "soup", kind: "meal") }

  before do
    create(:recipe, user: user, name: "Mapo Tofu", description: "Silky **tofu**.", total_minutes: 25, servings: 4,
                    tags: [ chinese ])
    create(:recipe, user: user, name: "Hot and Sour Soup", tags: [ chinese, soup ])
    create(:recipe, user: user, name: "Minestrone", tags: [ soup ])
  end

  def resize(width) = page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: width, height: 900) }

  it "filters by a tag from the sidebar, which counts each tag's recipes and all of them" do
    log_in_as user
    visit recipes_path

    expect(page).to have_css("h1", text: "Recipes")
    expect(page).to have_no_css(".recipes-count") # the count is All recipes' in the sidebar
    within(".tag-catalog") do
      expect(page).to have_link("All recipes 3")
      expect(page).to have_link("Chinese 2")
      expect(page).to have_link("Soup 2")
      expect(page).to have_no_link("Italian") # none of the user's recipes
      click_link "Chinese"
    end

    expect(page).to have_css("h1", text: "Chinese")
    expect(page).to have_css(".recipe-row", count: 2)
    expect(page).to have_no_text("Minestrone")
  end

  it "starts the sidebar level with the first recipe, under a heading across the top, even when it is the taller" do
    %w[breakfast lunch dinner snack dessert appetizer salad drink].each { create(:tag, key: _1, kind: "meal") }
    %w[japanese mexican american].each { create(:tag, key: _1, kind: "cuisine") }
    log_in_as user
    visit recipes_path

    box = lambda do |selector|
      page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()")
    end
    # The sidebar is taller than the list...
    expect(box.(".recipes-sidebar")["height"]).to be > box.(".recipes-list")["height"]
    # ...and both start together, below the heading
    expect(box.(".recipes-list")["top"]).to be_within(1).of(box.(".recipes-sidebar")["top"])
    expect(box.(".recipes-sidebar")["top"]).to be > box.(".recipes-header")["bottom"]
  end

  it "searches as you type, keeping the search box's focus, and a tag picked next keeps the search" do
    log_in_as user
    visit recipes_path

    fill_in "Search recipes by name, ingredient or source", with: "soup"
    expect(page).to have_text("1 recipe · matching “soup”")
    expect(page).to have_css(".recipe-row", count: 1, text: "Hot and Sour Soup")
    expect(page).to have_css("input[name='q']:focus")
    expect(page).to have_current_path(recipes_path(q: "soup"))
    # However the tag is opened (a click, or a new tab)
    expect(find(".tag-catalog").find_link("Soup")[:href]).to include("q=soup")

    within(".tag-catalog") { click_link "Soup" }
    expect(page).to have_css("h1", text: "Soup")
    expect(page).to have_css(".recipe-row", count: 1, text: "Hot and Sour Soup")
    expect(page).to have_field("Search recipes by name, ingredient or source", with: "soup")
  end

  it "shows the login page whole when a search finds the session has ended" do
    log_in_as user
    visit recipes_path
    page.driver.with_playwright_page { |pw| pw.context.clear_cookies }

    fill_in "Search recipes by name, ingredient or source", with: "soup"

    expect(page).to have_current_path(login_path)
    expect(page).to have_button("Log in")
  end

  it "keeps searches out of the history, so Back leaves the page" do
    log_in_as user
    click_link "All Recipes"
    fill_in "Search recipes by name, ingredient or source", with: "soup"
    expect(page).to have_text("matching “soup”")
    fill_in "Search recipes by name, ingredient or source", with: "minestrone"
    expect(page).to have_text("matching “minestrone”")

    page.go_back
    expect(page).to have_current_path(root_path)
  end

  it "shows a row's description as text, its time and servings, and keeps its ⋮ menu" do
    log_in_as user
    visit recipes_path

    row = find(".recipe-row", text: "Mapo Tofu")
    expect(row).to have_text("Silky tofu.")
    expect(row.find(".recipe-row-facts")).to have_text(/25 min\s+👥\s+Servings\s+4\s+Chinese/)

    within(row) do
      find("button[data-action*='dropdown#toggle']").click
      click_link "Edit"
    end
    expect(page).to have_field("Name", with: "Mapo Tofu")
  end

  it "keeps an open ⋮ menu above the next row's ⋮ button" do
    log_in_as user
    visit recipes_path

    within(first(".recipe-row")) { click_button "More actions" }
    delete = find_link("Delete")
    # Where the next row's ⋮ button sits, under the menu
    hit = page.evaluate_script(<<~JS)
      (() => {
        const link = [...document.querySelectorAll("a")].find((a) => a.textContent.trim() === "Delete");
        const box = link.getBoundingClientRect();
        return document.elementFromPoint(box.right - 4, box.top + box.height / 2).textContent.trim();
      })()
    JS
    expect(delete).to be_visible
    expect(hit).to eq "Delete"
  end

  it "shows the search box on a phone, with the tags folded behind Filter" do
    resize(390)
    log_in_as user
    visit recipes_path

    # The heading, then the search box with Filter, then the recipes; the tags start folded
    tops = page.evaluate_script(<<~JS)
      [".recipes-header", ".recipes-search-row", ".recipes-list"].map((selector) =>
        document.querySelector(selector).getBoundingClientRect().top)
    JS
    expect(tops).to eq tops.sort
    expect(page).to have_no_css(".tag-catalog", visible: true)

    # Searching needs no tap first, and leaves the tags folded
    fill_in "Search recipes by name, ingredient or source", with: "o"
    expect(page).to have_text("matching “o”")
    expect(page).to have_css("input[name='q']:focus")
    expect(page).to have_no_css(".tag-catalog", visible: true)

    # Filter opens them (its arrow turns), and Done folds them again
    click_button "Filter"
    expect(page).to have_css("button[aria-expanded='true']", text: "Filter")
    expect(page).to have_css(".tag-catalog", visible: true)
    click_button "Done"
    expect(page).to have_css("button[aria-expanded='false']:focus", text: "Filter")
    expect(page).to have_no_css(".tag-catalog", visible: true)

    # A tag picked keeps the search and names the button, the tags folded again
    click_button "Filter"
    within(".tag-catalog") { click_link "Soup" }
    expect(page).to have_css("h1", text: "Soup")
    expect(page).to have_field("Search recipes by name, ingredient or source", with: "o")
    expect(page).to have_button("Filter: Soup")
    expect(page).to have_no_css(".tag-catalog", visible: true)
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
  end

  it "keeps a row's time and servings on one line on a phone, cutting the tags short instead" do
    create(:recipe, user: user, name: "Red-braised pork", total_minutes: 90, servings: 4, tags: [ chinese, soup ])
    resize(390)
    log_in_as user
    visit recipes_path

    facts = find(".recipe-row", text: "Red-braised pork").find(".recipe-row-facts")
    expect(facts).to have_text("1 hr 30 min")
    heights = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".recipe-row-facts")].map((facts) => facts.getBoundingClientRect().height)
    JS
    line_height = page.evaluate_script(<<~JS)
      parseFloat(getComputedStyle(document.querySelector(".recipe-row-facts")).lineHeight)
    JS
    expect(heights).to all(be <= line_height + 1)
  end

  it "keeps a row with a long name within the narrowest phone, its name cut short" do
    create(:recipe, user: user, name: "Grandma's slow-braised pork belly with preserved mustard greens and rice")
    resize(320)
    log_in_as user
    visit recipes_path

    expect(page).to have_css(".recipe-row-title", text: "Grandma's slow-braised")
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 320
  end
end
