class CreateValues < ActiveRecord::Migration
  def change
    create_table :values do |t|
      t.string :value
      t.string :other_value
      t.timestamps null: false
    end
  end
end
