# The import form: a recipe link, screenshots of a recipe, or the recipe's text pasted in. Starting an import puts a
# Draft in the Draft box; ImportRecipeJob reads it in the background.
class ImportsController < ApplicationController
  # The form's ways in, one at a time: a link (its site is the source), screenshots (with the recipe's name and where
  # they're from), or the recipe's text (with where it's from)
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
    set_source
  end

  # Where text or screenshots are from: one of the user's sources, or a new one's name (created when the recipe is
  # saved). Pasting the text of a link that was blocked starts from that link's site.
  def set_source
    @source = current_user.sources.find_by(id: params[:source_id]) if params[:source_id].present?
    @new_source_name = params[:new_source_name].to_s.squish.presence
    return unless @mode == "text" && @url.present? && !@source && !@new_source_name

    site = RecipeLink.site_name(@url)
    @source = current_user.sources.named(site).first if site
    @new_source_name = site unless @source
  end

  def import_params
    source_name = @source&.name || @new_source_name
    case @mode
    when "screenshot"
      { title: @title, screenshots: Array(params[:screenshots]).grep(ActionDispatch::Http::UploadedFile),
        source_name: source_name }
    when "text" then { url: @url, text: @text, source_name: source_name }
    else { url: @url }
    end
  end

  def imports_left = @imports_left ||= StartImportService.imports_left(current_user)
end
