#!/usr/bin/env ruby
# frozen_string_literal: true

# Build category JSON files from packages/index.json for GitHub Pages.

require 'json'
require 'fileutils'
require 'active_model'

class App
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :categories

  def to_h
    { 'name' => name, 'categories' => categories }
  end
end

class Category
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :name, :string
  attribute :parent, :string
  attribute :children, default: -> { [] }
  attribute :apps, default: -> { [] }

  def top_level?
    parent.nil?
  end

  def sub_name
    id.split('/', 2).last
  end

  # All apps in this category and its children, deduped, sorted by name
  def aggregated_apps
    seen = {}
    [self, *children.sort_by(&:id)].each_with_object([]) do |cat, result|
      cat.apps.each do |app|
        next if seen[app.name]

        seen[app.name] = true
        result << app
      end
    end.sort_by(&:name)
  end

  def to_h
    h = { 'id' => id, 'name' => name }
    h['parent'] = parent if parent
    h
  end
end

class IndexBuilder
  def initialize(src, out_dir)
    @out_dir = out_dir
    @data = JSON.parse(File.read(src))
    @categories = {}
    @apps = []

    load_categories
    load_apps
  end

  def build
    FileUtils.mkdir_p(@out_dir)
    write_root_index
    write_sub_category_files
    write_top_level_files
    print_summary
  end

  private

  def load_categories
    @data['categories'].each do |raw|
      cat = Category.new(raw)
      @categories[cat.id] = cat
    end

    @categories.each_value do |cat|
      next if cat.top_level?

      parent = @categories[cat.parent]
      parent.children << cat if parent
    end
  end

  def load_apps
    @data['apps'].each do |raw|
      app = App.new(raw)
      @apps << app
      app.categories.each do |cid|
        @categories[cid]&.apps&.<< app
      end
    end
  end

  def write_root_index
    write_json(File.join(@out_dir, 'index.json'), @data)
  end

  def write_sub_category_files
    @categories.each_value do |cat|
      cat.children.sort_by(&:id).each do |child|
        dir = File.join(@out_dir, cat.id)
        FileUtils.mkdir_p(dir)
        path = File.join(dir, "#{child.sub_name}.json")
        write_json(path, child.apps.sort_by(&:name).map(&:to_h))
      end
    end
  end

  def write_top_level_files
    top_level.each do |cat|
      path = File.join(@out_dir, "#{cat.id}.json")
      write_json(path, cat.aggregated_apps.map(&:to_h))
    end
  end

  def write_json(path, data)
    File.write(path, JSON.pretty_generate(data) + "\n")
  end

  def top_level
    @categories.values.select(&:top_level?).sort_by(&:id)
  end

  def print_summary
    sub_count = @categories.values.sum { |c| c.children.length }
    puts "Built #{top_level.length} top-level + #{sub_count} sub-category files in #{@out_dir}/"
  end
end

src = File.join(__dir__, 'index.json')
out_dir = ARGV[0] || '_site'
IndexBuilder.new(src, out_dir).build
