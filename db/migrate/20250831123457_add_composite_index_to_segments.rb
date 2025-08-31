class AddCompositeIndexToSegments < ActiveRecord::Migration[8.0]
  def change
    add_index :segments, %i[airline origin_iata destination_iata]
  end
end
