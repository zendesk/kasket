# frozen_string_literal: true
ActiveRecord::Schema.define do
  suppress_messages do
    create_table 'comments', force: true do |t|
      t.text     'body'
      t.integer  'post_id'
      t.boolean  'public', default: true, null: false
      t.datetime 'created_at'
      t.datetime 'updated_at'
    end

    create_table 'authors', force: true do |t|
      t.string 'name'
      t.string 'metadata'
    end

    create_table 'posts', force: true do |t|
      t.string   'title'
      t.integer  'author_id'
      t.integer  'blog_id'
      t.string   'ignored_column'
      t.integer  'poly_id'
      t.integer  'big_id', limit: 8
      t.string   'poly_type'
      t.datetime 'created_at'
      t.datetime 'updated_at'
    end

    create_table 'blogs', force: true do |t|
      t.string   'name'
      t.datetime 'created_at'
      t.datetime 'updated_at'
    end
  end
end
