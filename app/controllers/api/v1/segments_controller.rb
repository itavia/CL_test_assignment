# frozen_string_literal: true

module Api
  module V1
    class SegmentsController < ApplicationController
      def create
        rows = params[:segments]
        return render(json: { error: 'Пустой список segments' }, status: :bad_request) if rows.blank?

        imported = 0
        errors = []

        rows.each_with_index do |r, i|
          begin
            seg = find_or_build_segment(r)
            seg.assign_attributes(segment_attrs(r))
            seg.save!
            imported += 1
          rescue ActiveRecord::RecordInvalid => e
            errors << { index: i, segment_number: r['segment_number'], error: e.record.errors.full_messages.join(', ') }
          rescue => e
            errors << { index: i, segment_number: r['segment_number'], error: e.message }
          end
        end

        if errors.any?
          render json: { message: 'Часть данных не принята', data: { imported_count: imported }, errors: errors }, status: :unprocessable_entity
        else
          render json: { message: 'Данные приняты', data: { imported_count: imported } }
        end
      end

      private

      def find_or_build_segment(r)
        key = {
          airline: r['airline'],
          segment_number: r['segment_number'],
          std: safe_time(r['std'])
        }.compact
        key.present? ? Segment.find_or_initialize_by(key) : Segment.new
      end

      def segment_attrs(r)
        {
          airline: r['airline'],
          segment_number: r['segment_number'],
          origin_iata: r['origin_iata'],
          destination_iata: r['destination_iata'],
          std: safe_time(r['std']),
          sta: safe_time(r['sta'])
        }.compact
      end

      def safe_time(v)
        return v if v.is_a?(Time) || v.is_a?(ActiveSupport::TimeWithZone)
        return v.to_time if v.is_a?(Date)
        Time.zone.parse(v.to_s)
      rescue
        nil
      end
    end
  end
end
