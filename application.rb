#encoding: utf-8

# Includes components
require "fileutils"
require "sinatra"
require "haml"
require "yaml"

# Configures server
configure do
  
  # Setups paths
  dir = File.dirname(__FILE__)
  set :views, dir.dup << "/pages"
  set :static, false
  set :dir, dir

  # Loads configuration
  config = YAML::load(File.read(dir.dup << "/config.yaml"))
  set :config, { }
  config.each_pair do |key, value|
    settings.config[key.to_sym] = value
  end

  # Setups application
  enable :run
  
  # Setups host
  set :bind, settings.config[:bind]
  set :port, settings.config[:port]

  # Setups HAML
  set :haml, {:format => settings.config[:format].to_sym }            # default Haml format is :xhtml
  
end

helpers do
  def process_sass(base_path, static_path)
    code = sass base_path[0..-5].to_sym
    File.open(static_path, "w") do |io|
      io.write(code)
    end
  end
  
  def process_haml(domain_path, base_path, static_path)
    layout = nil
    
    # Layout
    layout_path = domain_path << "/__layout__"
    if File.exists? settings.dir.dup << "/pages/" << layout_path << ".haml"
      layout = layout_path.to_sym
    end

    # Page
    code = haml base_path[0..-6].to_sym, :layout => layout
    File.open(static_path, "w") do |io|
      io.write(code)
    end
  end
  
  def domain_to_path(host)
    path = host.split(".")
    path.reverse! if path.length > 1
    path.join("/")  # returns
  end
end

before do
  if request.path == ?/
    request_path = "/index.html"
  else
    request_path = request.path
  end
  
  extension = File.extname(request.path).to_sym
  domain_path = domain_to_path(request.host)
  base_path = domain_path.dup << request_path
  static_path = settings.dir.dup << "/cache/" << base_path 
  page_path = settings.dir.dup << "/pages/" << base_path
  
  if extension == :".html"
    page_path.replace(page_path[0..-6] << ".haml")
    make_callback = Proc::new do 
      process_haml(domain_path, base_path, static_path)
    end
  elsif extension == :".css"
    page_path.replace(page_path[0..-5] << ".sass") 
    make_callback = Proc::new do 
      process_sass(base_path, static_path)
    end
  else
    make_callback = Proc::new do 
      FileUtils.copy(page_path, static_path, :verbose => true)
    end    
  end

  if not File.exists? page_path
    not_found
  end
    
  stat_exists = File.exists? static_path
  if (stat_exists and (File.stat(static_path).mtime <  File.stat(page_path).mtime)) or (not stat_exists)
    FileUtils.makedirs(File.dirname(static_path))
    make_callback.call()
  end

  send_file static_path
end

  
