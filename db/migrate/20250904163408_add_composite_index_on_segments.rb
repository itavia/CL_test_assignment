class AddCompositeIndexOnSegments < ActiveRecord::Migration[8.0]
  def change
    add_index :segments, [:airline, :origin_iata, :destination_iata]
  end
end
