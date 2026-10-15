require "rails_helper"

RSpec.describe FetchPageService do
  it "asks for the page uncompressed, so the size limit counts the bytes it reads" do
    allow(SsrfFilter).to receive(:get).and_raise(SsrfFilter::Error)

    expect { described_class.new("https://example.com/soup").call }.to raise_error(FetchPageService::Error)
    expect(SsrfFilter).to have_received(:get)
      .with("https://example.com/soup", hash_including(headers: hash_including("Accept-Encoding" => "identity")))
  end

  it "fails a page the server compresses anyway, instead of reading its bytes as text" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response["content-encoding"] = "gzip"
    allow(SsrfFilter).to receive(:get).and_return(response)

    expect { described_class.new("https://example.com/soup").call }
      .to raise_error(FetchPageService::Error, /compressed \(gzip\)/) { |error| expect(error.reason).to eq :fetch_failed }
  end
end
