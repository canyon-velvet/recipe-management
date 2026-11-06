require "rails_helper"

RSpec.describe WatchVideoService do
  let(:url) { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }
  let(:sent) { [] }

  # Stands in for Gemini: answers with the given status and body, or each request with the next of several
  # [status, body] replies (the last one again once they run out), and keeps each request sent
  def gemini(*replies)
    replies = [ replies ] if replies.first.is_a?(Integer)
    responses = replies.map do |status, body|
      Net::HTTPResponse::CODE_TO_OBJ[status.to_s].new("1.1", status.to_s, "")
                                                 .tap { allow(_1).to receive(:body).and_return(body.to_json) }
    end
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request) do |request|
      sent << request
      responses.size > 1 ? responses.shift : responses.first
    end
    allow(Net::HTTP).to receive(:start).with("generativelanguage.googleapis.com", 443, hash_including(use_ssl: true))
                                       .and_wrap_original { |_original, *, &block| block.call(http) }
  end

  def model_of(request) = request.path[%r{/models/([^:]+):}, 1]

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

  it "has Flash-Lite watch it at once when Flash is busy" do
    gemini([ 503, { error: { message: "The model is overloaded." } } ], [ 200, reply("Bibimbap …") ])

    expect(described_class.new(url).call).to eq "Bibimbap …"
    expect(sent.map { model_of(_1) }).to eq %w[gemini-flash-latest gemini-flash-lite-latest]
  end

  it "waits out rate limits and outages when both models have them" do
    [ 429, 500, 503 ].each do |status|
      sent.clear
      gemini(status, { error: { message: "Try later" } })
      expect { described_class.new(url).call }.to raise_error(described_class::TemporaryError, /#{status}/)
      expect(sent.size).to eq 2
    end
  end

  it "waits out a connection that failed or was too slow, without trying Flash-Lite at once: Flash wasn't busy" do
    allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)

    expect { described_class.new(url).call }.to raise_error(described_class::TemporaryError, /ReadTimeout/)
    expect(Net::HTTP).to have_received(:start).once
  end

  it "fails, reported, when Flash is busy and Flash-Lite can't be used, instead of waiting on a broken fallback" do
    expect(Rails.error).to receive(:report)
    gemini([ 503, { error: { message: "The model is overloaded." } } ],
           [ 404, { error: { message: "models/gemini-flash-lite-latest is not found" } } ])

    expect(reason_of { described_class.new(url).call }).to eq :video_failed
  end

  it "doesn't try Flash-Lite for a video Flash can't watch" do
    gemini(400, { error: { message: "Video is not public" } })

    expect(reason_of { described_class.new(url).call }).to eq :video_unavailable
    expect(sent.map { model_of(_1) }).to eq %w[gemini-flash-latest]
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
