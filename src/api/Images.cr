
# Class for the /1.0/images API portion

class Images
    setter lxd : LXDSocket?

    def getList : Array(String) # GET /1.0/images
        l = [] of String
        json = JSON.parse(@lxd.not_nil!.get("/1.0/images").body)
        return l if json["metadata"].size == 0
        json["metadata"].as_a.each { |i| l << i.to_s }
        l
    end

    def get(fingerprint : String) : Image # GET /1.0/images/<fingerprint>
        json = JSON.parse @lxd.not_nil!.get("/1.0/images/#{fingerprint.gsub("/1.0/images/", "")}").body
        @lxd.not_nil!.logger.debug json
        img = json["metadata"]
        fingerprint = img["fingerprint"].to_s
        als = [] of Alias
        img["aliases"].as_a.each { |a| als << Alias.new(a["name"].to_s, a["description"].to_s, fingerprint) }
        p = img["properties"]
        pro = ImageProperties.new(p["architecture"].to_s, p["description"].to_s, p["os"].to_s, p["release"].to_s)
        up = img["update_source"]
        update = UpdateSource.new(up["server"].to_s, up["protocol"].to_s, up["certificate"].to_s, up["alias"].to_s)
        cat = Time::Format::YAML_DATE.parse? img["created_at"].to_s
        eat = Time::Format::YAML_DATE.parse? img["expires_at"].to_s
        luat = Time::Format::YAML_DATE.parse? img["last_used_at"].to_s
        uat = Time::Format::YAML_DATE.parse? img["uploaded_at"].to_s
        Image.new(als, img["architecture"].to_s, img["auto_update"].as_bool, img["cached"].as_bool, fingerprint, img["filename"].to_s, pro, update, img["public"].as_bool, img["size"].as_i64, cat.nil? ? Time.new : cat, eat.nil? ? Time.new : eat, luat.nil? ? Time.new : luat, uat.nil? ? Time.new : uat)
    end

    def getAliasesList : Array(String) # GET /1.0/images/aliases 
        l = [] of String
        JSON.parse(@lxd.not_nil!.get("/1.0/images/aliases").body)["metadata"].as_a.each { |a| l << a.to_s }
        l
    end

    def getAliasInfo(name : String) : Alias # GET /1.0/images/aliases/<name>
        json = JSON.parse @lxd.not_nil!.get("/1.0/images/aliases/#{name.gsub("/1.0/images/aliases/","")}").body
        @lxd.not_nil!.logger.debug json
        a = json["metadata"]
        Alias.new(a["name"].to_s, a["description"].to_s, a["target"].to_s)
    end

    struct Image
        property aliases, architecture, auto_update, cached, fingerprint, filename, properties, update_source, public, size, created_at, expires_at, last_used_at, uploaded_at

        def initialize(@aliases : Array(Alias), @architecture : String, @auto_update : Bool, @cached : Bool, @fingerprint : String, @filename : String, @properties : ImageProperties, @update_source : UpdateSource, @public : Bool, @size : Int64, @created_at : Time, @expires_at : Time, @last_used_at : Time, @uploaded_at : Time)
        end
    end

    struct ImageProperties
        property architecture, description, os, release

        def initialize(@architecture : String, @description : String, @os : String, @release : String)
        end
    end

    struct UpdateSource
        property server, protocol, certificate, "alias"

        def initialize(@server : String, @protocol : String, @certificate : String, @alias : String)
        end
    end

    struct Alias
        property name, description, target

        def initialize(@name : String, @description : String, @target : String)
        end
    end
end