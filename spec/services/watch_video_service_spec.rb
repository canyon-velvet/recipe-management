require "rails_helper"

RSpec.describe WatchVideoService do
  let(:url) { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }
  let(:sent) { [] }

  # Stands in for Gemini: answers with the given status and body, and keeps each request sent
  def gemini(status, body)
    response = Net::HTTPResponse::CODE_TO_OBJ[status.to_s].new("1.1", status.to_s, "")
    allow(response).to receive(:body).and_return(body.is_a?(String) ? body : body.to_json)
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request) { |request| sent << request && response }
    allow(Net::HTTP).to receive(:start).with("generativelanguage.googleapis.com", 443, hash_including(use_ssl: true))
                                       .and_yield(http).and_return(response)
  end

  # Why it failed
  def reason_of
    yield
  rescue described_class::Error => e
    e.reason
  end

  def reply(text, finish = "STOP")
    { candidates: [ { content: { parts: [ { text: text } ] }, finishReason: finish } ] }
  end

  before { allow(described_class).to receive(:api_key).and_return("test-key") }

  it "has Gemini watch the video's first 40 minutes at low resolution, and gives back the recipe it wrote down" do
    gemini(200, reply("Bibimbap\n\nIngredients:\n- rice, 2 cups"))

    expect(described_class.new(url).call).to eq "Bibimbap\n\nIngredients:\n- rice, 2 cups"
    request = sent.sole
    expect(request["x-goog-api-key"]).to eq "test-key"
    body = JSON.parse(request.body)
    expect(body.dig("contents", 0, "parts", 0)).to eq(
      "file_data" => { "file_uri" => url }, "video_metadata" => { "end_offset" => "2400s" }
    )
    expect(body.dig("generationConfig", "mediaResolution")).to eq "MEDIA_RESOLUTION_LOW"
  end

  it "says there's no recipe when the video doesn't teach one" do
    gemini(200, reply("NO_RECIPE\n"))

    expect(reason_of { described_class.new(url).call }).to eq :not_a_recipe
  end

  it "says the video can't be watched when Gemini refuses it, such as a private one" do
    gemini(400, { error: { message: "Video is not public" } })

    expect(reason_of { described_class.new(url).call }).to eq :video_unavailable
  end

  it "waits out rate limits, outages and a connection that failed" do
    [ 429, 500, 503 ].each do |status|
      gemini(status, { error: { message: "Try later" } })
      expect { described_class.new(url).call }.to raise_error(described_class::TemporaryError, /#{status}/)
    end

    allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)
    expect { described_class.new(url).call }.to raise_error(described_class::TemporaryError, /ReadTimeout/)
  end

  it "reports a wrong key or request, the app's to fix, instead of blaming the video" do
    expect(Rails.error).to receive(:report).exactly(3).times
    gemini(400, { error: { message: "API key not valid", details: [ { reason: "API_KEY_INVALID" } ] } })
    expect(reason_of { described_class.new(url).call }).to eq :video_failed
    gemini(403, { error: { status: "PERMISSION_DENIED" } })
    expect(reason_of { described_class.new(url).call }).to eq :video_failed
    gemini(404, { error: { message: "models/gemini-flash-latest is not found" } })
    expect(reason_of { described_class.new(url).call }).to eq :video_failed
  end

  it "sends Claude no more of what Gemini wrote than of a page" do
    gemini(200, reply("a" * (ExtractRecipeService::MAX_TEXT_CHARS + 1)))

    expect(described_class.new(url).call.length).to eq ExtractRecipeService::MAX_TEXT_CHARS
  end

  it "fails a reply cut short or empty" do
    gemini(200, reply("Bibimbap\nIngredients", "MAX_TOKENS"))
    expect(reason_of { described_class.new(url).call }).to eq :video_failed

    gemini(200, { candidates: [] })
    expect(reason_of { described_class.new(url).call }).to eq :video_failed
  end
end
