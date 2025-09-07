class AddIndexesForRouteFinding < ActiveRecord::Migration[8.0]
  def change
    add_index :segments, [:airline, :origin_iata, :destination_iata, :std], name: 'idx_segments_for_route_finding'
    add_index :permitted_routes, [:carrier, :origin_iata, :destination_iata], unique: true, name: 'idx_permitted_routes_for_route_finding'
  end
end