class SourcesController < ApplicationController
  include PickerJson

  def search
    render_names current_user.sources.search_by_name(params[:q])
  end

  def create
    render_created current_user.sources.create(source_params)
  end

  private

  def source_params
    params.require(:source).permit(:name)
  end
end
