require "rails_helper"

RSpec.describe "Logging in", type: :system do
  it "takes the user to the home page with their name in the account menu" do
    user = create(:user, password: "secret123")

    visit login_path
    expect(page).to have_css("h1", text: "Log in to your kitchen")
    expect(page).to have_text("Sign-up is by invitation")
    fill_in "Username", with: user.username
    fill_in "Password", with: "secret123"
    click_button "Log in"

    expect(page).to have_text("Logged in.")
    expect(page).to have_current_path(root_path)
    expect(page).to have_css(".account-toggle", text: user.username)
  end

  it "stays on the log-in page with a wrong password" do
    user = create(:user)

    visit login_path
    fill_in "Username", with: user.username
    fill_in "Password", with: "wrong-password"
    click_button "Log in"

    expect(page).to have_text("Incorrect username or password.")
    expect(page).to have_no_css(".account-toggle")
  end

  it "shows the photo across the top on a phone, like the home page, with the form all on one screen" do
    page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: 390, height: 700) }
    visit login_path

    box = lambda do |selector|
      page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()")
    end
    expect(box.(".home-photo-image")).to include("left" => 0, "width" => 390)
    expect(box.(".home-intro")["top"]).to be < box.(".home-photo-image")["bottom"] # the form's sheet overlaps it…
    # …drawn over it in every browser, not only those that paint in the shown order
    expect(page.evaluate_script("parseInt(getComputedStyle(document.querySelector('.home-intro')).zIndex)")).to be > 0
    expect(box.(".login-note")["bottom"]).to be <= 700
    expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
  end

  it "plays the tour in a pop-up from the photo, and stops it when the pop-up closes" do
    visit login_path
    # Nothing downloaded until asked for: the browser stopped short of fetching it
    expect(page.evaluate_script("document.querySelector('.tour-video').networkState")).to eq(1) # NETWORK_IDLE

    # The test browser can't decode H.264 video, as the browsers people use can, so what's checked is that the video
    # is asked to play, and to stop
    page.execute_script(<<~JS)
      window.videoCalls = []
      HTMLMediaElement.prototype.play = function () { videoCalls.push("play"); return Promise.resolve() }
      HTMLMediaElement.prototype.pause = function () { videoCalls.push("pause") }
    JS
    within(".home-photo") { click_button "Watch the tour" }
    expect(page).to have_css("dialog[open] video.tour-video")
    expect(page.evaluate_script("videoCalls")).to eq([ "play" ])

    click_button "Close"
    expect(page).to have_no_css("dialog[open]")
    expect(page.evaluate_script("videoCalls")).to eq([ "play", "pause" ])

    # Also on a phone: the pill shows on the photo's band, above the form's sheet
    page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: 390, height: 700) }
    box = lambda do |selector|
      page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()")
    end
    expect(box.(".login-tour")["bottom"]).to be <= box.(".home-intro")["top"]
  end

  it "fits the tour's pop-up, controls and all, on a short screen" do
    { "laptop" => [ 1366, 657 ], "phone turned sideways" => [ 844, 390 ] }.each do |screen, (width, height)|
      page.driver.with_playwright_page { |pw| pw.set_viewport_size(width: width, height: height) }
      visit login_path
      click_button "Watch the tour"

      fit = page.evaluate_script(<<~JS)
        (dialog => ({
          scrolls: dialog.scrollHeight > dialog.clientHeight,
          videoBottom: dialog.querySelector("video").getBoundingClientRect().bottom
        }))(document.querySelector("dialog[open]"))
      JS
      expect(fit["scrolls"]).to be(false), "the pop-up scrolls on a #{screen}"
      expect(fit["videoBottom"]).to be <= height
    end
  end
end
