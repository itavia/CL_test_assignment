class CreatePermittedRoutes < ActiveRecord::Migration[8.0]
  def change
    create_table :permitted_routes, id: :bigint do |t|
      t.string :carrier, null: false
      t.string :origin_iata, null: false
      t.string :destination_iata, null: false
      t.boolean :direct, default: true, null: false
      t.text :transfer_iata_codes, array: true, default: [], null: false

      t.timestamps
    end
  end
end
