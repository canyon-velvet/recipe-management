# A model with a name the user types: one found by its exact name (ignoring case and spaces around it), or the ones
# whose name contains some text, with % and _ taken as typed.
module NameSearchable
  extend ActiveSupport::Concern

  included do
    scope :named, ->(name) { where("lower(#{table_name}.name) = lower(?)", name.strip) }
    scope :search_by_name, ->(query) {
      where("#{table_name}.name ILIKE ?", "%#{sanitize_sql_like(query.to_s)}%") if query.present?
    }
  end
end
