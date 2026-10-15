# Idempotent seed data — safe to run multiple times

# Recipe tags, grouped by kind. Display names live in config/locales under `tags` and `tag_kinds`.
{
  "meal" => %w[breakfast lunch dinner snack dessert appetizer soup salad drink],
  "cuisine" => %w[chinese italian japanese mexican american],
  "diet" => %w[vegetarian vegan gluten_free],
  "flavor" => %w[spicy],
  "convenience" => %w[quick kid_friendly make_ahead]
}.flat_map { |kind, keys| keys.map { [ kind, _1 ] } }.each.with_index(1) do |(kind, key), i|
  Tag.find_or_initialize_by(key: key).update!(kind: kind, position: i * 10)
end
puts "Seeded #{Tag.count} tags"

# Admin user (only in development)
if Rails.env.development?
  User.find_or_create_by!(username: "admin") do |user|
    user.password = "password"
    user.admin = true
  end
  puts "Seeded admin user (username: admin, password: password)"
end

# Aisles are per user; new users get the defaults on sign-up. Display names live in config/locales under `aisles`.
# Only users with no aisles at all get them here: the seeds run on every deploy, and must not bring back a default
# aisle someone deleted.
users = User.where.missing(:aisles)
puts "Added default aisles for #{users.count} users"
users.find_each { |user| Aisle.create_defaults_for(user) }

# Sample drafts for the admin, one per status, so the Draft box can be tried before the importer exists.
if Rails.env.development?
  admin = User.find_by!(username: "admin")
  aisle_id = ->(key) { admin.aisles.find_by(key: key)&.id }

  admin.drafts.find_or_create_by!(source_url: "https://example.com/recipes/scallion-pancakes") do |draft|
    draft.status = :ready
    draft.data = {
      "name" => "葱油饼",
      "description" => "Flaky pan-fried scallion pancakes.",
      "source_name" => "Example Kitchen",
      "ingredients" => [
        { "name" => "面粉", "quantity" => "300", "unit" => "g", "aisle_id" => aisle_id.("pantry") },
        { "name" => "葱", "quantity" => "4", "unit" => "根", "aisle_id" => aisle_id.("produce") },
        { "name" => "盐", "quantity" => "1", "unit" => "tsp", "aisle_id" => aisle_id.("spices_seasonings") }
      ],
      "steps" => [ "Mix the flour with warm water and rest the dough.", "Roll out, oil, salt, add scallions, roll up.",
                   "Flatten and pan-fry until golden on both sides." ],
      "tags" => %w[chinese snack]
    }
  end
  admin.drafts.find_or_create_by!(source_url: "https://example.com/recipes/still-reading")
  admin.drafts.find_or_create_by!(source_url: "https://example.com/recipes/blocked") { |draft| draft.status = :failed }
  puts "Seeded #{admin.drafts.count} sample drafts for admin"
end
