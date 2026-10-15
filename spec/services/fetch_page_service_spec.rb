require "rails_helper"

RSpec.describe FetchPageService do
  it "asks for the page uncompressed, so the size limit counts the bytes it reads" do
    allow(SsrfFilter).to receive(:get).and_raise(SsrfFilter::Error)

    expect { described_class.new("https://example.com/soup").call }.to raise_error(FetchPageService::Error)
    expect(SsrfFilter).to have_received(:get)
      .with("https://example.com/soup", hash_including(headers: hash_including("Accept-Encoding" => "identity")))
  end
end
