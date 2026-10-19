module ImportsHelper
  # The fields for one or more of the import form's ways in (modes, e.g. "text screenshot"): a fieldset that's sent,
  # checked and shown only while one of its ways is chosen (the import-form controller keeps it in step)
  def import_panel(modes, current, &)
    tag.fieldset(class: "import-panel", disabled: modes.split.exclude?(current),
                 data: { import_form_target: "panel", modes: modes }, &)
  end
end
