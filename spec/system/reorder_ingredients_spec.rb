require "rails_helper"

RSpec.describe "Reordering a recipe's ingredients", type: :system do
  let(:user) { create(:user) }
  let(:recipe) do
    create(:recipe, user: user).tap do |recipe|
      [ [ "Beans", "2", "cups" ], [ "Garlic", "3", "cloves" ], [ "Salt", nil, nil ], [ "Oil", "1", "tbsp" ] ]
        .each do |name, quantity, unit|
          recipe.recipe_ingredients.create!(ingredient: create(:ingredient, user: user, name: name),
                                            quantity: quantity, unit: unit)
        end
    end
  end

  def previews = all(".ingredient-row .reorder-preview").map(&:text)
  def saved_ingredients = recipe.recipe_ingredients.reload.map { _1.ingredient.name }
  def middle(element) = page.evaluate_script(<<~JS, element)
    (e => { const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2] })(arguments[0])
  JS

  before do
    log_in_as user
    visit edit_recipe_path(recipe)
    within(".ingredient-list") { click_button "Reorder" }
  end

  it "collapses the ingredients to one line each, which drag into order" do
    expect(page).to have_no_css(".ingredient-row input.form-input", visible: true)
    expect(page).to have_no_button("+ Add ingredient")
    expect(previews).to eq [ "Beans 2 cups", "Garlic 3 cloves", "Salt", "Oil 1 tbsp" ]

    scroll_to(find(".ingredient-list"))
    x, y = middle(find(".reorder-preview", text: "Beans"))
    _, below = middle(find(".reorder-preview", text: "Salt"))
    page.driver.with_playwright_page do |pw|
      pw.mouse.move(x, y)
      pw.mouse.down
      pw.mouse.move(x, below + 10, steps: 10)
      pw.mouse.up
    end

    expect(previews).to eq [ "Garlic 3 cloves", "Salt", "Beans 2 cups", "Oil 1 tbsp" ]
    within(".ingredient-list") { click_button "Done" }
    expect(page).to have_css(".ingredient-row input.form-input", minimum: 12, visible: true)
    click_button "Update recipe"
    expect(page).to have_text("Recipe updated.")
    expect(saved_ingredients).to eq %w[Garlic Salt Beans Oil]
  end

  it "moves an ingredient with the arrow keys on its handle, and keeps the steps' order apart" do
    handle = all(".ingredient-row .reorder-handle")[3]
    handle.send_keys(:up, :up, :up)

    expect(previews).to eq [ "Oil 1 tbsp", "Beans 2 cups", "Garlic 3 cloves", "Salt" ]
    expect(page.evaluate_script("document.activeElement")).to eq handle
    expect(handle["aria-label"]).to start_with "Move ingredient 1:"
    expect(page).to have_css("[aria-live]", text: "Ingredient moved to 1 of 4", visible: :all)
    expect(page).to have_css(".step-row textarea", visible: true)
    click_button "Update recipe"
    expect(page).to have_text("Recipe updated.")
    expect(saved_ingredients).to eq %w[Oil Beans Garlic Salt]
  end

  it "numbers an added ingredient after the others" do
    within(".ingredient-list") { click_button "Done" }
    click_button "+ Add ingredient"
    within(".ingredient-list") { click_button "Reorder" }

    expect(all(".ingredient-row [data-reorder-list-target=position]", visible: :all).map(&:value)).to eq %w[1 2 3 4 5]
    expect(previews.last).to eq "Search ingredients..."
  end
end
