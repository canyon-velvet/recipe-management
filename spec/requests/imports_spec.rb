require "rails_helper"

RSpec.describe "Importing", type: :request do
  let(:user) { create(:user) }
  # The test env's cache stores nothing; the hourly limit needs one that counts.
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails).to receive(:cache).and_return(cache)
    log_in_as user
  end

  def import(count)
    count.times { StartImportService.new(user: user, url: "https://example.com/#{SecureRandom.hex(4)}").call }
  end

  def limit_line
    get new_import_path
    Nokogiri::HTML(response.body).at_css(".import-limit")
  end

  it "says how many imports are left this hour, in amber once few are" do
    expect(limit_line.text).to eq "20 of 20 imports left this hour"

    import 2
    expect(limit_line.text).to eq "18 of 20 imports left this hour"
    expect(limit_line["class"]).not_to include("import-limit--low")

    import 15
    expect(limit_line.text).to eq "3 of 20 imports left this hour"
    expect(limit_line["class"]).to include("import-limit--low")
  end

  it "counts an admin's imports out of #{StartImportService::ADMIN_HOURLY_LIMIT}" do
    delete logout_path
    log_in_as create(:user, :admin)

    expect(limit_line.text).to eq "50 of 50 imports left this hour"
  end
end
