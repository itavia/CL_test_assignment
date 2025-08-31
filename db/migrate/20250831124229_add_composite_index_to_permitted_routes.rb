class AddCompositeIndexToPermittedRoutes < ActiveRecord::Migration[8.0]
  def change
    add_index :permitted_routes, %i[carrier origin_iata destination_iata]
  end
end
