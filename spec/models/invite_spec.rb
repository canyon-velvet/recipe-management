require "rails_helper"

RSpec.describe Invite do
  it "gets a token and expires a week after it's created" do
    invite = create(:invite)

    expect(invite.token).to be_present
    expect(invite.expires_at).to be_within(1.minute).of(1.week.from_now)
  end

  it "is usable until it's used or expires" do
    open = create(:invite)
    used = create(:invite, used_at: 1.hour.ago)
    expired = create(:invite, expires_at: 1.minute.ago)

    expect(Invite.usable).to contain_exactly(open)
    expect([ open, used, expired ].map(&:usable?)).to eq [ true, false, false ]
  end

  describe "#redeem" do
    let(:invite) { create(:invite) }

    it "creates the account and marks the invite used by it" do
      user = build(:user, username: "newcook")

      expect(invite.redeem(user)).to be true
      expect(user).to be_persisted
      expect(invite.reload).to have_attributes(used_by: user, used_at: be_present)
    end

    it "works once: a second sign-up with the same link, even one that loaded it before, gets nothing" do
      stale_copy = Invite.find(invite.id)
      invite.redeem(build(:user))

      second = build(:user)
      expect(stale_copy.redeem(second)).to be false
      expect(second).not_to be_persisted
    end

    it "leaves the invite unused when the account is invalid" do
      user = build(:user, username: "")

      expect(invite.redeem(user)).to be false
      expect(user.errors).to be_present
      expect(invite.reload.used_at).to be_nil
    end

    it "refuses once the invite has expired" do
      invite.update!(expires_at: 1.minute.ago)

      expect(invite.redeem(build(:user))).to be false
    end
  end
end
