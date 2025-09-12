# frozen_string_literal: true

module Requests
  module JsonHelpers
    def response_body
      @response_body ||= JSON.parse(response.body, symbolize_names: true)
    end
  end
end

RSpec.configure do |config|
  config.include Requests::JsonHelpers, type: :request
end
