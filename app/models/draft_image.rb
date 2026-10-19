# A screenshot an import reads (StartImportService), in the order picked. Deleted once Claude has read it.
class DraftImage < ApplicationRecord
  # What Claude reads, by what the file's bytes say it is rather than what the browser called it
  CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  # Within Claude's 5 MB per picture once base64-encoded. The phone shrinks screenshots well below this.
  MAX_BYTES = 3.megabytes

  belongs_to :draft

  validates :content_type, inclusion: { in: CONTENT_TYPES }
  validates :data, presence: true, length: { maximum: MAX_BYTES }

  def self.from_upload(file, position:)
    data = file.read.b
    new(position: position, data: data, content_type: Marcel::MimeType.for(StringIO.new(data)))
  end
end
