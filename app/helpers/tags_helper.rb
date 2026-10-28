module TagsHelper
  # A tag in the recipe form's tag box: its emoji, if it has one, and its name
  def tag_label(tag) = [ tag.icon, tag.name ].compact.join(" ")
end
