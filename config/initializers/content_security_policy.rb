# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# Everything the app loads is its own (scripts, styles and fonts are vendored), so the page may only run its own scripts
# and load its own images. Any HTML that slips into a page can't run or send data elsewhere.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self
    # Inline style attributes are used in a few views and by Tom Select; styles can't run code.
    policy.style_src   :self, :unsafe_inline
    policy.img_src     :self, :data
    policy.connect_src :self # includes the Action Cable websocket
    policy.object_src  :none
    policy.base_uri    :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  # A nonce lets the importmap's inline script run. A new one per request: the session id (Rails' example) is empty on
  # a first visit, which would block the importmap. Turbo ignores nonces when it compares pages, so they can differ.
  # Only for scripts: a nonce in style-src would switch off 'unsafe-inline'.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
