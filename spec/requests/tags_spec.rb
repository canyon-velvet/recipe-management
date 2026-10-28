require "rails_helper"

RSpec.describe "Tags", type: :request do
  let(:user) { create(:user) }

  before { log_in_as user }

  def create_tag(**tag) = post(tags_path, params: { tag: tag }, as: :json)

  it "makes the user a tag, under Other unless another group is chosen, and answers with it for the tag box" do
    create_tag(name: "Korean", emoji: "🍜")

    expect(response).to have_http_status(:created)
    tag = user.tags.sole
    expect(tag).to have_attributes(name: "Korean", emoji: "🍜", kind: "other")
    expect(response.parsed_body).to eq("id" => tag.id, "name" => "Korean", "label" => "🍜 Korean")

    create_tag(name: "Gochujang", kind: "flavor")
    expect(user.tags.find_by!(name: "Gochujang").kind).to eq "flavor"
    expect(response.parsed_body["label"]).to eq "Gochujang"
  end

  it "says why it couldn't, in the pop-up's language" do
    user.tags.create!(name: "Korean")

    create_tag(name: "korean", emoji: "no")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"]).to eq [ "Name has already been taken", "Emoji is invalid" ]
  end

  it "makes it the user's own, whatever else is sent" do
    someone_else = create(:user)

    post tags_path, params: { tag: { name: "Thai", user_id: someone_else.id, key: "dinner", position: 1 } }, as: :json

    expect(someone_else.tags).to be_empty
    expect(user.tags.sole).to have_attributes(name: "Thai", position: Tag::CUSTOM_POSITION)
    expect(user.tags.sole.key).not_to eq "dinner"
  end

  it "says the name is taken when the same one is sent twice at once" do
    allow_any_instance_of(Tag).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

    create_tag(name: "Korean")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"]).to eq [ "Name has already been taken" ]
  end
end
