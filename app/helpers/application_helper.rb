module ApplicationHelper
  # Shows each image as its alt text. Text can come from imported pages or the assistant, and an image would load from
  # someone else's server as soon as it's shown, with whatever its address carries.
  class MarkdownWithoutImages < Redcarpet::Render::HTML
    def image(_link, _title, alt_text) = ERB::Util.html_escape(alt_text.to_s)
  end

  def render_markdown(text)
    return "" if text.blank?

    renderer = MarkdownWithoutImages.new(
      filter_html: true,
      safe_links_only: true,
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener" }
    )
    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      no_intra_emphasis: true
    )
    markdown.render(text).html_safe
  end

  # The navbar's links, as [label, path]: in the bar on a wide page, in ☰ when it's folded.
  def navbar_links
    links = [ [ t("shared.navbar.home"), root_path ] ]
    return links unless logged_in?

    links + [ [ t("shared.navbar.recipes"), recipes_path ], [ t("shared.navbar.meal_plans"), meal_plans_path ] ]
  end

  # Stimulus controllers on <body>, for what any page can open: the Edit-aisles pop-up and the assistant panel.
  def body_controllers
    return unless logged_in?

    [ "aisle-editor", ("assistant-panel" if assistant_available?) ].compact.join(" ")
  end

  def assistant_panel_id = dom_id(current_user, :assistant_panel)
end
