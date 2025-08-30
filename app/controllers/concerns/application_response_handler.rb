# frozen_string_literal: true

module ApplicationResponseHandler
  extend ActiveSupport::Concern

  private

  def render_success(data = {}, status: :ok)
    render json: { success: true, data: data }, status: status
  end

  def render_error(message = "Something went wrong", status: :unprocessable_entity)
    render json: { success: false, error: message }, status: status
  end

  def render_not_found(message = "Resource not found")
    render json: { success: false, error: message }, status: :not_found
  end
end
