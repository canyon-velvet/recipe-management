# A recipe has its own icon now (recipes.icon, filled from its tags' emoji), so tags have none
class RemoveEmojiFromTags < ActiveRecord::Migration[8.1]
  def change
    remove_column :tags, :emoji, :string, limit: 10
  end
end
