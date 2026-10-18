class RecipeIngredient < ApplicationRecord
  belongs_to :recipe
  # autosave validates and saves an ingredient that is new to the user along with the recipe.
  belongs_to :ingredient, autosave: true

  # A draft's ingredient the user doesn't have yet: its name and the aisle chosen for it in the review form.
  attr_accessor :new_ingredient_name, :new_aisle_id

  validates :ingredient_id, uniqueness: { scope: :recipe_id }
  validate :ingredient_must_belong_to_recipe_owner
  validate :ingredient_must_be_listed_once

  before_validation :use_new_ingredient, if: -> { ingredient.nil? && new_ingredient_name.present? }

  # Rows whose ingredient's name contains any of the texts, ignoring case.
  scope :named_like, ->(*texts) {
    patterns = texts.map { |text| "%#{sanitize_sql_like(text)}%" }
    joins(:ingredient).where("ingredients.name ILIKE ANY (ARRAY[?])", patterns)
  }

  # Shown as a "new" row in the form until the recipe saves.
  def new_ingredient? = new_ingredient_name.present? && (ingredient.nil? || ingredient.new_record?)

  private

  # Reuses the user's ingredient with that name, else one another row of this recipe is already creating,
  # else builds it in the chosen aisle (Other if none).
  def use_new_ingredient
    user = recipe.user
    self.ingredient = user.ingredients.named(new_ingredient_name).first ||
                      sibling_new_ingredient ||
                      user.ingredients.build(name: new_ingredient_name,
                                             aisle: user.aisles.find_by(id: new_aisle_id) || user.aisles.find_by(key: "other"))
  end

  def sibling_new_ingredient
    recipe.recipe_ingredients.filter_map(&:ingredient)
          .find { |other| other.new_record? && other.name.casecmp?(new_ingredient_name.strip) }
  end

  # Two rows with the same ingredient would hit the unique index on save; the uniqueness validation above only
  # sees saved rows, not unsaved siblings or ingredients that are themselves new.
  def ingredient_must_be_listed_once
    return unless ingredient

    duplicate = recipe.recipe_ingredients.any? do |other|
      next false if other.equal?(self) || other.marked_for_destruction? || other.ingredient.nil?

      other.ingredient.equal?(ingredient) || (ingredient.persisted? && other.ingredient_id == ingredient.id)
    end
    errors.add(:ingredient, :taken) if duplicate
  end

  def ingredient_must_belong_to_recipe_owner
    errors.add(:ingredient, :invalid) if ingredient && recipe && ingredient.user_id != recipe.user_id
  end
end
