# The JSON the recipe form's pickers read (the ingredient and source autocompletes, their create pop-ups, and the
# aisle box): the names found, and a record just created or why it couldn't be.
module PickerJson
  private

  def render_names(records)
    render json: records.order(:name).limit(20).map { |record| record.slice(:id, :name) }
  end

  # extra: more for the picker to show, such as a tag's emoji and name together
  def render_created(record, **extra)
    if record.persisted?
      render json: record.slice(:id, :name).merge(extra), status: :created
    else
      render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
