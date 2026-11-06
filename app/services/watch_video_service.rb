# Has Gemini watch a public YouTube video (issue #208) and write down the recipe it teaches, as plain text: what's
# said and shown on screen, which is often the only place a video gives its amounts. Claude then reads that text like
# pasted text (CleanRecipeService), so a video's draft is made like any other. Google fetches the video, not us; the
# link sent is always a canonical watch link (RecipeLink), never one as the user typed it.
class WatchVideoService
  MODEL = "gemini-flash-latest"
  ENDPOINT = URI("https://generativelanguage.googleapis.com/v1beta/models/#{MODEL}:generateContent")
  # Only the first 40 minutes are watched, so a long video can't use up the quota. At low resolution a second of video
  # is about 100 tokens: 40 minutes is about 240k, within the free tier's tokens a minute (an hour would be over).
  MAX_SECONDS = 2400
  # Watching a long video takes Gemini a minute or more
  HTTP_OPTIONS = { open_timeout: 10, read_timeout: 300 }.freeze
  NO_RECIPE = "NO_RECIPE"

  PROMPT = <<~PROMPT.freeze
    This is a cooking video. Write down the recipe it teaches, in the language the video uses, as plain text:
    its name, the ingredients with their amounts, the steps in order, the servings and times if given, and any tips.
    Take amounts from what is said, shown on screen or written in captions. Only write what the video gives; don't
    add ingredients, amounts or steps of your own. If the video doesn't teach a recipe, reply only #{NO_RECIPE}.
  PROMPT

  # reason: :video_unavailable (Gemini can't watch it: private, unlisted, removed or age-restricted), :not_a_recipe,
  # or :video_failed (also when the key or the request is wrong, which is reported). Temporary problems (rate limits,
  # outages) raise TemporaryError, which ImportRecipeJob waits out.
  class Error < ImportFailure; end

  class TemporaryError < StandardError; end

  TEMPORARY_STATUSES = [ 429, 500, 503, 504 ].freeze

  def self.api_key = Rails.application.credentials.dig(:gemini, :api_key) || ENV["GEMINI_API_KEY"]

  def self.available? = api_key.present?

  # url: a YouTube watch link (RecipeLink.youtube?)
  def initialize(url)
    @url = url
  end

  # Returns the recipe as text, no longer than a page's text sent to Claude
  def call
    text = parse(post)
    raise Error.new(:not_a_recipe) if text.strip == NO_RECIPE

    text.first(ExtractRecipeService::MAX_TEXT_CHARS)
  end

  private

  def post
    request = Net::HTTP::Post.new(ENDPOINT, "Content-Type" => "application/json",
                                            "x-goog-api-key" => self.class.api_key)
    request.body = body.to_json
    response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, **HTTP_OPTIONS) { _1.request(request) }
    raise_for(response) unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise TemporaryError, "#{e.class}: #{e.message}"
  end

  def body
    video = { file_data: { file_uri: @url }, video_metadata: { end_offset: "#{MAX_SECONDS}s" } }
    { contents: [ { parts: [ video, { text: PROMPT } ] } ],
      generationConfig: { mediaResolution: "MEDIA_RESOLUTION_LOW" } }
  end

  # A video Gemini can't watch is refused as a bad request (400). So is a bad key (API_KEY_INVALID), and a key without
  # access is forbidden (403): those, and anything else, are the app's to fix, so they're reported.
  def raise_for(response)
    message = "HTTP #{response.code}: #{response.body.to_s.first(500)}"
    raise TemporaryError, message if TEMPORARY_STATUSES.include?(response.code.to_i)
    raise Error.new(:video_unavailable, message) if response.code == "400" && !message.include?("API_KEY_INVALID")

    failed(message)
  end

  def failed(message)
    Rails.error.report(Error.new(:video_failed, message), handled: true, context: { url: @url })
    raise Error.new(:video_failed, message)
  end

  def parse(json)
    candidate = json.dig("candidates", 0)
    text = candidate&.dig("content", "parts")&.filter_map { _1["text"] }&.join
    failed("no text: #{json.to_s.first(500)}") if text.blank?
    failed("stopped: #{candidate["finishReason"]}") unless candidate["finishReason"] == "STOP"

    text
  end
end
