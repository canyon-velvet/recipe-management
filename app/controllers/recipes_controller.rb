class RecipesController < ApplicationController
  before_action :set_recipe, only: [ :show, :edit, :update, :destroy ]
  before_action :set_form_data, only: [ :new, :create, :edit, :update ]
  before_action :set_draft, only: [ :new, :create ]

  def index
    # An unknown or malformed ?tag= shows all recipes, so the list and the catalog always agree.
    @selected_tag = Tag.find_by(key: params[:tag]) if params[:tag].is_a?(String) && params[:tag].present?
    recipes = current_user.recipes.includes(:source, :tags)
                          .search_by_name_or_ingredient(params[:q])
                          .tagged(@selected_tag&.key)
                          .order(updated_at: :desc)
    @pagy, @recipes = pagy(recipes)
    @tags_by_kind = Tag.by_kind
    @tag_counts = Tag.recipe_counts_for(current_user)
  end

  def search
    recipes = current_user.recipes.includes(:tags).search_by_name_or_ingredient(params[:q]).order(:name).limit(20)
    render json: recipes.map { |r| { id: r.id, name: r.name, tags: r.tags.map(&:name) } }
  end

  def show
  end

  def new
    @recipe = @draft ? BuildRecipeFromDraftService.new(@draft).call : Recipe.new
  end

  def create
    @recipe = current_user.recipes.build(recipe_params)
    ensure_own_records!

    if save_recipe
      redirect_to recipe_path(@recipe), notice: t(@draft ? "flash.recipe_saved_from_draft" : "flash.recipe_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  # In one transaction, so an edit that fails saves nothing: assigning tag_ids to a saved recipe writes them at once.
  def update
    saved = Recipe.transaction do
      @recipe.assign_attributes(recipe_params)
      ensure_own_records!
      @recipe.save || raise(ActiveRecord::Rollback)
    end

    if saved
      sync_grocery_lists(@recipe.meal_plans)
      redirect_to recipe_path(@recipe), notice: t("flash.recipe_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    meal_plans = @recipe.meal_plans.to_a
    @recipe.destroy
    sync_grocery_lists(meal_plans)
    redirect_to recipes_path, notice: t("flash.recipe_deleted")
  end

  private

  def set_recipe
    @recipe = current_user.recipes.includes(:source, :tags, :steps, recipe_ingredients: :ingredient).find(params[:id])
  end

  # Reviewing a Ready draft from the Draft box prefills the form; saving it empties the draft.
  def set_draft
    @draft = current_user.drafts.ready.find(params[:draft_id]) if params[:draft_id].present?
  end

  # The form's source and ingredients must be the user's own. The models refuse to save anyone else's, but by then
  # the form would show its name, so another user's id is not found at all.
  def ensure_own_records!
    records = [ @recipe.source, *@recipe.recipe_ingredients.map(&:ingredient) ].compact
    raise ActiveRecord::RecordNotFound unless records.all? { |record| record.user_id == current_user.id }
  end

  # Both happen or neither does, so a saved draft never stays in the Draft box.
  def save_recipe
    Recipe.transaction do
      next false unless @recipe.save

      @draft&.destroy!
      true
    end
  end

  # The grocery lists of the meal plans the recipe is in follow its ingredients (or its removal)
  def sync_grocery_lists(meal_plans)
    meal_plans.each { |meal_plan| SyncGroceryListService.new(meal_plan).call }
  end

  def set_form_data
    @aisles = current_user.aisles.ordered
    @tags = Tag.ordered
  end

  def recipe_params
    params.require(:recipe).permit(
      :name, :description, :source_id, :new_source_name, :source_url, *Recipe::COUNT_LIMITS.keys, tag_ids: [],
      recipe_ingredients_attributes: [ :id, :ingredient_id, :new_ingredient_name, :new_aisle_id, :quantity, :unit, :_destroy ],
      steps_attributes: [ :id, :body, :position, :_destroy ]
    )
  end
end
