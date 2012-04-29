class SortOutNames < ActiveRecord::Migration
  def self.up
    add_column :readers, :nickname, :string
    add_column :readers, :name, :string

    Reader.reset_column_information

    Reader.all.each do |r|
      r.send :combine_names
      r.save if r.changed?
    end
  end

  def self.down
    remove_column :readers, :nickname
    remove_column :readers, :name
  end
end
