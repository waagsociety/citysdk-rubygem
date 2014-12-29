
module CitySDK

  class Importer
    attr_reader :filereader, :api, :params

    def initialize(pars, fr = nil)
      @params = pars

      raise Exception.new("Missing :host in Importer parameters.") if @params[:host].nil?
      raise Exception.new("Missing :layer in Importer parameters.") if @params[:layer].nil?
      raise Exception.new("Missing :file_path in Importer parameters.") if @params[:file_path].nil?

      @api = CitySDK::API.new(@params[:host])
      if @params[:name]
        raise Exception.new("Missing :password in Importer parameters.") if @params[:password].nil?
        raise Exception.new("Failure to authenticate '#{@params[:name]}' with api.") if not @api.authenticate(@params[:name],@params[:password])
        @api.release
      end

      @params[:addresslayer] = 'bag.vbo' if @params[:addressleyer].nil?
      @params[:addressfield] = 'postcode_huisnummer' if @params[:addressfield].nil?

      @filereader = fr || FileReader.new(@params)
    end


    def write(path)
      return @filereader.write(path)
    end

    def setParameter(k,v)
      begin
        @params[(k.to_sym rescue k) || k] = v
        return true
      rescue
      end
      nil
    end

    def sign_in
      begin
        sign_out if @signed_in
        @api.set_host(@params[:host])
        @api.set_layer(@params[:layer])
        @api.authenticate(@params[:name],@params[:password])
        @signed_in = true
      rescue => e
        @api.release
        raise e
      ensure
      end
    end

    def sign_out
      @signed_in = false
      return @api.release
    end

    def filter_fields(h)
      data = {}
      h.each_key do |k|
        k = (k.to_sym rescue k) || k
        j = @params[:alternate_fields][k]
        data[j] = h[k] if @params[:fields].include?(k)
      end
      data
    end

    def do_import(&block)
      result = {
        created: 0,
        not_added: 0
      }

      failed = nil

      # TODO: add possibility to add node to postal code
      # if @params[:hasaddress] == 'certain'
      #   failed = addToAddress(&block)
      #  end

      if failed == []
        result[:updated] += @filereader.content.length
        return result
      end

      if failed
        result[:updated] += (@filereader.content.length - failed.length)
      end

      objects = failed || @filereader.content
      count = objects.length

      begin
        sign_in

        if @params[:hasgeometry]
          begin
            objects.each do |record|

              node = {
                type: 'Feature',
                properties: record[:properties],
                geometry: record[:geometry],
              }

              node[:properties][:data] = filter_fields(record[:properties][:data])
              node[:crs] = { type: 'EPSG', properties: { code: @params[:srid]  } } if @params[:srid] != 4326

              node[:properties][:title] = node[:properties][:data][@params[:title]] if @params[:title]

              yield(node[:properties]) if block_given?

              @api.create_object(node)
              count -= 1
            end
            @api.create_flush
          rescue => e
            raise e
          end
        else
          raise Exception.new("Cannot import. Geometry or uniuque id is not known for records.") if failed.nil?
        end
      rescue => e
        raise Exception.new(e.message)
      ensure
        a = sign_out
        result[:created] += a[:created]
        result[:not_added] = count
      end
      return result
    end

    def addToAddress()
      failed = []
      if @params[:postcode] and @params[:housenumber]
        begin
          sign_in
          @filereader.content.each do |rec|
            row = rec[:properties]
            pc = row[@params[:postcode]].to_s
            hn = row[@params[:housenumber]].to_s
            qres = {}
            if not (pc.empty? or hn.empty?)
              pc = pc.downcase.gsub(/[^a-z0-9]/,'')
              hn.scan(/\d+/).reverse.each { |n|
                # puts "/nodes?#{@params[:addresslayer]}::#{@params[:addressfield]}=#{pc + n}"
                qres = @api.get("/nodes?#{@params[:addresslayer]}::#{@params[:addressfield]}=#{pc + n}")
                break if qres[:status]=='success' and qres[:record_count].to_i >= 1
              }
            else
              qres[:status]='nix'
            end
            if qres[:status]=='success' and qres[:results] and qres[:results][0]
              url = '/' + qres[:results][0][:cdk_id] + '/' + @params[:layer]
              data = filter_fields(row)
              yield({addto: qres[:results][0][:cdk_id], data: data}) if block_given?
              n = @api.put(url,{'data'=>data})
            else
              failed << rec
            end
          end
        rescue => e
          raise e
        ensure
          sign_out
        end
        return failed
      end
      raise Exception.new("Addresses not well defined in dataset.")
    end
  end
end

