# The record it points to (an ingredient's aisle, a recipe's source) must be the record's own user's.
class SameUserValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :invalid) if value && record.user && value.user_id != record.user_id
  end
end
