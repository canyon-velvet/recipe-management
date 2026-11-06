# The address of the exact page a recipe came from (GLOSSARY: Recipe link), in one canonical form, so the same
# page is recognised however it was copied: tracking parameters and #fragments dropped, scheme and host
# lowercased, 下厨房's desktop and mobile addresses unified, and a YouTube video's many links made its watch page.
module RecipeLink
  TRACKING_PARAM = /\A(utm_\w+|fbclid|gclid)\z/
  XIACHUFANG_HOSTS = %w[xiachufang.com www.xiachufang.com m.xiachufang.com].freeze
  YOUTUBE_HOSTS = %w[youtube.com www.youtube.com m.youtube.com].freeze
  # A video's id: 11 letters, digits, - and _. Its link, as normalize makes every link to it.
  YOUTUBE_ID = /\A[\w-]{11}\z/
  YOUTUBE_VIDEO = %r{\Ahttps://www\.youtube\.com/watch\?v=[\w-]{11}\z}

  # Blank → nil. Anything that isn't a parsable http(s) URL is returned stripped, for validation to reject.
  def self.normalize(url)
    url = url.to_s.strip
    return if url.empty?

    uri = URI.parse(url)
    return url unless uri.is_a?(URI::HTTP) && uri.host

    uri.scheme = uri.scheme.downcase
    uri.host = uri.host.downcase
    id = youtube_id(uri)
    return youtube_url(id) if id

    if XIACHUFANG_HOSTS.include?(uri.host)
      uri = URI::HTTPS.build(host: "www.xiachufang.com", path: uri.path, query: uri.query)
    end
    # "#comments" only scrolls the page, but "#/recipe/12" (or "#!…") is how some sites address the recipe itself.
    uri.fragment = nil unless uri.fragment.to_s.start_with?("/", "!")
    uri.query = without_tracking(uri.query)
    uri.to_s
  rescue URI::InvalidURIError, ArgumentError
    url
  end

  SITE_NAMES = { "xiachufang.com" => "下厨房", "xiaohongshu.com" => "小红书", "youtube.com" => "YouTube" }.freeze

  # Whether a (normalized) link is a YouTube video, which Gemini watches instead of the page being read
  def self.youtube?(url) = YOUTUBE_VIDEO.match?(url.to_s)

  # The Source a link comes from: a known site's own name, otherwise its host (example.com).
  def self.site_name(url)
    host = URI.parse(url.to_s).host.to_s.downcase.delete_prefix("www.").delete_prefix("m.")
    SITE_NAMES.find { |domain, _| host == domain || host.end_with?(".#{domain}") }&.last || host.presence
  rescue URI::InvalidURIError
    nil
  end

  # A readable stand-in for a page's title: "…/apple-oatmeal-cake/" → "Apple oatmeal cake"; a link without
  # words, like "…/recipe/107110062/", is shown short instead: "xiachufang.com/recipe/107110062".
  def self.title(url)
    uri = URI.parse(url.to_s)
    return unless uri.host

    slug = uri.path.to_s.split("/").compact_blank.last.to_s.sub(/\.\w+\z/, "")
    return slug.tr("-_", " ").squish.capitalize if slug.match?(/\p{L}{3,}/)

    "#{uri.host.delete_prefix("www.")}#{uri.path.chomp("/")}"
  rescue URI::InvalidURIError
    nil
  end

  def self.without_tracking(query)
    return if query.blank?

    # Filter the raw "name=value" parts, so everything else stays exactly as written (e.g. a bare "?12345").
    kept = query.split("&").reject { |part| URI.decode_www_form_component(part.split("=", 2).first.to_s).match?(TRACKING_PARAM) }
    kept.empty? ? nil : kept.join("&")
  end

  # youtube.com/watch?v=ID (with a playlist, a start time or a share code), youtube.com/shorts/ID, youtu.be/ID
  def self.youtube_id(uri)
    id = if uri.host == "youtu.be" then uri.path.delete_prefix("/")
    elsif YOUTUBE_HOSTS.include?(uri.host)
      uri.path == "/watch" ? URI.decode_www_form(uri.query.to_s).to_h["v"] : uri.path[%r{\A/shorts/([^/]+)}, 1]
    end
    id if id.to_s.match?(YOUTUBE_ID)
  end

  def self.youtube_url(id) = "https://www.youtube.com/watch?v=#{id}"
  private_class_method :without_tracking, :youtube_id, :youtube_url
end
