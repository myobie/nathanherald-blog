task :environment do
  require 'blog.rb'
end

desc "Run all setup tasks"
task :bootstrap do
  Rake::Task["bootstrap:db"].invoke
end

namespace :bootstrap do
  
  desc "create the initial db"
  task :db => :environment do
    DataMapper.auto_migrate!
  end
  
end