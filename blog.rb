require "rubygems"
require "sinatra/base"
# gem "nakajima-rack-flash"
# require "rack-flash"
require "haml"

# gem "myobie-turbine-core"
gem "turbine-core"
require "turbine-core"

PostType.preferred_order = [Video, Audio, Photo, Chat, Review, Link, Quote, Article]

require "dm-core"
require "dm-timestamps"
require "dm-types"

# setup datamapper
DataMapper.setup(:default, "sqlite3:///#{Dir.pwd}/blog.db")
DataMapper::Logger.new(STDOUT, :debug) # :off, :fatal, :error, :warn, :info, :debug

# Models
class Post
  include DataMapper::Resource
  
  attr_accessor :content_object
  
  property :id,             Serial
  property :slug,           String, :nullable => false, :index => true, :length => 255
  property :status,         String
  property :object_class,   String, :length => 100
  property :content,        Yaml
  property :created_at,     DateTime
  property :updated_at,     DateTime
  
  before :save do
    self.slug = content_object.get_attr(:slug)
    self.status = content_object.get_attr(:status)
    self.object_class = content_object.get_attr(:type)
    self.content = content_object.content
  end
  
  def update_content!(new_content_object)
    self.content_object = new_content_object
    save
  end
  
  def content_object
    if @content_object.blank? && !self.object_class.blank?
      @content_object = Kernel.const_get(self.object_class).new(self.content)
    end
    @content_object
  end
  
  def content_object=(new_content_object)
    case new_content_object
    when String
      @content_object = PostType.auto_detect(new_content_object)
    else
      @content_object = new_content_object
    end
  end
  
end

class User
  include DataMapper::Resource
  
  property :id, Serial
  property :username, String
  property :password, String # quick and dirty, probly should just use a yaml file instead
end

# Tell PostType how to save to the db
class PostType
  def send_to_storage
    p = Post.new
    p.update_content! self
  end
end

# Our Sinatra App
class Blog < Sinatra::Base
  set :haml, {:format => :html5 }
  
  include Rack::Utils
  alias_method :h, :escape_html
  
  # helpers
  
  def partial(name, options = {})
    haml(:"_#{name}", options.merge!(:layout => false))
  end
  
  def relative_time(time)
    days_ago = (Time.now - time).to_i / (60*60*24)
    days_ago = 0 if days_ago < 0
    "#{days_ago} day#{'s' if days_ago != 1} ago"
  end
  
  # authentication stuff
  
  def auth
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
  end

  def unauthorized!(realm="nathanherald.com")
    header 'WWW-Authenticate' => %(Basic realm="#{realm}")
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
    u = User.first
    u.username == username && u.password == password
  end
  
  # use Rack::Flash, :accessorize => true
  
  # Routes
  get '/' do
    # show the homepage, maybe the five newest or something
    @posts = Post.all :limit => 5, :order => [:created_at.desc]
    haml :index
  end
  
  get '/posts/?' do
    # list all posts
    @posts = Post.all :order => [:created_at.desc]
    haml :posts
  end
  
  post '/posts/?' do
    ensure_authenticated
    # create a new post
    @post_content = PostType.auto_detect(params[:post])
    @post_content.save
    redirect '/posts'
  end
  
  get '/posts/:id/?' do
    # show the post for that id (or it could be a slug)
    @post = Post.get(params[:id])
    @post = Post.first(:slug => params[:id]) if @post.blank?
    haml :show
  end
  
  put '/posts/:id/?' do
    ensure_authenticated
    # update the post for that id
    @post = Post.get(params[:id])
    @post.update_content!(params[:post])
    redirect '/posts'
  end
  
  delete '/posts/:id/?' do
    ensure_authenticated
    # remove the post for that id
    @post = Post.get(params[:id])
    @post.destroy
    redirect '/posts'
  end
  
  get '/feed' do
    # make an rss feed of the last 30 posts
    haml :feed
  end
  
end
