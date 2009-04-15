
ENV['GEM_PATH'] = AppConfig[:production_gems_path]

require "rubygems"

module Gem 
  def self.default_path 
    [AppConfig[:production_gems_path], default_dir] 
  end 
end

Gem.clear_paths
