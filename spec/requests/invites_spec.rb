require "rails_helper"

RSpec.describe "Invites", type: :request do
  context "for an admin" do
    let(:admin) { create(:user, :admin) }

    before { log_in_as admin }

    it "lists invites with the links that can still be used" do
      open = create(:invite, note: "Mum")
      create(:invite, note: "Old friend", expires_at: 1.day.ago)

      get invites_path

      expect(response.body).to include("Mum", "Old friend", "Expired 1 day ago", register_url(invite_token: open.token))
      statuses = Nokogiri::HTML(response.body).css(".status-pill").map(&:text)
      expect(statuses).to eq %w[Expired Active] # newest first
    end

    it "creates an invite for someone" do
      post invites_path, params: { invite: { note: "Mum" } }

      expect(response).to redirect_to(invites_path)
      expect(Invite.sole).to have_attributes(note: "Mum", created_by: admin)
    end

    it "deletes an unused invite, but keeps a used one" do
      unused = create(:invite)
      used = create(:invite, used_at: 1.day.ago, used_by: create(:user))

      delete invite_path(unused)
      delete invite_path(used)

      expect(Invite.all).to contain_exactly(used)
      expect(flash[:alert]).to eq "A used invite can't be deleted."
    end
  end

  it "is only for admins" do
    invite = create(:invite)
    log_in_as create(:user)

    get invites_path
    expect(response).to redirect_to(root_path)

    post invites_path, params: { invite: { note: "Me" } }
    delete invite_path(invite)

    expect(Invite.all).to contain_exactly(invite)
  end
end
