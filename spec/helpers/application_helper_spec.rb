require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#render_markdown" do
    it "renders markdown" do
      expect(helper.render_markdown("**Stir** well")).to include("<strong>Stir</strong> well")
    end

    it "shows images, inline or by reference, as their alt text, so nothing loads from another server" do
      html = helper.render_markdown("![Dumplings](https://evil.example/a.png)\n\n![Soup <b>][ref]\n\n" \
                                    "[ref]: https://evil.example/b.png")

      expect(html).to include("<p>Dumplings</p>", "<p>Soup &lt;b&gt;</p>")
      expect(html).not_to include("<img", "evil.example")
    end

    it "filters out raw HTML" do
      html = helper.render_markdown(%(<script>alert(1)</script><img src="x" onerror="alert(1)">Done))

      expect(html).not_to include("<script", "<img", "onerror")
      expect(html).to include("Done")
    end

    it "doesn't link javascript: addresses" do
      expect(helper.render_markdown("[click](javascript:alert(1))")).not_to include("href")
    end
  end
end
