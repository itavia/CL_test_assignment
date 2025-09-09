# config/initializers/load_protobuf_files.rb

Rails.application.configure do
  config.before_configuration do
    # Add lib/proto to the Ruby load path
    $LOAD_PATH.unshift(Rails.root.join("lib", "proto"))

    # Manually require generated protobuf files
    require 'flight_search_pb'
    require 'flight_search_services_pb'
  end
end
