class AddUniqueConcurrentIndexToPermittedRoutes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :permitted_routes, [:carrier, :origin_iata, :destination_iata], unique: true, name: 'idx_permitted_routes_for_route_finding', algorithm: :concurrently
  end
end