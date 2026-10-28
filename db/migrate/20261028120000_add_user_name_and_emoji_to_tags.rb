# Tags a user makes for themselves (Korean, Instant Pot…), beside the built-in ones everyone shares (no user). Theirs
# keep the name as typed, untranslated, and can have an emoji of their choosing.
class AddUserNameAndEmojiToTags < ActiveRecord::Migration[8.1]
  def change
    add_reference :tags, :user, foreign_key: true
    add_column :tags, :name, :string, limit: 30
    add_column :tags, :emoji, :string, limit: 10
    add_check_constraint :tags, "user_id IS NULL OR name IS NOT NULL", name: "tags_users_named"
    # A user's tag names are unique, ignoring case
    add_index :tags, "user_id, lower(name)", unique: true, where: "user_id IS NOT NULL",
                                              name: "index_tags_on_user_id_and_lower_name"

    # Undone first: without their user and name, users' tags would be left as built-in tags with no translation
    reversible do |direction|
      direction.down do
        execute "DELETE FROM recipe_tags WHERE tag_id IN (SELECT id FROM tags WHERE user_id IS NOT NULL)"
        execute "DELETE FROM tags WHERE user_id IS NOT NULL"
      end
    end
  end
end
