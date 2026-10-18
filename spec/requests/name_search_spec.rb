require "rails_helper"

RSpec.describe "Searching by name", type: :request do
  let(:user) { create(:user) }

  before { post login_path, params: { username: user.username, password: "password" } }

  def names_found(path, query)
    get path, params: { q: query }
    response.parsed_body.map { |found| found["name"] }
  end

  it "finds the user's ingredients, sources and recipes whose name contains the text, % and _ as typed" do
    %w[Sugar 100%\ cocoa].each { |name| create(:ingredient, user: user, name: name) }
    %w[Grandma Mum's_notes].each { |name| create(:source, user: user, name: name) }
    [ "Apple cake", "50% less sugar cake" ].each { |name| create(:recipe, user: user, name: name) }
    create(:ingredient, user: create(:user), name: "Sugar snap peas")

    expect(names_found(search_ingredients_path, "sug")).to eq [ "Sugar" ]
    expect(names_found(search_ingredients_path, "%")).to eq [ "100% cocoa" ]
    expect(names_found(search_sources_path, "_")).to eq [ "Mum's_notes" ]
    expect(names_found(search_recipes_path, "%")).to eq [ "50% less sugar cake" ]
    expect(names_found(search_ingredients_path, "")).to eq [ "100% cocoa", "Sugar" ]
  end
end
