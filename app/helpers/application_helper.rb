module ApplicationHelper
  def render_markdown(text)
    return "" if text.blank?

    # No images: text can come from imported pages or the assistant, and an image would load from someone else's
    # server as soon as it's shown, with whatever its address carries.
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      no_images: true,
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

  # Stimulus controllers on <body>, for what any page can open: the Edit-aisles pop-up and the assistant panel.
  def body_controllers
    return unless logged_in?

    [ "aisle-editor", ("assistant-panel" if assistant_available?) ].compact.join(" ")
  end

  def assistant_panel_id = dom_id(current_user, :assistant_panel)
end
