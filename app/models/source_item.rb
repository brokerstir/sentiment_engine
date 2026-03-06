class SourceItem < ApplicationRecord
  # Add optional: true to stop the validation from blocking the save.
  # The database NOT NULL constraint will still protect your data integrity.
  belongs_to :trend
  has_many :sentiment_analyses, dependent: :destroy

  validates :headline, :url, presence: true
end
