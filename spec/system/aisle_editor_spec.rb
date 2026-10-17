require "rails_helper"

RSpec.describe "Editing aisles", type: :system do
  let(:user) { create(:user) } # with the default aisles, Produce first and Other last

  def names = all("dialog[open] .aisle-row .aisle-name").map(&:value)
  def middle(element) = page.evaluate_script(<<~JS, element)
    (e => { const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2] })(arguments[0])
  JS

  def open_aisles
    find(".account-toggle").click
    click_button "Edit aisles"
    expect(page).to have_css("dialog[open] .aisle-row", count: 9)
  end

  # Closing waits for the saves, then reloads the list (the old one is marked, to wait for the new one), so reopening
  # shows what was saved
  def reopen_aisles
    page.execute_script("document.querySelector('dialog[open] .aisle-list').dataset.old = true")
    click_button "Done"
    open_aisles
    expect(page).to have_no_css(".aisle-list[data-old]")
  end

  # Moves are saved in the background, so this waits for them
  def expect_saved(keys)
    page.document.synchronize do
      saved = user.aisles.ordered.pluck(:key).first(keys.size)
      raise Capybara::ExpectationNotMet, "saved #{saved}" unless saved == keys
    end
  end

  before { log_in_as user }

  it "drags an aisle into a new place on a phone, and saves it" do
    page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: 390, height: 844) }
    open_aisles

    x, y = middle(find("button[aria-label^='Move Produce:']"))
    _, dairy = middle(find_field(with: "Dairy & Eggs"))
    page.driver.with_playwright_page do |pw|
      pw.mouse.move(x, y)
      pw.mouse.down
      pw.mouse.move(x, dairy + 10, steps: 10)
      pw.mouse.up
    end

    expect(names.first(3)).to eq [ "Meat & Seafood", "Dairy & Eggs", "Produce" ]
    expect(page).to have_css("[aria-live]", text: "Produce moved to 3 of 8", visible: :all)
    expect_saved %w[meat_seafood dairy_eggs produce]
    reopen_aisles
    expect(names.first(3)).to eq [ "Meat & Seafood", "Dairy & Eggs", "Produce" ]
    expect(names.last).to eq "Other"
  end

  it "moves an aisle with the arrow keys on its grip, but never past Other" do
    open_aisles

    find("button[aria-label^='Move Bakery:']").send_keys(:up)
    expect(names.first(4)).to eq [ "Produce", "Meat & Seafood", "Bakery", "Dairy & Eggs" ]
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-label')")).to start_with "Move Bakery:"

    find("button[aria-label^='Move Beverages:']").send_keys(:down)
    expect(names.last(2)).to eq [ "Beverages", "Other" ]

    expect_saved %w[produce meat_seafood bakery dairy_eggs]
    reopen_aisles
    expect(names.first(4)).to eq [ "Produce", "Meat & Seafood", "Bakery", "Dairy & Eggs" ]
  end

  it "keeps a move when a rename redraws the list before the move is saved" do
    open_aisles
    # Moves save slowly, so the rename's redraw (with the order from before the move) comes first
    page.execute_script(<<~JS)
      const fetchNow = window.fetch
      window.fetch = (url, options) => String(url).endsWith("/move")
        ? new Promise(resolve => setTimeout(resolve, 1500)).then(() => fetchNow(url, options))
        : fetchNow(url, options)
    JS

    find_field(with: "Bakery").set("Bread")
    find("button[aria-label^='Move Dairy & Eggs:']").send_keys(:up) # leaving the name saves the rename

    expect(page).to have_field(with: "Bread")
    expect_saved %w[produce dairy_eggs meat_seafood]
    using_wait_time(5) do
      expect(page).to have_css("dialog[open] .aisle-row:nth-child(2) .aisle-name[value='Dairy & Eggs']")
    end
  end
end
