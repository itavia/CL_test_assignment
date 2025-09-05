FactoryBot.define do
  sequence :segment_number do |n|
    n.to_s.rjust(4, '0')
  end
end
