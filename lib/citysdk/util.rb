require 'json'

class String
  def remove_non_ascii
    self.encode( "UTF-8", "binary", :invalid => :replace, :undef => :replace, :replace => '§')
  end
  def starts_with?(aString)
    index(aString) == 0
  end
end

class Object
  def deep_copy
    Marshal.load(Marshal.dump(self))
  end
  def blank?
    return false if self.class == Symbol
    self.nil? or (self.class==String and self.strip == '') or (self.respond_to?(:empty?) ? self.empty? : false)
  end
end


module CitySDK
  
  # for debugging purposes...
  def jsonlog(o)
    puts JSON.pretty_generate({ o.class.to_s => o })
  end


  class Exception < ::Exception
    def initialize(message,parms=nil,srcfile=nil,srcline=nil)
      if parms and srcfile and srcline
        file = File.basename( parms[:originalfile] ? parms[:originalfile] : ( parms[:file_path] || '-' ) )
        m = "#{Time.now.strftime("%b %M %Y, %H:%M")}; CitySDK, processing file: #{file}\n Exception in #{File.basename(srcfile)}, #{srcline}\n #{message}"
      else
        m = "#{Time.now.strftime("%b %M %Y, %H:%M")}; CitySDK Exception: #{message}"
      end
      super(m)
      $stderr.puts(m) if parms and parms[:verbose]
    end
  end

  def self.parseJson(jsonstring)
    begin
      return jsonstring.blank? ? {} : JSON.parse(jsonstring,symbolize_names: true)
    rescue Exception => e
      raise CitySDK::Exception.new("#{e.message}; input: #{jsonstring}")
    end
  end

end



