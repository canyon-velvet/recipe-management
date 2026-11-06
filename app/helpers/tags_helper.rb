module TagsHelper
  # The tag box's option for a tag, with its name for the box to tell a new name from one already there (data-data)
  def tag_option(tag) = [ tag.name, tag.id, { data: { data: { name: tag.name }.to_json } } ]
end
