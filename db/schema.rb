# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_20_120200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "aisles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "key"
    t.integer "position", null: false
    t.bigint "user_id", null: false
    t.string "name"
    t.index "user_id, lower((name)::text)", name: "index_aisles_on_user_id_and_lowercase_name", unique: true
    t.index ["user_id", "key"], name: "index_aisles_on_user_id_and_key", unique: true
    t.index ["user_id", "position"], name: "index_aisles_on_user_id_and_position"
    t.index ["user_id"], name: "index_aisles_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_conversations_on_user_id_and_created_at"
  end

  create_table "draft_images", force: :cascade do |t|
    t.bigint "draft_id", null: false
    t.integer "position", null: false
    t.string "content_type", null: false
    t.binary "data", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["draft_id"], name: "index_draft_images_on_draft_id"
  end

  create_table "drafts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "reading", null: false
    t.string "source_url"
    t.text "source_text"
    t.string "failure_reason"
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "screenshot_count", default: 0, null: false
    t.index ["user_id", "created_at"], name: "index_drafts_on_user_id_and_created_at"
    t.index ["user_id", "source_url"], name: "index_drafts_on_user_id_and_source_url", unique: true, where: "(source_url IS NOT NULL)"
  end

  create_table "grocery_list_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "grocery_list_id", null: false
    t.boolean "in_pantry", default: false, null: false
    t.bigint "ingredient_id", null: false
    t.integer "occurrence_count", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["grocery_list_id", "ingredient_id"], name: "index_grocery_list_items_uniqueness", unique: true
    t.index ["grocery_list_id"], name: "index_grocery_list_items_on_grocery_list_id"
    t.index ["ingredient_id"], name: "index_grocery_list_items_on_ingredient_id"
  end

  create_table "grocery_lists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "meal_plan_id", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_plan_id"], name: "index_grocery_lists_on_meal_plan_id", unique: true
  end

  create_table "ingredients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "aisle_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_ingredients_on_user_id_and_lowercase_name", unique: true
    t.index ["aisle_id"], name: "index_ingredients_on_aisle_id"
    t.index ["user_id"], name: "index_ingredients_on_user_id"
  end

  create_table "invites", force: :cascade do |t|
    t.string "token", null: false
    t.bigint "created_by_id", null: false
    t.bigint "used_by_id"
    t.datetime "used_at"
    t.datetime "expires_at", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_invites_on_created_by_id"
    t.index ["token"], name: "index_invites_on_token", unique: true
    t.index ["used_by_id"], name: "index_invites_on_used_by_id"
  end

  create_table "meal_plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.string "name"
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "start_date"], name: "index_meal_plans_on_user_id_and_start_date", unique: true
    t.index ["user_id"], name: "index_meal_plans_on_user_id"
  end

  create_table "meal_slot_recipes", force: :cascade do |t|
    t.boolean "add_to_grocery_list", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "meal_slot_id", null: false
    t.bigint "recipe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_slot_id", "recipe_id"], name: "index_meal_slot_recipes_on_meal_slot_id_and_recipe_id", unique: true
    t.index ["meal_slot_id"], name: "index_meal_slot_recipes_on_meal_slot_id"
    t.index ["recipe_id"], name: "index_meal_slot_recipes_on_recipe_id"
  end

  create_table "meal_slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.bigint "meal_plan_id", null: false
    t.integer "meal_type", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_plan_id", "day_of_week", "meal_type"], name: "index_meal_slots_uniqueness", unique: true
    t.index ["meal_plan_id"], name: "index_meal_slots_on_meal_plan_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "role", null: false
    t.text "content", default: "", null: false
    t.string "status", default: "done", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "agent"
    t.bigint "recipe_ids", default: [], null: false, array: true
    t.jsonb "card_reasons", default: {}, null: false
    t.bigint "draft_ids", default: [], null: false, array: true
    t.jsonb "preference_suggestions", default: [], null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.check_constraint "agent::text = ANY (ARRAY['router'::character varying, 'recommend'::character varying, 'import'::character varying]::text[])", name: "messages_agent_known"
    t.check_constraint "role::text = ANY (ARRAY['user'::character varying, 'assistant'::character varying]::text[])", name: "messages_role_known"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'done'::character varying, 'failed'::character varying]::text[])", name: "messages_status_known"
  end

  create_table "preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "category", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "user_id, category, lower((value)::text)", name: "index_preferences_on_user_category_and_value", unique: true
    t.index ["user_id"], name: "index_preferences_on_user_household", unique: true, where: "((category)::text = 'household'::text)"
    t.check_constraint "category::text = ANY (ARRAY['diet'::character varying, 'likes'::character varying, 'dislikes'::character varying, 'avoid'::character varying, 'household'::character varying]::text[])", name: "preferences_category_known"
  end

  create_table "recipe_ingredients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "ingredient_id", null: false
    t.string "quantity"
    t.bigint "recipe_id", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["ingredient_id"], name: "index_recipe_ingredients_on_ingredient_id"
    t.index ["recipe_id", "ingredient_id"], name: "index_recipe_ingredients_on_recipe_id_and_ingredient_id", unique: true
    t.index ["recipe_id"], name: "index_recipe_ingredients_on_recipe_id"
  end

  create_table "recipe_steps", force: :cascade do |t|
    t.bigint "recipe_id", null: false
    t.integer "position", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id", "position"], name: "index_recipe_steps_on_recipe_id_and_position"
    t.index ["recipe_id"], name: "index_recipe_steps_on_recipe_id"
  end

  create_table "recipe_tags", force: :cascade do |t|
    t.bigint "recipe_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id", "tag_id"], name: "index_recipe_tags_on_recipe_id_and_tag_id", unique: true
    t.index ["recipe_id"], name: "index_recipe_tags_on_recipe_id"
    t.index ["tag_id"], name: "index_recipe_tags_on_tag_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "source_url"
    t.integer "servings"
    t.integer "prep_minutes"
    t.integer "cook_minutes"
    t.integer "total_minutes"
    t.string "share_token"
    t.index ["share_token"], name: "index_recipes_on_share_token", unique: true
    t.index ["source_id"], name: "index_recipes_on_source_id"
    t.index ["user_id", "source_url"], name: "index_recipes_on_user_id_and_source_url", unique: true, where: "(source_url IS NOT NULL)"
    t.index ["user_id"], name: "index_recipes_on_user_id"
    t.check_constraint "cook_minutes > 0", name: "recipes_cook_minutes_positive"
    t.check_constraint "prep_minutes > 0", name: "recipes_prep_minutes_positive"
    t.check_constraint "servings > 0", name: "recipes_servings_positive"
    t.check_constraint "total_minutes > 0", name: "recipes_total_minutes_positive"
  end

  create_table "runs", force: :cascade do |t|
    t.bigint "message_id", null: false
    t.string "model", null: false
    t.string "status", default: "running", null: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.string "error"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_runs_on_message_id", unique: true
    t.check_constraint "status::text = ANY (ARRAY['running'::character varying, 'succeeded'::character varying, 'failed'::character varying]::text[])", name: "runs_status_known"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_sources_on_user_id_and_lowercase_name", unique: true
    t.index ["user_id"], name: "index_sources_on_user_id"
  end

  create_table "steps", force: :cascade do |t|
    t.bigint "run_id", null: false
    t.string "name", null: false
    t.string "model"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.string "error"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "input"
    t.jsonb "output"
    t.index ["run_id"], name: "index_steps_on_run_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "key", null: false
    t.string "kind", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_tags_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.string "time_zone", default: "Central Time (US & Canada)", null: false
    t.index "lower((username)::text)", name: "index_users_on_lowercase_username", unique: true
  end

  add_foreign_key "aisles", "users"
  add_foreign_key "conversations", "users"
  add_foreign_key "draft_images", "drafts", on_delete: :cascade
  add_foreign_key "drafts", "users"
  add_foreign_key "grocery_list_items", "grocery_lists"
  add_foreign_key "grocery_list_items", "ingredients"
  add_foreign_key "grocery_lists", "meal_plans"
  add_foreign_key "ingredients", "aisles"
  add_foreign_key "ingredients", "users"
  add_foreign_key "invites", "users", column: "created_by_id", on_delete: :cascade
  add_foreign_key "invites", "users", column: "used_by_id", on_delete: :nullify
  add_foreign_key "meal_plans", "users"
  add_foreign_key "meal_slot_recipes", "meal_slots"
  add_foreign_key "meal_slot_recipes", "recipes"
  add_foreign_key "meal_slots", "meal_plans"
  add_foreign_key "messages", "conversations"
  add_foreign_key "preferences", "users"
  add_foreign_key "recipe_ingredients", "ingredients"
  add_foreign_key "recipe_ingredients", "recipes"
  add_foreign_key "recipe_steps", "recipes"
  add_foreign_key "recipe_tags", "recipes"
  add_foreign_key "recipe_tags", "tags"
  add_foreign_key "recipes", "sources"
  add_foreign_key "recipes", "users"
  add_foreign_key "runs", "messages"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "sources", "users"
  add_foreign_key "steps", "runs"
end
