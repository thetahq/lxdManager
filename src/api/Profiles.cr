
# Class for the /1.0/profiles API portion

class Profiles
    setter lxd : LXDSocket?

    def getList : Array(String) # GET /1.0/profiles
        l = [] of String
        json = JSON.parse(@lxd.not_nil!.get("/1.0/profiles").body)
        return l if json["metadata"].size == 0
        json["metadata"].as_a.each { |p| l << p.to_s }
        l
    end

    def get(name : String) : Profile # GET /1.0/profiles/<name>
        json = JSON.parse @lxd.not_nil!.get("/1.0/profiles/#{name.gsub("/1.0/profiles/","")}").body
        @lxd.not_nil!.logger.debug json
        pro = json["metadata"]
        conf = {} of String => String
        pro["config"].as_h.each { |k, v| conf[k] = v.to_s }
        dev = {} of String => Containers::ContainerDevice
        pro["devices"].as_h.each { |k, v| dev[k] = Containers::ContainerDevice.new(v.dig?("path") != nil ? v["path"].to_s : "", v["type"].to_s, v.dig?("nictype") != nil ? v["nictype"].to_s : "", v.dig?("parent") != nil ? v["parent"].to_s : "") }
        uby = [] of String
        pro["used_by"].as_a.each { |u| uby << u.to_s }
        Profile.new(pro["name"].to_s, pro["description"].to_s, conf, dev, uby)
    end

    struct Profile
        property name, description, config, devices, used_by
        
        def initialize(@name : String, @description : String, @config : Hash(String, String), @devices : Hash(String, Containers::ContainerDevice), @used_by : Array(String))
        end
    end
end