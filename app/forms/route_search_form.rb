# A Form Object to validate parameters for the flight search.
# It uses ActiveModel::Validations to define rules and provides
# type casting for attributes.
class RouteSearchForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # @!attribute carrier
  #   @return [String] The airline carrier code (e.g., 'S7').
  attribute :carrier, :string
  # @!attribute origin_iata
  #   @return [String] The 3-letter IATA code for the origin airport.
  attribute :origin_iata, :string
  # @!attribute destination_iata
  #   @return [String] The 3-letter IATA code for the destination airport.
  attribute :destination_iata, :string
  # @!attribute departure_from
  #   @return [Date] The start of the departure date window.
  attribute :departure_from, :date
  # @!attribute departure_to
  #   @return [Date] The end of the departure date window.
  attribute :departure_to, :date

  validates :carrier, :origin_iata, :destination_iata, :departure_from, :departure_to, presence: true
  validates :origin_iata, :destination_iata, format: { with: /\A[A-Z]{3}\z/, message: "must be a 3-letter uppercase IATA code" }
  validate :departure_to_cannot_be_before_departure_from

  private

  # Custom validation to ensure the date range is logical.
  def departure_to_cannot_be_before_departure_from
    if departure_from.present? && departure_to.present? && departure_to < departure_from
      errors.add(:departure_to, "can't be before departure_from")
    end
  end
end
