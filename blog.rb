class AppConfig
  @@hash = {}
  
  def self.load(path)
    @@hash = YAML::load(File.read("#{path}.yml"))
  end
  
  def self.[](what)
    @@hash[what]
  end
end

AppConfig.load "config"

if ENV['RACK_ENV'] == 'production' && AppConfig[:dreamhost]
  require 'dreamhost'
end

require 'rubygems'
gem "sinatra"
require "sinatra/base"
gem "nakajima-rack-flash"
require "rack-flash"
gem "haml"
require "haml"
gem "pony"
require 'pony'
gem "extlib"
require 'extlib'
gem "myobie-turbine-core"
# gem "turbine-core"
require "turbine-core"

PostType.preferred_order = [Video, Audio, Photo, Chat, Review, Quote, Link, Article]

# TODO: move these changes into turbine-core
class Review
  html do
    haml %Q{
      %h2
        - if get_attr?(:url)
          %a{:href=>get_attr(:url)}= get_attr(:item)
        - else
          = get_attr(:item)

      %p.rating
        Rating:
        %span= get_attr(:rating)

      ~ get_attr(:description)
    }.indents(true)
  end
end

require 'model' # can only be required after the config is loaded

# Our Sinatra App
class Blog < Sinatra::Base
  enable :methodoverride, :static, :sessions, :logging
  # log = File.new("sinatra.log", "a")
  # STDOUT.reopen(log)
  # STDERR.reopen(log)
  set :haml, { :format => :html5 }
  set :app_file, __FILE__
  set :reload, Proc.new { development? }
  alias_method :h, :escape_html
  
  use Rack::Flash, :accessorize => [:notice, :error]
  
  ### Helpers
  
  def partial(name, options = {})
    haml(:"_#{name}", options.merge!(:layout => false))
  end
  
  def relative_time(time)
    days_ago = (Time.now - time.to_time).to_i / (60*60*24)
    days_ago = 0 if days_ago < 0
    
    if days_ago == 0
      "today"
    elsif days_ago == 1
      "yesterday"
    else
      "#{days_ago} days ago"
    end
  end
  
  def render_post(post)
    # partial post.object_class.downcase.to_sym, :locals => { :post => post }
    post.content_object.to_html
  end
  
  def oldest_post
    @oldest_post ||= Post.first :order => [:created_at.asc]
  end
  
  def months
    @months ||= years.map { |year| 
      s = year == oldest_post.created_at_year ? oldest_post.created_at_month : 1
      e = year == Time.now.year ? Time.now.month : 12
      (s..e).to_a.reverse.map { |month| [month, year] }
    }.inject([]) { |sum, year| sum + year }
  end#months
  
  def years
    @years ||= oldest_post ? (oldest_post.created_at_year..Time.now.year).to_a : []
  end
  
  def perc_of_month(amount)
    ((amount.to_f / AppConfig[:max_posts_per_month].to_f) * 100).floor
  end
  
  ### Authentication
  
  def auth
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
  end

  def unauthorized!(realm="nathanherald.com")
    response['WWW-Authenticate'] = %(Basic realm="#{realm}")
    throw :halt, [ 401, 'Authorization Required' ]
  end

  def bad_request!
    throw :halt, [ 400, 'Bad Request' ]
  end
  
  def ensure_authenticated
    unauthorized! unless auth.provided?
    bad_request! unless auth.basic?
    unauthorized! unless authorize(*auth.credentials)
  end
  
  def authorize(username, password)
    AppConfig[:username] == username && AppConfig[:password] == password
  end
  
  def logged_in?
    auth.provided? && auth.basic? && authorize(*auth.credentials)
  end
  
  ### Routes
  
  get '/' do
    DataMapper.repository do
      @posts = Post.all :limit => (AppConfig[:home_posts_count] || 5), :order => [:created_at.desc]
      body haml(:home)
    end#repository
  end#get
  
  get '/archive/?' do
    # list all posts
    @posts = Post.all :order => [:created_at.desc]
    haml :archive
  end
  
  get %r{^/([0-9]{4})/?$} do |year|
    @posts = Post.all({
      :created_at_year.gte => year.to_i, 
      :created_at_year.lt => year.to_i+1,
      :order => [:created_at.desc]
    })
    haml :list
  end
  
  get %r{^/([0-9]{4})/([0-9]{2})/?$} do |year, month|
    @posts = Post.all({
      :created_at_year.gte => year.to_i, 
      :created_at_year.lt => year.to_i+1,
      :created_at_month.gte => month.to_i,
      :created_at_month.lt => month.to_i+1,
      :order => [:created_at.desc]
    })
    haml :list
  end
  
  get %r{^/([0-9]{4})/([0-9]{2})/(.+)/?$} do |year, month, slug|
    @post = Post.first({
      :created_at_year.gte => year.to_i, 
      :created_at_year.lt => year.to_i+1,
      :created_at_month.gte => month.to_i,
      :created_at_month.lt => month.to_i+1,
      :slug => slug,
      :order => [:created_at.desc]
    })
    haml :show
  end
  
  get '/login/?' do
    ensure_authenticated
    redirect '/'
  end
  
  get '/posts/new/?' do
    ensure_authenticated
    # show a new form
    haml :new
  end
  
  post '/posts/?' do
    ensure_authenticated
    # create a new post
    @post_content = PostType.auto_detect(params[:post])
    @post = @post_content.save
    redirect @post.path
  end
  
  get '/posts/:id/?' do
    # show the post for that id (or it could be a slug)
    @post = Post.get(params[:id])
    haml :show
  end
  
  get '/posts/:id/edit/?' do
    ensure_authenticated
    # show an edit form
    @post = Post.get(params[:id])
    haml :edit
  end
  
  post '/posts/:id/?' do
    params.to_yaml
  end
  
  put '/posts/:id/?' do
    ensure_authenticated
    # update the post for that id
    @post = Post.get(params[:id])
    @post.update_content!(params[:post])
    redirect @post.path
  end
  
  delete '/posts/:id/?' do
    ensure_authenticated
    # remove the post for that id
    @post = Post.get(params[:id])
    @post.destroy
    redirect '/'
  end
  
  get '/feed/?' do
    # make an rss feed of the last 30 posts
    DataMapper.repository do
      @posts = Post.all :limit => 30, :order => [:created_at.desc]
      body haml(:feed, :layout => false)
    end#repository
  end
  
  ### other pages
  %w(about contact thankyou).each do |path|
    get "/#{path}/?" do
      haml path.to_sym
    end
  end
  
  post '/contact/?' do
    Pony.mail({
      :to => AppConfig[:mail][:to], 
      :from => AppConfig[:mail][:from], 
      :subject => AppConfig[:mail][:subject], 
      :body => [params[:name], params[:email], params[:message]].join("\n\n")
    })
    redirect '/thankyou'
  end
  
end
