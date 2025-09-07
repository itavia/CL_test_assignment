class RouteSearchForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :carrier, :string
  attribute :origin_iata, :string
  attribute :destination_iata, :string
  attribute :departure_from, :date
  attribute :departure_to, :date

  validates :carrier, :origin_iata, :destination_iata, :departure_from, :departure_to, presence: true
  validates :origin_iata, :destination_iata, format: { with: /\A[A-Z]{3}\z/, message: "must be a 3-letter uppercase IATA code" }
  validate :departure_to_cannot_be_before_departure_from

  private

  def departure_to_cannot_be_before_departure_from
    if departure_from.present? && departure_to.present? && departure_to < departure_from
      errors.add(:departure_to, "can't be before departure_from")
    end
  end
end
