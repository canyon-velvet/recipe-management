# Fetches the page behind a recipe link, safely: the link comes from a user, so it must never make the server
# reach a private or internal address (SSRF). SsrfFilter refuses those, re-checks every redirect and pins the
# connection to the address it checked. Pages are also limited in redirects, time and size.
class FetchPageService
  MAX_BYTES = 3.megabytes
  # read_timeout limits each read; this limits the whole fetch, so a server trickling bytes can't hold a worker.
  MAX_SECONDS = 20
  MAX_REDIRECTS = 3
  HTTP_OPTIONS = { open_timeout: 5, read_timeout: 10 }.freeze
  # A plain agent: some sites behind Cloudflare challenge browser-like agents that don't run JavaScript.
  # Uncompressed: a compressed page is unpacked a chunk at a time, and one small chunk could unpack to far more than
  # MAX_BYTES before the size check sees it.
  HEADERS = { "User-Agent" => "RecipeManager/1.0 (recipe import)", "Accept" => "text/html,application/xhtml+xml",
              "Accept-Encoding" => "identity" }.freeze
  BLOCKED_STATUSES = [ 401, 403, 429, 503 ].freeze
  # Bot checks often come back as a normal 200 page; they're small and carry one of these markers.
  CHALLENGE_MARKERS = [ "请滑动完成验证", "安全验证", "captcha", "challenge-platform", "verify you are human" ].freeze
  CHALLENGE_MAX_BYTES = 50_000

  # reason: :blocked (the site refused us, e.g. a captcha) or :fetch_failed (anything else).
  class Error < ImportFailure; end

  class TooLarge < StandardError; end
  class TooSlow < StandardError; end

  def initialize(url)
    @url = url
  end

  # Returns the page's HTML as a UTF-8 string.
  def call
    body = +""
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_SECONDS
    # Every response is read here, redirects and errors included, so the size and time limits always apply.
    response = SsrfFilter.get(request_url, headers: HEADERS, max_redirects: MAX_REDIRECTS, http_options: HTTP_OPTIONS) do |res|
      body = +""
      res.read_body do |chunk|
        body << chunk
        raise TooLarge if body.bytesize > MAX_BYTES
        raise TooSlow if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      end
    end

    raise Error.new(:blocked, "HTTP #{response.code}") if BLOCKED_STATUSES.include?(response.code.to_i)
    raise Error.new(:fetch_failed, "HTTP #{response.code}") unless response.is_a?(Net::HTTPSuccess)

    html = to_utf8(body, response["content-type"])
    raise Error.new(:blocked, "challenge page") if challenge_page?(html)

    html
  rescue TooLarge
    raise Error.new(:fetch_failed, "page larger than #{MAX_BYTES} bytes")
  rescue TooSlow
    raise Error.new(:fetch_failed, "page took longer than #{MAX_SECONDS} s")
  rescue SsrfFilter::Error, SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError,
         Net::HTTPBadResponse, Net::ProtocolError, URI::InvalidURIError => e
    raise Error.new(:fetch_failed, "#{e.class}: #{e.message}")
  end

  private

  # 下厨房 puts the recipe's structured data on its mobile pages.
  def request_url
    uri = URI.parse(@url)
    uri.host = "m.xiachufang.com" if RecipeLink::XIACHUFANG_HOSTS.include?(uri.host)
    uri.to_s
  end

  def challenge_page?(html)
    html.bytesize < CHALLENGE_MAX_BYTES && CHALLENGE_MARKERS.any? { |marker| html.downcase.include?(marker) }
  end

  def to_utf8(body, content_type)
    charset = content_type.to_s[/charset=["']?([\w-]+)/i, 1] || body[/<meta[^>]+charset=["']?([\w-]+)/i, 1] || "UTF-8"
    body.force_encoding(charset).encode("UTF-8", invalid: :replace, undef: :replace)
  rescue ArgumentError, Encoding::ConverterNotFoundError
    body.force_encoding("UTF-8").scrub
  end
end
