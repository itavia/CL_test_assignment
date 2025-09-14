class AddSearchIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :segments, [:airline, :origin_iata, :destination_iata, :std], name: "idx_segments_search"
    add_index :permitted_routes, [:carrier, :origin_iata, :destination_iata], name: "idx_permitted_routes_search"
  end
end