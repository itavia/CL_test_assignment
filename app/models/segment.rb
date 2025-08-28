# == Schema Information
#
# Table name: segments
#
#  id               :integer          not null, primary key
#  airline          :string           not null
#  segment_number   :string           not null
#  origin_iata      :string(3)        not null
#  destination_iata :string(3)        not null
#  std              :datetime         # scheduled time of departure (UTC)
#  sta              :datetime         # scheduled time of arrival (UTC)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class Segment < ApplicationRecord
  validates :airline, :segment_number, presence: true
  validates :origin_iata, :destination_iata, presence: true, length: { is: 3 }
end