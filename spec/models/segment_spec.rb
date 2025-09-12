# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Segment do
  describe 'валидации' do
    it 'валиден с корректными атри
    бутами' do
      segment = build(:segment)
      expect(segment).to be_valid
    end

    context 'проверка присутствия' do
      it 'невалиден без airline' do
        segment = build(:segment, airline: nil)

        expect(segment).not_to be_valid
        expect(segment.errors[:airline]).to include("can't be blank")
      end

      it 'невалиден без segment_number' do
        segment = build(:segment, segment_number: nil)

        expect(segment).not_to be_valid
        expect(segment.errors[:segment_number]).to include("can't be blank")
      end

      it 'невалиден без origin_iata' do
        segment = build(:segment, origin_iata: nil)

        expect(segment).not_to be_valid
        expect(segment.errors[:origin_iata]).to include("can't be blank")
      end

      it 'невалиден без destination_iata' do
        segment = build(:segment, destination_iata: nil)

        expect(segment).not_to be_valid
        expect(segment.errors[:destination_iata]).to include("can't be blank")
      end
    end

    context 'проверка длины IATA кодов' do
      it 'невалиден, если длина origin_iata не равна 3' do
        segment = build(:segment, origin_iata: 'AA')

        expect(segment).not_to be_valid
        expect(segment.errors[:origin_iata]).to include('is the wrong length (should be 3 characters)')
      end

      it 'невалиден, если длина destination_iata не равна 3' do
        segment = build(:segment, destination_iata: 'BBBB')

        expect(segment).not_to be_valid
        expect(segment.errors[:destination_iata]).to include('is the wrong length (should be 3 characters)')
      end
    end
  end
end
