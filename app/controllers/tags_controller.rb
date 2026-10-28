# The recipe form's New tag pop-up: a tag of the user's own, answered with what the tag box shows for it.
class TagsController < ApplicationController
  include PickerJson

  def create
    tag = current_user.tags.build(tag_params)
    begin
      tag.save
    rescue ActiveRecord::RecordNotUnique # the same name sent twice at once: the index caught the second
      tag.errors.add(:name, :taken)
    end
    render_created tag, label: helpers.tag_label(tag)
  end

  private

  def tag_params = params.expect(tag: [ :name, :kind, :emoji ])
end
