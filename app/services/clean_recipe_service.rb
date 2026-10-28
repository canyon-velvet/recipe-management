# Has Claude turn what an import read (a page's structured recipe and text, pasted text, or screenshots) into Draft
# data: ingredients split into name / quantity / unit and placed in one of the user's aisles, steps split, tags
# suggested from the fixed list, all in the recipe's original language. Structured outputs make the reply
# always match RecipeCleanup's schema.
class CleanRecipeService
  MODEL = :"claude-haiku-4-5"
  MAX_TOKENS = 8_000
  # A page's structured recipe can be huge; only a recipe-sized part of it is sent (the page text is capped too).
  MAX_ITEMS = 60
  MAX_FIELD_CHARS = 500

  # Claude's answer. The SDK turns this class into the JSON schema the response must follow.
  class RecipeCleanup < Anthropic::BaseModel
    class Ingredient < Anthropic::BaseModel
      required :name, String, doc: "The ingredient only, e.g. 'flour' or '面粉'; no amount, unit or preparation note"
      required :quantity, String, doc: "The amount as written, e.g. '300', '1/2', '适量'; empty string if none"
      required :unit, String, doc: "The unit as written, e.g. 'g', 'cup', '个'; empty string if none"
      required :aisle_id, Integer, doc: "The id of the aisle this ingredient is shopped in, from the user's aisles"
    end

    required :is_recipe, Anthropic::Boolean, doc: "false if the input doesn't contain a recipe"
    required :name, String
    required :description, String, doc: "One or two sentences, from the source; empty string if none"
    required :ingredients, Anthropic::ArrayOf[Ingredient], doc: "Only the source's ingredient list; empty if it has none"
    required :steps, Anthropic::ArrayOf[String], doc: "One instruction per step, in order, without step numbers"
    required :tags, Anthropic::ArrayOf[String], doc: "Keys from the allowed tag list that clearly apply"
    required :tips, Anthropic::ArrayOf[String], doc: "The source's own tips or notes, each as written; empty if none"
    required :servings, Integer,
             doc: "How many people it serves, as the source states (the lower number of a range); 0 if not stated"
    required :prep_minutes, Integer, doc: "Prep time in minutes, as the source states; 0 if not stated"
    required :cook_minutes, Integer, doc: "Cooking time in minutes, as the source states; 0 if not stated"
    required :total_minutes, Integer, doc: "Total time in minutes, as the source states; 0 if not stated"
  end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You turn recipes that a user imported into clean, structured data for their recipe app.

    Keep the recipe's original language: don't translate names, ingredients or steps.
    Use only what the source says; don't invent ingredients, amounts or steps.
    The source may be screenshots instead of text, such as an AI's summary of a recipe video: read the recipe from
    them, in the order given, as one recipe.
    Take the ingredients only from the source's ingredient list (e.g. "Ingredients" or "用料"), exactly as listed.
    Never add an ingredient that is only mentioned in the steps, such as oil, salt or a seasoning used while
    cooking. If the source has no ingredient list, return no ingredients.
    Split every ingredient line into the ingredient's name, the quantity and the unit, keeping each as written.
    Put each ingredient in exactly one of the user's aisles, choosing the aisle a shopper would find it in;
    use the "Other" aisle when nothing fits.
    Give one step per instruction, in order, without numbering. Drop ads, stories and comments.
    Suggest tags only from the allowed list, and only ones that clearly apply.
    Copy the source's own tips, tricks or notes (e.g. "Tips", "Notes", "小贴士") into tips, each as written;
    don't repeat steps or ingredients there, and leave tips empty if the source has none.
    Fill servings and the prep, cook and total times only from what the source states, converting times to
    minutes; use 0 for anything it doesn't state. Servings is a number of people: a yield such as "1 loaf" is 0.
    If the input doesn't contain a recipe, set is_recipe to false and leave the lists empty.
  PROMPT

  # reason: :not_a_recipe or :cleanup_failed. Temporary problems (rate limits, outages) raise TemporaryError.
  class Error < ImportFailure; end

  class TemporaryError < StandardError; end

  def self.api_key = Rails.application.credentials.dig(:anthropic, :api_key) || ENV["ANTHROPIC_API_KEY"]

  def self.available? = api_key.present?

  # recipe: ExtractRecipeService's structured fields (or nil); text: page text or pasted text; images: screenshots,
  # each { media_type:, data: } with data as bytes.
  def initialize(user:, recipe:, text:, images: [], client: nil)
    @user = user
    @recipe = recipe
    @text = text
    @images = images
    @client = client
  end

  # Returns Draft data (see Draft) without source_name, which the caller knows best.
  def call
    cleanup = parse(request)
    # A recipe needs steps; ingredients may be missing when the source has no ingredient list.
    raise Error.new(:not_a_recipe) unless cleanup.is_recipe && cleanup.steps.any?

    to_draft_data(cleanup)
  end

  private

  def client = @client ||= Anthropic::Client.new(api_key: self.class.api_key)

  def request
    client.messages.create(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system_: SYSTEM_PROMPT,
      messages: [ { role: "user", content: [ *image_blocks, { type: "text", text: user_message } ] } ],
      output_config: { format: RecipeCleanup }
    )
  rescue Anthropic::Errors::RateLimitError, Anthropic::Errors::InternalServerError, Anthropic::Errors::APIConnectionError => e
    raise TemporaryError, "#{e.class}: #{e.message}"
  rescue Anthropic::Errors::APIStatusError => e
    raise Error.new(:cleanup_failed, "#{e.class}: #{e.message}")
  end

  def parse(message)
    raise Error.new(:cleanup_failed, "stopped: #{message.stop_reason}") unless message.stop_reason == :end_turn

    parsed = message.content.find { |block| block.type == :text }&.parsed
    raise Error.new(:cleanup_failed, "unparsable output: #{parsed.inspect}") unless parsed.is_a?(RecipeCleanup)

    parsed
  end

  def user_message
    <<~MESSAGE
      <aisles>
      #{aisles.map { |id, name| "#{id}: #{name}" }.join("\n")}
      </aisles>
      <allowed_tags>
      #{tags.map { |tag| "#{tag.key}: #{tag.name}" }.join("\n")}
      </allowed_tags>
      <structured_recipe>
      #{@recipe ? JSON.pretty_generate(capped_recipe) : "none"}
      </structured_recipe>
      <source_text>
      #{@text.presence || "none"}
      </source_text>
    MESSAGE
  end

  def image_blocks
    @images.map do |image|
      source = { type: "base64", media_type: image[:media_type], data: Base64.strict_encode64(image[:data]) }
      { type: "image", source: source }
    end
  end

  def capped_recipe
    @recipe.transform_values do |value|
      value.is_a?(Array) ? value.first(MAX_ITEMS).map { _1.to_s.first(MAX_FIELD_CHARS) } : value.to_s.first(MAX_FIELD_CHARS)
    end
  end

  # The built-in tags and the user's own: another user's are never sent to Claude, nor kept from its reply
  def tags = @tags ||= Tag.visible_to(@user).ordered.to_a

  def aisles = @aisles ||= @user.aisles.ordered.to_h { |aisle| [ aisle.id, aisle.name ] }

  def to_draft_data(cleanup)
    tag_keys = tags.map(&:key)
    {
      "name" => cleanup.name.strip,
      "description" => cleanup.description.strip,
      "ingredients" => cleanup.ingredients.map do |item|
        { "name" => item.name.strip, "quantity" => item.quantity.strip, "unit" => item.unit.strip,
          "aisle_id" => (item.aisle_id if aisles.key?(item.aisle_id)) }
      end,
      "steps" => cleanup.steps.map(&:strip).compact_blank,
      "tags" => cleanup.tags & tag_keys,
      "tips" => cleanup.tips.map(&:strip).compact_blank,
      **counts(cleanup)
    }
  end

  # The page's structured values are exact, so they win over Claude's reading; Claude's 0 means not stated.
  def counts(cleanup)
    Recipe::COUNT_LIMITS.keys.to_h do |key|
      claude_value = cleanup.public_send(key)
      [ key.to_s, @recipe&.dig(key) || (claude_value if claude_value.positive?) ]
    end
  end
end
