class CreateDelegations < ActiveRecord::Migration[8.1]
  def change
    create_table :delegations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :call_template, null: true, foreign_key: false

      t.timestamps
    end
  end
end
