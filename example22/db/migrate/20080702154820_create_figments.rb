class CreateFigments < ActiveRecord::Migration
  def self.up
    create_table :figments do |t|
      t.integer :account_id
      t.integer :value

      t.timestamps
    end
  end

  def self.down
    drop_table :figments
  end
end
