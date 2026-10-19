# Screenshots an import reads (StartImportService), kept only until Claude has read them. In the database, so the web
# and worker processes share them without file storage.
class CreateDraftImages < ActiveRecord::Migration[8.1]
  def change
    create_table :draft_images do |t|
      t.references :draft, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :content_type, null: false
      t.binary :data, null: false
      t.timestamps
    end
    # How many screenshots a draft was imported from, shown in the Draft box after they're deleted
    add_column :drafts, :screenshot_count, :integer, default: 0, null: false
  end
end
