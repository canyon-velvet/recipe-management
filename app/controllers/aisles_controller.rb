# The Edit-aisles pop-up loads #index into a Turbo Frame; each change redirects back to it, except a move, which the
# pop-up has already shown.
# #create also answers JSON for adding an aisle from the create-ingredient pop-up's aisle box.
class AislesController < ApplicationController
  before_action :set_aisle, only: [ :update, :destroy, :move ]

  def index
    @aisles = current_user.aisles.ordered
  end

  def create
    aisle = Aisle.add_before_other(current_user, aisle_params[:name])

    respond_to do |format|
      format.json do
        if aisle.persisted?
          render json: { id: aisle.id, name: aisle.name }, status: :created
        else
          render json: { errors: aisle.errors.full_messages }, status: :unprocessable_entity
        end
      end
      format.html { aisle.persisted? ? redirect_to(aisles_path, status: :see_other) : render_editor(new_aisle: aisle) }
    end
  end

  def update
    if @aisle.update(aisle_params)
      redirect_to aisles_path, status: :see_other
    else
      render_editor(invalid: @aisle)
    end
  end

  def destroy
    if @aisle.destroy_moving_ingredients_to_other
      redirect_to aisles_path, status: :see_other
    else
      render_editor(invalid: @aisle)
    end
  end

  # Dragged into a new place in the pop-up, which already shows it there
  def move
    @aisle.move_to(params.require(:position).to_i)
    head :no_content
  end

  private

  def set_aisle
    @aisle = current_user.aisles.find(params[:id])
  end

  def aisle_params
    params.require(:aisle).permit(:name)
  end

  # Shows the editor again with the failed aisle in place, so its row keeps what was typed and shows the error.
  def render_editor(invalid: nil, new_aisle: nil)
    @aisles = current_user.aisles.ordered.map { |aisle| aisle.id == invalid&.id ? invalid : aisle }
    @new_aisle = new_aisle
    render :index, status: :unprocessable_entity
  end
end
