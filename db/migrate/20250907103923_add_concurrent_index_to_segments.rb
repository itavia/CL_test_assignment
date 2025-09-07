class AddConcurrentIndexToSegments < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :segments, [:airline, :origin_iata, :std], name: 'idx_segments_on_airline_origin_std', algorithm: :concurrently
  end
end