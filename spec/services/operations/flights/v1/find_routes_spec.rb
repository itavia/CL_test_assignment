require "rails_helper"

RSpec.describe Operations::Flights::V1::FindRoutes do
  subject(:result) { described_class.new.call(params) }

  describe "#call" do
    context "when search params are not valid" do
      let(:params) do
        { foo: "foo", faz: "faz" }  
      end

      it 'returns failure' do
        expect(result).to be_a(Dry::Monads::Failure)
        expect(result.failure.errors.to_h).to(
          include(
            carrier: ["is missing"],
            origin_iata: ["is missing"],
            destination_iata: ["is missing"]
          )
        )
      end
    end

    context "when search params are valid" do
      context "when no permitted route was found" do
        let(:params) do
          {
            carrier: "S13",
            origin_iata: "BQS",
            destination_iata: "NOZ",
            departure_from: "2024-01-01",
            departure_to: "2024-01-07"
          }
        end

        it "returns an empty array" do
          expect(result).to be_a(Dry::Monads::Success)
          expect(result.value!).to eq([])
        end
      end

      context "when permitted route was found" do
        let!(:permitted_route) { create(:permitted_route, :with_transfers) }
         let(:params) do
          {
            carrier: "Northtrop",
            origin_iata: "FRO",
            destination_iata: "AUR",
            departure_from: "2024-01-01",
            departure_to: "2024-01-07"
          }
        end       

        context "when no segements was found" do
          it "retruns an empty array" do
            expect(result).to be_a(Dry::Monads::Success)    
            expect(result.value!).to eq([])
          end
        end
        #["SHD", "SKY", "SHDICY", "SKYICYSUN"]
        context "when available segments was found" do
          let!(:direct_segment) do
            create(
              :segment,
              origin_iata: "FRO",
              destination_iata: "AUR",
              std: Time.new(2024, 1, 1, 5, 45),
              sta: Time.new(2024, 1, 2, 1, 40),
            ) 
          end

          let!(:segment_one) do
            create(
              :segment,
              origin_iata: "FRO",
              destination_iata: "SHD",
              std: Time.new(2024, 1, 1, 5, 45),
              sta: Time.new(2024, 1, 1, 7, 40),
            ) 
          end
          let!(:segment_two) do
            create(
              :segment,
              origin_iata: "SHD",
              destination_iata: "AUR",
              std: Time.new(2024, 1, 1, 15, 45),
              sta: Time.new(2024, 1, 1, 19, 40),
            )
          end
          let!(:segment_three) do
            create(
              :segment,
              origin_iata: "SHD",
              destination_iata: "ICY",
              std: Time.new(2024, 1, 1, 18, 45),
              sta: Time.new(2024, 1, 2, 0, 40),
            )
          end
          let!(:segment_four) do
            create(
              :segment,
              origin_iata: "ICY",
              destination_iata: "AUR",
              std: Time.new(2024, 1, 2, 8, 45),
              sta: Time.new(2024, 1, 2, 10, 40),
            )
          end

          it "retruns available routes" do
            expect(result).to be_a(Dry::Monads::Success) 
            expect(result.value!.first).to(
              include(
                origin_iata: "FRO",
                destination_iata: "AUR",
                departure_time: direct_segment.std,
                arrival_time: direct_segment.sta,
                segments: [
                  {
                    carrier: "Northtrop",
                    segment_number: direct_segment.segment_number,
                    destination_iata: "AUR",
                    origin_iata: "FRO",
                    std: direct_segment.std,
                    sta: direct_segment.sta
                  }
                ]
              )
            )
          end
        end
      end
    end
  end
end
