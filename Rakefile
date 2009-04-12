task :environment do
  require 'blog.rb'
end

desc "Run all setup tasks"
task :setup do
  Rake::Task["setup:db"].invoke
  Rake::Task["setup:user"].invoke
end

namespace :setup do
  
  desc "setup a user (set BLOG_USER and BLOG_PASS before rake command)"
  task :user => :environment do
    User.create :username => ENV["BLOG_USER"], :password => ENV["BLOG_PASS"]
  end
  
  desc "create the initial db"
  task :db => :environment do
    DataMapper.auto_migrate!
  end
  
end