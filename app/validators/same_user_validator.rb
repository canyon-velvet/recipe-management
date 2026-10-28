# The records it points to (an ingredient's aisle, a recipe's source or tags) must be the record's own user's.
# allow_shared: also allows ones with no user, shared by everyone (the built-in tags).
class SameUserValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless record.user

    allowed = ->(item) { item.user_id == record.user_id || (options[:allow_shared] && item.user_id.nil?) }
    record.errors.add(attribute, :invalid) unless Array.wrap(value).all?(&allowed)
  end
end
