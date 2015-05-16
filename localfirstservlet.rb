# -*- coding: utf-8 -*-
require 'webrick'
require 'net/http'
require 'uri'

include WEBrick
include WEBrick::HTTPUtils

config = {
  :BindAddress => '127.0.0.1',
  :Port => 8000,
  :RemoteServer => ARGV[0] || "http://www.yahoo.co.jp",
  :DocumentRoot => ARGV[1] || File.join(Dir::pwd, 'www')
}

class LocalFirstServlet < HTTPServlet::AbstractServlet

  @@cached = {}

  def initialize(server, config)
    super server
    @remote = config.fetch(:RemoteServer)
    @root = config.fetch(:DocumentRoot)
  end

  def do_GET(req, res)
    target = File.expand_path(File.join(@root, *req.path.split('/')))

    if !FileTest::directory?(target) && File.exists?(target)
      res.body = open(target).read
      res["Content-Type"] = mime_type(target, DefaultMimeTypes)
      puts "Local: #{req.path}"
    elsif @@cached.has_key?(req.path)
      res.body = @@cached[req.path].body
      res["Content-Type"] = @@cached[req.path]["Content-Type"]
      puts "Cached: #{req.path}"
    else
      url = URI.parse(@remote + req.path)
      fetched = Net::HTTP.start(url.host){|http|
        http.get(url.path)
      }
      res.body = fetched.body
      res['Content-Type'] = fetched['Content-Type']
      puts "Fetched: #{url}"
      @@cached[req.path] = fetched
    end
  end
end

server = HTTPServer.new(config)

server.mount('/', LocalFirstServlet, config)

['TERM', 'INT'].each{|signal| 
  trap(signal){ server.shutdown } 
}

server.start

__END__
