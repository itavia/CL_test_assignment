# frozen_string_literal: true

module Api
  module V1
    class PermittedRoutesController < ApplicationController
      # POST /api/v1/permitted_routes
      # { routes: [ { carrier, origin_iata, destination_iata, direct?, transfer_iata_codes?[] }, ... ] }
      def create
        rows = Array(params[:routes])
        return render json: { message: 'Пустой список routes' }, status: :bad_request if rows.blank?

        imported = 0
        errors = []

        rows.each_with_index do |r, i|
          begin
            pr = PermittedRoute.find_or_initialize_by(
              carrier: r['carrier'],
              origin_iata: r['origin_iata'],
              destination_iata: r['destination_iata']
            )
            pr.direct = r.key?('direct') ? !!r['direct'] : pr.direct
            pr.transfer_iata_codes = Array(r['transfer_iata_codes']).map { |s| s.to_s.upcase[0,3] }
            pr.save!
            imported += 1
          rescue ActiveRecord::RecordInvalid => e
            errors << { index: i, carrier: r['carrier'], route: [r['origin_iata'], r['destination_iata']], error: e.record.errors.full_messages.join(', ') }
          rescue => e
            errors << { index: i, carrier: r['carrier'], route: [r['origin_iata'], r['destination_iata']], error: e.message }
          end
        end

        if errors.any?
          render json: { message: 'Часть данных не принята', data: { imported_count: imported }, errors: errors }, status: :unprocessable_entity
        else
          render json: { message: 'Данные приняты', data: { imported_count: imported } }
        end
      end
    end
  end
end