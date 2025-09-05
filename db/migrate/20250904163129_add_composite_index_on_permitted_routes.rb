class AddCompositeIndexOnPermittedRoutes < ActiveRecord::Migration[8.0]
  def change
    add_index :permitted_routes, [:carrier, :origin_iata, :destination_iata]
  end
end
