require "rails_helper"

RSpec.describe CleanRecipeService do
  let(:user) { create(:user) }

  # Stands in for Anthropic::Client: replies with the given cleanup, as structured outputs would, and keeps what was
  # sent (client.messages.sent).
  def fake_client(**cleanup)
    reply = CleanRecipeService::RecipeCleanup.new(
      is_recipe: true, name: "Apple cake", description: "", ingredients: [], steps: [ "Bake it." ], tags: [], tips: [],
      servings: 0, prep_minutes: 0, cook_minutes: 0, total_minutes: 0, **cleanup
    )
    message = Struct.new(:stop_reason, :content).new(:end_turn, [ Struct.new(:type, :parsed).new(:text, reply) ])
    messages = Struct.new(:message, :sent) { def create(**params) = (self.sent = params) && message }.new(message)
    Struct.new(:messages).new(messages)
  end

  def clean(recipe: nil, **cleanup)
    described_class.new(user: user, recipe: recipe, text: "Apple cake …", client: fake_client(**cleanup)).call
  end

  describe "servings and times" do
    it "uses what Claude read from the text" do
      data = clean(servings: 4, prep_minutes: 15, cook_minutes: 30)

      expect(data.values_at("servings", "prep_minutes", "cook_minutes", "total_minutes")).to eq [ 4, 15, 30, nil ]
    end

    it "prefers the page's structured values over Claude's reading" do
      data = clean(recipe: { servings: 6, total_minutes: 50 }, servings: 4, total_minutes: 45)

      expect(data.values_at("servings", "total_minutes")).to eq [ 6, 50 ]
    end

    it "treats Claude's 0 as not stated" do
      data = clean

      expect(data.values_at("servings", "prep_minutes", "cook_minutes", "total_minutes")).to all(be_nil)
    end
  end

  it "sends screenshots as pictures, in order, before the instructions" do
    client = fake_client
    images = [ { media_type: "image/png", data: "first" }, { media_type: "image/jpeg", data: "second" } ]
    described_class.new(user: user, recipe: nil, text: nil, images: images, client: client).call

    content = client.messages.sent[:messages].sole[:content]
    expect(content.map { _1[:type] }).to eq %w[image image text]
    expect(content.first[:source]).to eq(type: "base64", media_type: "image/png", data: Base64.strict_encode64("first"))
  end

  it "offers Claude the built-in tags and the user's own, never another user's, and keeps only those it picks" do
    create(:tag, key: "dinner", kind: "meal")
    korean = user.tags.create!(name: "Korean")
    thai = create(:user).tags.create!(name: "Thai")
    client = fake_client(tags: [ "dinner", korean.key, thai.key ])

    data = described_class.new(user: user, recipe: nil, text: "Bibimbap …", client: client).call

    prompt = client.messages.sent[:messages].sole[:content].last[:text]
    expect(prompt).to include("dinner: Dinner", "#{korean.key}: Korean")
    expect(prompt).not_to include("Thai")
    expect(data["tags"]).to eq [ "dinner", korean.key ]
  end
end
