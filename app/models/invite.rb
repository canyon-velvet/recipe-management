# A link to sign up with (GLOSSARY). Signing up is by invitation only, because every account can spend the owner's
# Claude credits. An admin creates an invite, optionally noting who it's for, and sends its link; it works once, for a
# week.
class Invite < ApplicationRecord
  LIFETIME = 7.days

  has_secure_token
  belongs_to :created_by, class_name: "User"
  belongs_to :used_by, class_name: "User", optional: true

  attribute :expires_at, default: -> { LIFETIME.from_now }

  validates :note, length: { maximum: 100 }

  scope :usable, -> { where(used_at: nil, expires_at: Time.current..) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def used? = used_at.present?
  def usable? = !used? && expires_at.future?

  # Saves the new user and marks the invite used, together, if the invite can still be used. Locked, so two sign-ups
  # with the same link can't both get in: the second waits, then sees it used. False if it wasn't saved: the user has
  # errors, or the invite was used or expired meanwhile.
  def redeem(user)
    with_lock { usable? && user.save && update!(used_by: user, used_at: Time.current) }
  end
end
