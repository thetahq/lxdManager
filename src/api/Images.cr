
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

    def create(aliases : Array(Alias), source : Source, properties : ImageProperties? = nil, public : Bool = false, filename : String? = nil, auto_udate : Bool = false,  compression_algorithm : String? = nil) : String # POST /1.0/images
        payload = {} of String => Array(Alias) | Source | ImageProperties | String | Bool
        payload["aliases"] = aliases
        payload["source"] = source
        payload["properties"] = properties if !properties.nil?
        payload["public"] = public if public
        payload["filaname"] = filename if !filename.nil?
        payload["auto_udate"] = auto_udate if auto_udate
        payload["compression_algorithm"] = compression_algorithm if !compression_algorithm.nil?
        res = @lxd.not_nil!.post "/1.0/images", payload.to_json
        JSON.parse(res.body)["operation"].to_s
    end

    def get(fingerprint : String) : Image # GET /1.0/images/<fingerprint>
        res = @lxd.not_nil!.get "/1.0/images/#{fingerprint.gsub("/1.0/images/", "")}"
        json = JSON.parse res.body
        @lxd.not_nil!.logger.debug json
        Image.from_json json["metadata"].to_json
    end

    def replaceInfo(fingerprint : String, auto_update : Bool, properties : ImageProperties, public : Bool) # PUT /1.0/images/<fimgerprint>
        payload = { "auto_update" => auto_update, "properties" => properties, "public" => public }
        @lxd.not_nil!.post "/1.0/images/#{fingerprint.gsub("/1.0/images/", "")}", payload.to_json
    end
    
    def updateInfo(fingerprint : String, auto_update : Bool? = nil, properties : ImageProperties? = nil, public : Bool? = nil) # PATCH /1.0/images/<fingerprint>
        payload = {} of String => Bool | ImageProperties
        payload["auto_update"] = auto_update if !auto_update.nil?
        payload["properties"] = properties if !properties.nil?
        payload["public"] = public if !public.nil?
        @lxd.not_nil!.patch "/1.0/images/#{fingerprint.gsub("/1.0/images/", "")}", payload.to_json if !payload.empty?
    end

    def delete(fingerprint : String) # DELETE /1.0/images/<fingerprint>
        res = @lxd.not_nil!.delete "/1.0/images/#{fingerprint.gsub("/1.0/images/", "")}"
        raise Common::FailureException.new "Failed to delete the image!" if res.status_code != 202
    end

    def refresh(fingerprint : String) : String # POST /1.0/images/<fingerprint>/refresh
        res = @lxd.not_nil!.post "/1.0/images/#{fingerprint.gsub("/1.0/images/", "")}/refresh", ""
        JSON.parse(res.body)["operation"].to_s
    end

    #S Aliases

    def getAliasList : Array(String) # GET /1.0/images/aliases 
        l = [] of String
        json = JSON.parse(@lxd.not_nil!.get("/1.0/images/aliases").body)
        return l if json["metadata"].size == 0
        json["metadata"].as_a.each { |a| l << a.to_s }
        l
    end

    def addAlias(name : String, description : String, target : String) # POST /1.0/images/aliases
        payload = { "name" => name, "description" => description, "target" => target.gsub("/1.0/images/", "") }
        @lxd.not_nil!.logger.debug payload.to_json
        @lxd.not_nil!.post "/1.0/images/aliases", payload.to_json
    end

    def getAlias(name : String) : Alias # GET /1.0/images/aliases/<name>
       res = @lxd.not_nil!.get "/1.0/images/aliases/#{name.gsub("/1.0/images/aliases/","")}"
       json = JSON.parse res.body
       @lxd.not_nil!.logger.debug json
       Alias.from_json json["metadata"].to_json
    end

    def renameAlias(currentName : String, newName : String)
        @lxd.not_nil!.post "/1.0/images/aliases/#{currentName.gsub("/1.0/images/aliases/","")}", { "name" => newName }.to_json
    end

    def updateAlias(name : String, description : String = "", target : String = "") # PATCH /1.0/images/aliases/<name>
        return if description == "" && target == ""
        payload = {} of String => String
        payload["description"] = description if description != ""
        payload["target"] = target if target != ""
        @lxd.not_nil!.patch "/1.0/images/aliases/#{name.gsub("/1.0/images/aliases/","")}", payload.to_json if !payload.empty?
    end

    def deleteAlias(name : String) # DELETE /1.0/images/aliases/<name>
        @lxd.not_nil!.delete "/1.0/images/aliases/#{name.gsub("/1.0/images/aliases/","")}"
    end

    #S Images and Aliases Structs

    struct Image
        JSON.mapping(
            aliases: Array(Alias), 
            architecture: String, 
            auto_update: Bool, 
            cached: Bool, 
            fingerprint: String, 
            filename: String, 
            properties: ImageProperties, 
            update_source: UpdateSource, 
            public: Bool, 
            size: Int64, 
            created_at: Time, 
            expires_at: Time, 
            last_used_at: Time, 
            uploaded_at: Time
        )

        def delete
            LXDSocket.i.not_nil!.images.delete @fingerprint
        end

        def refresh : String
            LXDSocket.i.not_nil!.images.refresh @fingerprint
        end

        def replaceInfo(auto_update : Bool, properties : ImageProperties, public : Bool)
            LXDSocket.i.not_nil!.images.replaceInfo @fingerprint, auto_update, properties, public
        end

        def updateInfo(auto_update : Bool? = nil, properties : ImageProperties? = nil, public : Bool? = nil)
            LXDSocket.i.not_nil!.images.updateInfo @fingerprint, auto_update, properties, public
        end
    end

    struct ImageProperties
        JSON.mapping(
            architecture: String?, 
            description: String?, 
            os: String?,
            release: String?
        )

        def initialize(@architecture : String? = nil, @description : String? = nil, @os : String? = nil, @release : String? = nil)
        end
    end

    struct UpdateSource
        JSON.mapping(
            server: String,
            protocol: String,
            certificate: String,
            "alias": String
        )
    end

    struct Alias
        JSON.mapping(
            name: String,
            description: String,
            target: String
        )

        def initialize(@name, @description, @target = "")
        end

        def delete
            LXDSocket.i.not_nil!.images.deleteAlias @name
        end

        def rename(newName : String)
            LXDSocket.i.not_nil!.images.renameAlias @name, newName
        end
    end

    abstract struct Source
    end

    struct ImageSource < Source
        JSON.mapping(
            type: String,
            mode: String,
            server: String,
            protocol: String,
            secret: String?,
            certificate: String?,
            fingerprint: String?,
            "alias": String?
        )

        def initialize(@server, @secret : String? = nil,@certificate : String? = nil, @fingerprint : String? = nil, @alias : String? = nil, @protocol : String = "lxd")
            @type = "image"
            @mode = "pull"
        end
    end

    struct ContainerSource < Source
        JSON.mapping(
            type: String,
            name: String
        )

        def initialize(@name)
            @type = "container"
        end
    end

    struct URLSource < Source
        JSON.mapping(
            type: String,
            url: String
        )

        def initialize(@url)
            @type = "url"
        end
    end
end