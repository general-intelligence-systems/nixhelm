#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

Category = Struct.new(:id, :name, :parent, keyword_init: true) do

  def filename = "#{self.id}.json"

  def top_level? = parent.nil?

  def children(all_categories) = all_categories.select { |c| c.parent == id }

  def apps(all_categories, all_apps)
    own = all_apps.select { |a| a.categories.include?(id) }
    child_apps = children(all_categories).flat_map { |c| c.apps(all_categories, all_apps) }
    (own + child_apps).uniq(&:name)
  end
end

App = Struct.new(:name, :categories, keyword_init: true) do
  def to_h = { 'name' => name, 'categories' => categories }
end

src = File.join(__dir__, 'index.json')
out = ARGV[0] || '_site'

categories = nil
apps = nil
data = nil

JSON.parse(File.read(src)).tap do |json|
  data       = json
  categories = json['categories'].map { |x| Category.new(**x.transform_keys(&:to_sym)) }
  apps       = json['apps'].map       { |x| App.new(**x.transform_keys(&:to_sym)) }
end

FileUtils.mkdir_p(out)
File.write("#{out}/index.json", JSON.pretty_generate(data) + "\n")

categories.each do |cat|
  path      = File.join(out, cat.filename)
  directory = File.dirname(path)
  contents  = JSON.pretty_generate(cat.apps(categories, apps).map(&:to_h)) + "\n"

  FileUtils.mkdir_p(directory)
  File.write(path, contents)
end

top = categories.count(&:top_level?)
puts "Built #{top} top-level + #{categories.length - top} sub-category files in #{out}/"
