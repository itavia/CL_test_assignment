# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PermittedRoute do
  describe 'валидации' do
    it 'валиден с корректными атрибутами' do
      permitted_route = build(:permitted_route)

      expect(permitted_route).to be_valid
    end

    it 'невалиден без carrier' do
      permitted_route = build(:permitted_route, carrier: nil)

      expect(permitted_route).not_to be_valid
      expect(permitted_route.errors[:carrier]).to include("can't be blank")
    end

    it 'невалиден без origin_iata' do
      permitted_route = build(:permitted_route, origin_iata: nil)

      expect(permitted_route).not_to be_valid
      expect(permitted_route.errors[:origin_iata]).to include("can't be blank")
    end

    it 'невалиден без destination_iata' do
      permitted_route = build(:permitted_route, destination_iata: nil)

      expect(permitted_route).not_to be_valid
      expect(permitted_route.errors[:destination_iata]).to include("can't be blank")
    end
  end
end
