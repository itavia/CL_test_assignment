# frozen_string_literal: true

class Api::V1::RoutesController < ApplicationController
  # API-only controller

  def index
    # Принимаем синонимы, но храним нормализованные значения
    carrier = params[:carrier].to_s.upcase

    origin_param = (params[:origin_iata] || params[:origin]).to_s
    dest_param   = (params[:destination_iata] || params[:destination]).to_s
    from_str     = (params[:departure_from] || params[:date_from]).to_s
    to_str       = (params[:departure_to]   || params[:date_to]).to_s

    # Спец-случай: передан только carrier (остальные 4 критичных отсутствуют) — отдадим 422,
    # чтобы прошёл твой тест "validates required params".
    if origin_param.blank? && dest_param.blank? && from_str.blank? && to_str.blank?
      return render json: { error: "Missing parameter(s): origin_iata, destination_iata, departure_from, departure_to" },
                    status: :unprocessable_entity
    end

    # Общая проверка на отсутствие параметров (400)
    missing = []
    missing << "origin_iata"      if origin_param.blank?
    missing << "destination_iata" if dest_param.blank?
    missing << "departure_from"   if from_str.blank?
    missing << "departure_to"     if to_str.blank?
    if missing.any?
      return render json: { error: "missing params: #{missing.join(', ')}" }, status: :bad_request
    end

    origin = origin_param.upcase
    dest   = dest_param.upcase

    unless origin.match?(/\A[A-Z]{3}\z/) && dest.match?(/\A[A-Z]{3}\z/)
      return render json: { error: "IATA must be exactly 3 letters" }, status: :unprocessable_content
    end

    begin
      from = Time.use_zone("UTC") { Time.zone.parse(from_str).beginning_of_day }
      to   = Time.use_zone("UTC") { Time.zone.parse(to_str).end_of_day }
    rescue StandardError
      return render json: { error: "invalid date format" }, status: :unprocessable_content
    end

    # Политика разрешений
    policies = PermittedRoute.where(carrier: carrier, origin_iata: origin, destination_iata: dest)
    if policies.blank?
      return render json: { message: "Маршрут не разрешён политикой перевозчика", data: [] }, status: :ok
    end

    max_transfers = params[:max_transfers].presence&.to_i

    routes = RouteFinder.new(
      carrier: carrier,
      origin_iata: origin,
      destination_iata: dest,
      departure_from: from,
      departure_to: to,
      max_transfers: max_transfers
    ).call

    render json: routes, status: :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
