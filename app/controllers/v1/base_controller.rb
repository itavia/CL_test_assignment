# frozen_string_literal: true

module V1
  class BaseController < ApplicationController
    include Dry::Monads[:result]
  end
end
