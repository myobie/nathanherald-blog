require "dm-core"
require "dm-timestamps"
require "dm-types"

# setup datamapper
DataMapper.setup(:default, AppConfig[:database])
DataMapper::Logger.new(STDOUT, :debug) # :off, :fatal, :error, :warn, :info, :debug

# Add something to Fixnum so I can have a two digit month
class Fixnum
  def two_digits
    self < 10 ? "0#{self.to_s}" : self.to_s
  end
end

# Models
class Post
  include DataMapper::Resource
  
  attr_accessor :content_object
  
  property :id,               Serial
  property :slug,             String, :nullable => false, :index => true, :length => 255
  property :status,           String
  property :object_class,     String, :length => 100
  property :content,          Yaml
  property :created_at_month, Integer
  property :created_at_year,  Integer
  property :created_at,       DateTime
  property :updated_at,       DateTime
  
  def url
    "http://#{AppConfig[:domain]}#{path}"
  end
  
  def path
    "/#{created_at_year}/#{created_at_month.two_digits}/#{slug}"
  end
  
  def title
    content_object.get_attr(:title) || nil
  end
  
  def description
    content_object.get_attr(:body) || nil
  end
  
  def g(attr_name)
    content_object.get_attr(attr_name.to_sym)
  end
  
  def b?(attr_name)
    content_object.blank_attr?(attr_name.to_sym)
  end
  
  def g?(attr_name)
    content_object.get_attr?(attr_name.to_sym)
  end
  
  before :save do
    self.slug = content_object.get_attr(:slug)
    self.status = content_object.get_attr(:status)
    self.object_class = content_object.get_attr(:type)
    self.content = content_object.content
  end
  
  before :create do
    self.created_at_month = Time.now.month
    self.created_at_year  = Time.now.year
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

# Tell PostType how to save to the db
class PostType
  def send_to_storage
    p = Post.new
    p.update_content! self
    p
  end
end