require 'json'
require 'faraday'

module CitySDK

  class HostException < ::Exception
  end

  class API
    attr_reader   :last_result
    attr_reader   :error
    attr_accessor :batch_size
    attr_accessor :per_page
    attr_accessor :format

    def initialize(host)
      @error = '';
      @layer = '';
      @batch_size = 1000;
      @per_page = 25;
      @format = 'jsonld'
      @updated = @created = 0;
      set_host(host)
    end

    def authenticate(name, password)
      @name = name;
      @password = password;

      resp = @connection.get '/session', { name: @name, password: @password }
      if resp.status.between?(200, 299)
        resp = CitySDK::parse_json(resp.body)
        if (resp.class == Hash) and resp[:session_key]
          @connection.headers['X-Auth'] = resp[:session_key]
        else
          raise Exception.new('Invalid credentials')
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

    def set_host(host)
      if host.index('https') == 0
        @connection = Faraday.new url: host, ssl: { verify: false }
      else
        @connection = Faraday.new url: host
      end

      @connection.headers = {
        :user_agent => 'CitySDK LD API GEM ' + CitySDK::VERSION,
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
      create_flush
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
      # send any remaining entries in the create buffer
      create_flush
      if authorized?
        resp = @connection.delete('/session')
        if resp.status.between?(200, 299)
          @connection.headers.delete('X-Auth')
        else
          @error = CitySDK::parse_json(resp.body)[:error]
          raise HostException.new(@error)
        end
      end
      return {created: @created}
    end

    def delete(path)
      write :delete, path
    end

    def post(path, data)
      write :post, path, data
    end

    def patch(path, data)
      write :patch, path, data
    end

    def put(path, data)
      write :put, path, data
    end

    def write(method, path, data = nil)
      if authorized?
        payload = data ? data.to_json : nil
        resp = @connection.send(method, path, payload)
        @last_result = { status: resp.status, headers: resp.headers }

        if resp.status == 401 and @name and @password
          # API was authenticated before, so probably timed out. Try again!
          if authenticate(@name, @password)
            resp = @connection.send(method, path, payload)
            @last_result = { status: resp.status, headers: resp.headers }
          end
        end

        return CitySDK::parse_json(resp.body) if resp.status.between?(200, 299)
        @error = CitySDK::parse_json(resp.body)[:error] || {status: resp.status}
        raise HostException.new(@error)
      end
      raise CitySDK::Exception.new("#{method.upcase} needs authorization")
    end

    def get(path)
      resp = @connection.get(add_format(path))
      @next = (resp.headers['Link'] =~ /^<(.+)>;\s*rel="next"/) ? $1 : nil
      @last_result = { status: resp.status, headers: resp.headers }
      return CitySDK::parse_json(resp.body) if resp.status.between?(200, 299)
      @error = CitySDK::parse_json(resp.body)[:error]
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
