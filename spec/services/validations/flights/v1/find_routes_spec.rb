require "rails_helper"

RSpec.describe Validations::Flights::V1::FindRoutes do
  it "requires carrier, origing_iata, destination_iata" do
    expect(subject.call({}).errors.to_h).to(
      include(carrier: ["is missing"], origin_iata: ["is missing"], destination_iata: ["is missing"])  
    )
  end

  it "requires departure_from, departure_to" do
    expect(subject.call({}).errors.to_h).to(
      include(departure_from: ["is missing"], departure_to: ["is missing"])  
    )
  end
end
