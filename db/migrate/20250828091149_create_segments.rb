class CreateSegments < ActiveRecord::Migration[8.0]
  def change
    create_table :segments do |t|
      t.string :airline, null: false
      t.string :segment_number, null: false
      t.string :origin_iata, limit: 3, null: false
      t.string :destination_iata, limit: 3, null: false
      t.datetime :std  # scheduled time of departure (UTC)
      t.datetime :sta  # scheduled time of arrival (UTC)

      t.timestamps
    end
  end
end
