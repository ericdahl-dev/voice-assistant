class AddIntroTopicToCallTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :call_templates, :intro_topic, :string
  end
end
