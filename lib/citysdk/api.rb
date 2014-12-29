require 'json'
require 'faraday'

module CitySDK

  def log(m)
    File.open(File.expand_path('~/csdk.log'), "a")  do |f|
      f.write(m + "\n")
    end
  end

  class HostException < ::Exception
  end

  class API
    attr_reader   :last_result
    attr_reader   :error
    attr_accessor :batch_size
    attr_accessor :per_page
    attr_accessor :format

    def initialize(host, port=nil)
      @error = '';
      @layer = '';
      @batch_size = 1000;
      @per_page = 25;
      @format = 'jsonld'
      @updated = @created = 0;
      set_host(host,port)
    end

    def authenticate(n,p)
      @name = n;
      @passw = p;

      resp = @connection.get '/session', { :name => @name, :password => @passw }
      if resp.status.between?(200, 299)
        resp = CitySDK::parseJson(resp.body)
        if (resp.class == Hash) and resp[:session_key]
          @connection.headers['X-Auth'] = resp[:session_key]
        else
          raise Exception.new("Invalid credentials")
        end
      else
        raise Exception.new(resp.body)
      end
      if block_given?
        begin
          yield
        ensure
          self.release
        end
      end
      true
    end

    def set_host(host,port=nil)
      @host = host
      @port = port

      @host.gsub!(/^http(s)?:\/\//,'')

      if port.nil?
        if host =~ /^(.*):(\d+)$/
          @port = $2
          @host = $1
        else
          @port = 80
        end
      end

      if !($nohttps or @host =~ /.+\.dev/ or @host == 'localhost' or @host == '127.0.0.1' or @host == '0.0.0.0')
        @connection = Faraday.new :url => "https://#{@host}", :ssl => {:verify => false }
      else
        @connection = Faraday.new :url => "http://#{@host}:#{@port}"
      end
      @connection.headers = {
        :user_agent => 'CitySDK_API GEM ' + CitySDK::VERSION,
        :content_type => 'application/json'
      }
      begin
        get('/')
      rescue Exception => e
        raise CitySDK::Exception.new("Trouble connecting to API @ #{host}")
      end
      @create =  {
        type: "FeatureCollection",
        features: []
      }
    end

    def add_format(path)
      if path !~ /format/
        path = path + ((path =~ /\?/) ? "&" : "?") + "format=#{@format}"
      end
      return path if path =~ /per_page/
      path + "&per_page=#{@per_page}"
    end

    def set_layer(l)
      @layer = l
    end

    def next
      @next ? get(@next) : "{}"
    end

    def layers
      get "/layers"
    end

    def owners
      get "/owners"
    end

    def objects(layer=nil)
      !!layer ? get("/layers/#{layer}/objects") : get("/objects")
    end

    def create_object(n)
      @create[:features] << n
      create_flush if @create[:features].length >= @batch_size
    end

    def authorized?
     !! @connection.headers['X-Auth']
    end

    def release
      create_flush # send any remaining entries in the create buffer
      if authorized?
        resp = @connection.delete('/session')
        if resp.status.between?(200, 299)
          @connection.headers.delete('X-Auth')
        else
          @error = CitySDK::parseJson(resp.body)[:error]
          raise HostException.new(@error)
        end
      end
      return {created: @created}
    end

    def delete(path)
      if authorized?
        resp = @connection.delete(add_format(path))
        if resp.status.between?(200, 299)
          @last_result = { status: resp.status, headers: resp.headers }
          return (resp.body and resp.body !~ /\s*/) ? CitySDK::parseJson(resp.body) : ''
        end
        @error = CitySDK::parseJson(resp.body)[:error]
        raise HostException.new(@error)
      end
      raise CitySDK::Exception.new("DELETE needs authorization.")
    end

    def post(path,data)
      if authorized?
        resp = @connection.post(add_format(path),data.to_json)
        @last_result = { status: resp.status, headers: resp.headers }
        return CitySDK::parseJson(resp.body) if resp.status.between?(200, 299)
        @error = resp.body # CitySDK::parseJson(resp.body)[:error]

        File.open(File.expand_path("~/post_error_data.json"),"w") do |fd|
          fd.write(JSON.pretty_generate({error: @error, data: data}))
        end

        raise HostException.new(@error)
      end
      raise CitySDK::Exception.new("POST needs authorization.")
    end

    def patch(path,data)
      if authorized?
        resp = @connection.patch(add_format(path),data.to_json)
        @last_result = { status: resp.status, headers: resp.headers }
        return CitySDK::parseJson(resp.body) if resp.status.between?(200, 299)
        @error = CitySDK::parseJson(resp.body)[:error]
        raise HostException.new(@error)
      end
      raise CitySDK::Exception.new("PATCH needs authorization.")
    end

    def put(path,data)
      if authorized?
        resp = @connection.put(add_format(path),data.to_json)
        @last_result = { status: resp.status, headers: resp.headers }
        return CitySDK::parseJson(resp.body) if resp.status.between?(200, 299)
        @error = CitySDK::parseJson(resp.body)[:error] || {status: resp.status}
        raise HostException.new(@error)
      end
      raise CitySDK::Exception.new("PUT needs authorization.")
    end

    def get(path)
      resp = @connection.get(add_format(path))
      @next = (resp.headers['Link'] =~ /^<(.+)>;\s*rel="next"/) ? $1 : nil
      @last_result = { status: resp.status, headers: resp.headers }
      return CitySDK::parseJson(resp.body) if resp.status.between?(200, 299)
      @error = CitySDK::parseJson(resp.body)[:error]
      raise HostException.new(@error)
    end

    def create_flush
      if @create[:features].length > 0
        tally post("/layers/#{@layer}/objects",@create)
        @create[:features] = []
      end
    end

    def tally(res)
      @created += res.length
    end

  end

end
