# Tags a user makes for themselves (Korean, Instant Pot…), beside the built-in ones everyone shares (no user). Theirs
# keep the name as typed, untranslated, and can have an emoji of their choosing.
class AddUserNameAndEmojiToTags < ActiveRecord::Migration[8.1]
  def change
    add_reference :tags, :user, foreign_key: true
    add_column :tags, :name, :string
    add_column :tags, :emoji, :string
    # A user's tag names are unique, ignoring case
    add_index :tags, "user_id, lower(name)", unique: true, where: "user_id IS NOT NULL",
                                              name: "index_tags_on_user_id_and_lower_name"
  end
end
