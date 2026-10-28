module TagsHelper
  # A tag in the recipe form's tag box: its emoji, if it has one, and its name
  def tag_label(tag) = [ tag.icon, tag.name ].compact.join(" ")

  # The tag box's option for a tag, with its name for the box to tell a new name from one already there (data-data)
  def tag_option(tag) = [ tag_label(tag), tag.id, { data: { data: { name: tag.name }.to_json } } ]
end
