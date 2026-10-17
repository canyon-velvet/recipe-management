require "rails_helper"

RSpec.describe "Reordering a recipe's steps", type: :system do
  let(:user) { create(:user) }
  let(:recipe) do
    create(:recipe, user: user).tap do |recipe|
      recipe.steps.destroy_all
      [ "Soak the beans", "Boil them", "Fry the garlic", "Mix and serve" ].each.with_index(1) do |body, position|
        recipe.steps.create!(body: body, position: position)
      end
    end
  end

  def previews = all(".step-preview").map(&:text)
  def numbers = all(".step-number").map(&:text)
  def saved_steps = recipe.steps.reload.order(:position).map(&:body)
  def middle(element) = page.evaluate_script(<<~JS, element)
    (e => { const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2] })(arguments[0])
  JS

  before do
    log_in_as user
    visit edit_recipe_path(recipe)
    click_button "Reorder"
  end

  it "collapses the steps to one line each, which drag into order on a phone" do
    page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: 390, height: 844) }
    expect(page).to have_no_css(".step-row textarea", visible: true)
    expect(previews).to eq [ "Soak the beans", "Boil them", "Fry the garlic", "Mix and serve" ]

    x, y = middle(find(".step-preview", text: "Soak the beans"))
    _, below = middle(find(".step-preview", text: "Fry the garlic"))
    page.driver.with_playwright_page do |pw|
      pw.mouse.move(x, y)
      pw.mouse.down
      pw.mouse.move(x, below + 10, steps: 10)
      pw.mouse.up
    end

    expect(previews).to eq [ "Boil them", "Fry the garlic", "Soak the beans", "Mix and serve" ]
    expect(numbers).to eq %w[1 2 3 4]
    click_button "Done"
    expect(page).to have_css(".step-row textarea", count: 4, visible: true)
    click_button "Update recipe"
    expect(page).to have_text("Recipe updated.")
    expect(saved_steps).to eq [ "Boil them", "Fry the garlic", "Soak the beans", "Mix and serve" ]
  end

  it "moves a step with the arrow keys on its handle" do
    handle = all(".step-handle")[2]
    handle.send_keys(:up, :up)

    expect(previews).to eq [ "Fry the garlic", "Soak the beans", "Boil them", "Mix and serve" ]
    expect(page.evaluate_script("document.activeElement")).to eq handle
    expect(handle["aria-label"]).to start_with "Move step 1:"
    expect(page).to have_css("[aria-live]", text: "Step moved to 1 of 4", visible: :all)
    expect(page).to have_css("button[aria-pressed='true']", text: "Done")
    click_button "Update recipe"
    expect(page).to have_text("Recipe updated.")
    expect(saved_steps).to eq [ "Fry the garlic", "Soak the beans", "Boil them", "Mix and serve" ]
  end

  it "leaves a step pressed near the bottom of the screen where it is, without scrolling" do
    page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: 390, height: 844) }
    scrolled = page.evaluate_async_script(<<~JS)
      const done = arguments[0], before = scrollY, y = innerHeight - 10
      const fire = (target, type) =>
        target.dispatchEvent(new PointerEvent(type, { bubbles: true, cancelable: true, pointerId: 1, clientY: y }))
      fire([...document.querySelectorAll(".step-preview")].at(-1), "pointerdown")
      setTimeout(() => { fire(document, "pointerup"); done(scrollY - before) }, 300)
    JS

    expect(scrolled).to eq 0
    expect(previews).to eq [ "Soak the beans", "Boil them", "Fry the garlic", "Mix and serve" ]
    expect(find("[data-step-list-target=status]", visible: :all).text(:all)).to be_empty
  end

  it "ignores a second finger while one step is being dragged" do
    page.execute_script(<<~JS)
      const [first, , third] = document.querySelectorAll(".step-preview")
      const fire = (target, type, pointerId, y) =>
        target.dispatchEvent(new PointerEvent(type, { bubbles: true, cancelable: true, pointerId, clientY: y }))
      fire(first, "pointerdown", 1, 0)
      fire(third, "pointerdown", 2, 0)
      fire(document, "pointerup", 1, 0)
      fire(document, "pointerup", 2, 0)
      fire(document, "pointermove", 1, 9999)
    JS

    expect(page).to have_no_css(".step-row--lifted")
    expect(page).to have_no_text("null")
    expect(previews).to eq [ "Soak the beans", "Boil them", "Fry the garlic", "Mix and serve" ]
  end
end
