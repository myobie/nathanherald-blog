require "dm-core"
require "dm-timestamps"
require "dm-types"
require "dm-aggregates"

# setup datamapper
DataMapper.setup(:default, AppConfig[:database])
DataMapper::Logger.new(STDOUT, :debug) # :off, :fatal, :error, :warn, :info, :debug

# Add something to Fixnum so I can have a two digit month
class Fixnum
  def two_digits
    self < 10 ? "0#{self.to_s}" : self.to_s
  end
end

# Add a truncate_words to string
class String
  def truncate_words(words = 30, end_string = " ...")
    words = self.split()
    words[0..(length-1)].join(' ') + (words.length > length ? end_string : '')
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
  property :created_at_month, Integer, :index => true
  property :created_at_year,  Integer, :index => true
  property :created_at,       DateTime
  property :updated_at,       DateTime
  
  def self.my_count(month, year)
    count({
      :created_at_year.gte => year.to_i, 
      :created_at_year.lt => year.to_i+1,
      :created_at_month.gte => month.to_i,
      :created_at_month.lt => month.to_i+1
    })
  end
  
  def url
    "http://#{AppConfig[:domain]}#{path}"
  end
  
  def path
    "/#{created_at_year}/#{created_at_month.two_digits}/#{slug}"
  end
  
  def title
    if !content_object.class.heading_field.blank? && content_object.get_attr?(content_object.class.heading_field)
      content_object.get_attr(content_object.class.heading_field).truncate_words
    elsif !content_object.class.required_fields_list.blank?
      content_object.class.required_fields_list.map { |f| content_object.get_attr(f) }.join(" | ").truncate_words
    else
      "No Title"
    end
  end
  
  def description
    content_object.to_html
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
    self.slug = content_object.get_attr(:slug) unless content_object.blank_attr?(:slug)
    self.status = content_object.get_attr(:status) unless content_object.blank_attr?(:status)
    self.object_class = content_object.get_attr(:type) unless content_object.blank_attr?(:type)
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