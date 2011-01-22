#encoding: utf-8

# Includes components
require "fileutils"
require "sinatra"
require "haml"
require "yaml"

##
# Configures server
#

configure do
    
    # Setups paths
 #   dir = File.dirname(__FILE__)
    dir = "."
    set :views, dir.dup << "/pages"
    set :static, false
    set :dir, dir

    # Loads configuration
    config = YAML.load(File.read(dir.dup << "/config.yaml"))
    set :config, { 
        :bind => "localhost",
        :port => 8084,
        :format => "html5"
    }
    
    config.each_pair do |key, value|
        settings.config[key.to_sym] = value
    end

    # Setups application
    enable :run
    
    # Setups host
    set :bind, settings.config[:bind]
    set :port, settings.config[:port]

    # Setups HAML
    set :haml, {:format => settings.config[:format].to_sym }                        # default Haml format is :xhtml
    
end

##
# Defines base helpers.
#

helpers do

    ##
    # Process SASS file.
    #
    
    def process_sass(base_path, static_path)
        code = sass base_path[0..-5].to_sym
        File.open(static_path, "w") do |io|
            io.write(code)
        end
    end
    
    ##
    # Process HAML file. Deals with layout.
    #
    
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

    ##
    # Converts domain name to path in filesystem
    # 
    
    def domain_to_path(host)
        path = host.split(".")
        path.reverse! if path.length > 1
        path.join("/")    # returns
    end
end

##
# Process request.
#

before do

    # Sets default request path
    if request.path == ?/
        request_path = "/index.html"
    else
        request_path = request.path
    end
    
    # Creates paths
    extension = File.extname(request_path).to_sym
    domain_path = domain_to_path(request.host)
    base_path = domain_path.dup << request_path
    static_path = settings.dir.dup << "/cache/" << base_path 
    page_path = settings.dir.dup << "/pages/" << base_path
    
    # Do action according to extension
    case extension
        when :".html"
            page_path.replace(page_path[0..-6] << ".haml")
            callback = Proc::new do 
                process_haml(domain_path, base_path, static_path)
            end
        when :".css"
            page_path.replace(page_path[0..-5] << ".sass") 
            callback = Proc::new do 
                process_sass(base_path, static_path)
            end
        else
            callback = Proc::new do 
                FileUtils.copy(page_path, static_path, :verbose => true)
            end        
    end
    
    # Checks if page path exists
    if not File.exists? page_path
        not_found
    end

    # If cache refresh is necessary, does it 
    stat_exists = File.exists? static_path
    if (stat_exists and (File.stat(static_path).mtime < File.stat(page_path).mtime)) or (not stat_exists)
        FileUtils.makedirs(File.dirname(static_path))
        callback.call()
    end

    # Sends file
    send_file static_path
end

    
