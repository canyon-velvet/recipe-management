# One emoji as people pick it: a single character on screen, such as 🍜, 🌶️ (with its variation selector) or 🇰🇷,
# and short, so it isn't one with marks piled on it or dozens joined into one
class OneEmojiValidator < ActiveModel::EachValidator
  # The longest emoji people pick (a family, a flag of a country's region) are about this many code points
  MAX_LENGTH = 10
  # Drawn as an emoji, not text-style like ©: a flag is two regional indicators, a keycap a digit, # or * with ⃣
  START = /\A(
    \p{Regional_Indicator}{2} | (?!\p{Regional_Indicator})\p{Emoji_Presentation} | \p{Extended_Pictographic}\u{FE0F} |
    [\#*0-9]\u{FE0F}?\u{20E3}
  )/x

  def validate_each(record, attribute, value)
    one = value.length <= MAX_LENGTH && value.grapheme_clusters.one? && value.match?(START)
    record.errors.add(attribute, :invalid) unless one
  end
end
