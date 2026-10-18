module RequestHelpers
  def log_in_as(user, password: "password")
    post login_path, params: { username: user.username, password: password }
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
