
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
        res = @lxd.not_nil!.get "/1.0/images/#{fingerprint.gsub("/1.0/images/", "")}"
        json = JSON.parse res.body
        @lxd.not_nil!.logger.debug json
        img = json["metadata"]
        fingerprint = img["fingerprint"].to_s
        als = [] of Alias
        img["aliases"].as_a.each { |a| als << Alias.new(a["name"].to_s, a["description"].to_s, fingerprint, self) }
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

    def getAliasList : Array(String) # GET /1.0/images/aliases 
        l = [] of String
        json = JSON.parse(@lxd.not_nil!.get("/1.0/images/aliases").body)
        return l if json["metadata"].size == 0
        json["metadata"].as_a.each { |a| l << a.to_s }
        l
    end

    def addAlias(name : String, description : String, target : String) # POST /1.0/images/aliases
        a = { "name" => name, "description" => description, "target" => target.gsub("/1.0/images/", "") }
        @lxd.not_nil!.logger.debug a.to_json
        res = @lxd.not_nil!.post "/1.0/images/aliases", a.to_json
        raise Common::NotFoundException.new "Image fingerptint not found!" if res.status_code == 404
    end

    def getAlias(name : String) : Alias # GET /1.0/images/aliases/<name>
        res = @lxd.not_nil!.get "/1.0/images/aliases/#{name.gsub("/1.0/images/aliases/","")}"
        json = JSON.parse res.body
        @lxd.not_nil!.logger.debug json
        a = json["metadata"]
        Alias.new(a["name"].to_s, a["description"].to_s, a["target"].to_s, self)
    end

    def renameAlias(currentName : String, newName : String)
        res = @lxd.not_nil!.post "/1.0/images/aliases/#{currentName.gsub("/1.0/images/aliases/","")}", { "name" => newName }.to_json
    end

    def updateAlias(name : String, description : String = "", target : String = "") # PATCH /1.0/images/aliases/<name>
        return if description == "" && target == ""
        payload = {} of String => String
        payload["description"] = description if description != ""
        payload["target"] = target if target != ""
        res = @lxd.not_nil!.patch "/1.0/images/aliases/#{name.gsub("/1.0/images/aliases/","")}", payload.to_json
    end

    def deleteAlias(name : String) # DELETE /1.0/images/aliases/<name>
        res = @lxd.not_nil!.delete "/1.0/images/aliases/#{name.gsub("/1.0/images/aliases/","")}"
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

        def initialize(@name : String, @description : String, @target : String, @img : Images)
        end

        def delete
            @img.deleteAlias @name
        end

        def rename(newName : String)
            @img.renameAlias @name, newName
        end
    end
end