# The Preview tab of a markdown field. It renders on the server with the same helper the saved text is shown with, so
# the preview matches it and imported text can't run HTML in the browser.
class MarkdownPreviewsController < ApplicationController
  def create
    render html: helpers.render_markdown(params[:text].to_s)
  end
end
