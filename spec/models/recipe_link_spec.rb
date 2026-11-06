require "rails_helper"

RSpec.describe RecipeLink do
  describe "a YouTube video" do
    let(:watch) { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }

    it "is the same watch link however it was copied, without its start time, playlist or share code" do
      [ "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s&list=PL1", "https://youtu.be/dQw4w9WgXcQ?si=abc",
        "HTTPS://M.YouTube.com/shorts/dQw4w9WgXcQ", "https://youtube.com/watch?feature=share&v=dQw4w9WgXcQ" ]
        .each { |link| expect(described_class.normalize(link)).to eq(watch), link }

      expect(described_class.youtube?(watch)).to be true
      expect(described_class.site_name(watch)).to eq "YouTube"
      expect(described_class.title(watch)).to eq "youtube.com/watch?v=dQw4w9WgXcQ" # not "Watch"
    end

    it "is only a link to one video" do
      [ "https://www.youtube.com/@channel", "https://www.youtube.com/watch?v=short",
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ%22%3E", "https://notyoutube.com/watch?v=dQw4w9WgXcQ",
        "https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ",
        "https://www.youtube.com@evil.example/watch?v=dQw4w9WgXcQ",
        "https://youtu.be/dQw4w9WgXcQ/extra" ]
        .each { |link| expect(described_class.youtube?(described_class.normalize(link))).to be(false), link }
    end
  end
end
