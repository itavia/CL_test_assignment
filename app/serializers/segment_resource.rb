class SegmentResource < ApplicationResource
  attributes :segment_number, :origin_iata, :destination_iata, :std, :sta

  attribute :carrier do |resource|
    resource.airline
  end
end
