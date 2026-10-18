# The login lasts 30 days from the last visit (each visit moves it on), not just until the browser closes: an app
# added to the iPhone's Home Screen drops cookies without an expiry whenever it quits, which logged the user out every
# time they opened it. The key is Rails' default for this app, so sessions from before this setting carry on.
Rails.application.config.session_store :cookie_store, key: "_recipe_management_session", expire_after: 30.days
