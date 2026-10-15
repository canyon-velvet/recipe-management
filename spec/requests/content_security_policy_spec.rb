require "rails_helper"

RSpec.describe "Content Security Policy", type: :request do
  it "lets only the app's own scripts run, with a nonce for the importmap" do
    get login_path

    policy = response.headers["Content-Security-Policy"]
    nonce = policy[/'nonce-([^']+)'/, 1]
    expect(policy).to include("default-src 'self'", "object-src 'none'", "frame-ancestors 'none'")
    expect(policy).to match(/script-src 'self' 'nonce-[^']+'/)
    expect(policy).to include("style-src 'self' 'unsafe-inline'")
    expect(response.body).to include(%(<script type="importmap" data-turbo-track="reload" nonce="#{nonce}">))
  end
end
