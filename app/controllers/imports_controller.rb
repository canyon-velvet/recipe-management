# The import form: a recipe link, screenshots of a recipe, or the recipe's text pasted in. Starting an import puts a
# Draft in the Draft box; ImportRecipeJob reads it in the background.
class ImportsController < ApplicationController
  # The form's ways in, one at a time: a link, screenshots (with the recipe's name), or the recipe's text (with its
  # link, if any)
  MODES = %w[link screenshot text].freeze

  before_action :set_form, only: [ :new, :create ]

  helper_method :imports_left

  def new
  end

  def create
    @result = StartImportService.new(user: current_user, **import_params).call

    if @result.success?
      redirect_to drafts_path, notice: t("flash.import_started"), status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_form
    @mode = params[:mode].presence_in(MODES) || (params[:paste].present? ? "text" : "link")
    @url = params[:url].to_s.strip
    # Text typed under Text and left there when Link was chosen again isn't sent for reading
    @text = @mode == "text" ? params[:text].to_s : ""
    @title = params[:title].to_s
    @has_claude = CleanRecipeService.available?
  end

  def import_params
    return { url: @url, text: @text } unless @mode == "screenshot"

    { title: @title, screenshots: Array(params[:screenshots]).grep(ActionDispatch::Http::UploadedFile) }
  end

  def imports_left = @imports_left ||= StartImportService.imports_left(current_user)
end
