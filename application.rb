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
    set :haml, {:format => settings.config[:format].to_sym }                      # default Haml format is :xhtml
    
end

helpers do
    def process_sass(page_path, static_path)
        code = sass page_path[0..-5].to_sym
        File.open(static_path, "w") do |io|
            io.write(code)
        end
    end
    
    def process_haml(page_path, static_path)
        code = haml page_path[0..-6].to_sym
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
    extension = File.extname(request.path).to_sym
    path = domain_to_path(request.host) << request.path_info
    static_path = settings.dir.dup << "/cache/" << path 
    page_path = settings.dir.dup << "/pages/" << path
    
    if extension == :".html"
        page_path.replace(page_path[0..-6] << ".haml")
        make_callback = Proc::new do 
            process_haml(path, static_path)
        end
    elsif extension == :".css"
        page_path.replace(page_path[0..-5] << ".sass") 
        make_callback = Proc::new do 
            process_sass(path, static_path)
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

