
# Class for the /1.0/containers API portion

class Containers
    setter lxd : LXDSocket?

    def getList : Array(String) # GET /1.0/containers
        l = [] of String
        json = JSON.parse(@lxd.not_nil!.get("/1.0/containers").body)
        return l if json["metadata"].size == 0
        json["metadata"].as_a.each { |entry| l << entry.to_s }
        l
    end

    def create(name : String, architecture : String, profiles : Array(String), ephemeral : Bool, config : Hash(String, String), devices : Hash(String, Common::Device), source : Source) : String # POST /1.0/containers
        payload = { "name" => name, "architecture" => architecture, "profiles" => profiles, "ephemeral" => ephemeral, "config" => config, "devices" => devices, "source" => source }
        res = @lxd.not_nil!.post "/1.0/containers", payload.to_s
        JSON.parse(res.body)["operation"].to_s
    end

    def get (name : String) : Container # GET /1.0/containers/<name>
        json = JSON.parse @lxd.not_nil!.get("/1.0/containers/#{name.gsub("/1.0/containers/","")}").body
        @lxd.not_nil!.logger.debug json
        Container.from_json json["metadata"].to_json
    end

    def rename(name : String, newName : String) : String # POST /1.0/containers/<name>
        res = @lxd.not_nil!.post "/1.0/containers/#{name.gsub("/1.0/containers/", "")}", { "name" => newName }.to_json
        JSON.parse(res.body)["operation"].to_s
    end

    def replaceInfo(name : String, architecture : String, config : Hash(String, String), devices : Hash(String, Common::Device), ephemeral : Bool, profiles : Array(String)) : String # PUT /1.0/containers/<name>
        payload = { "architecture" => architecture, "config" => config, "devices" => devices, "ephemeral" => ephemeral, "profiles" => profiles }
        res = @lxd.not_nil!.put "/1.0/containers/#{name.gsub("/1.0/containers/", "")}", payload.to_json
        JSON.parse(res.body)["operation"].to_s
    end

    def updateInfo(name : String, architecture : String? = nil, config : Hash(String, String)? = nil, devices : Hash(String, Common::Device)? = nil, ephemeral : Bool? = nil, profiles : Array(String)? = nil) # PATCH /1.0/containers/<name>
        payload = {} of String => String | Hash(String, String) | Hash(String, Common::Device) | Bool | Array(String)
        payload["architecture"] = architecture if !architecture.nil?
        payload["config"] = config if !config.nil?
        payload["devices"] = devices if !devices.nil?
        payload["ephemeral"] = ephemeral if !ephemeral.nil?
        payload["profiles"] = profiles if !profiles.nil?
        @lxd.not_nil!.patch "/1.0/containers/#{name.gsub("/1.0/containers/", "")}", payload.to_json
    end

    def restore(name : String, snapshot : String) : String # PUT /1.0/containers/<name>
        res = @lxd.not_nil!.put "/1.0/containers/#{name.gsub("/1.0/containers/", "")}", { "restore" => snapshot }.to_json
        JSON.parse(res.body)["operation"].to_s
    end

    def delete(name : String) : String # DELETE /1.0/containers/<name>
        res = @lxd.not_nil!.delete "/1.0/containers/#{name.gsub("/1.0/containers/", "")}"
        JSON.parse(res.body)["operation"].to_s
    end

    def getState(name : String) : ContainerState # GET /1.0/containers/<name>/state
        json = JSON.parse @lxd.not_nil!.get("/1.0/containers/#{name.gsub("/1.0/containers/", "")}/state").body
        @lxd.not_nil!.logger.debug json
        ContainerState.from_json json ["metadata"].to_json
    end

    def changeState(name : String, toState : State) : String # PUT /1.0/containers/<name>/state
        res = @lxd.not_nil!.put "/1.0/containers/#{name.gsub("/1.0/containers/","")}/state", toState.to_json
        JSON.parse(res.body)["operation"].to_s
    end

    struct Container
        JSON.mapping(
            architecture: String,
            config: Hash(String, String),
            created_at: Time,
            devices: Hash(String, Common::Device),
            ephemeral: Bool,
            last_used_at: Time,
            name: String,
            description: String,
            profiles: Array(String),
            stateful: Bool,
            status: String,
            status_code: UInt16
        )

        def getState
            LXDSocket.i.not_nil.containers.getState @name
        end

        def rename(newName : String) : String
            LXDSocket.i.not_nil.containers @name, newName
        end

        def replaceInfo(architecture : String, config : Hash(String, String), devices : Hash(String, Common::Device), ephemeral : Bool, profiles : Array(String)) : String
            LXDSocket.i.not_nil.containers.replaceInfo @name, architecture, config, devices, ephemeral, profiles
        end

        def updateInfo(architecture : String? = nil, config : Hash(String, String)? = nil, devices : Hash(String, Common::Device)? = nil, ephemeral : Bool? = nil, profiles : Array(String)? = nil)
            LXDSocket.i.not_nil.containers.updateInfo @name, architecture, config, devices, ephemeral, profiles
        end

        def restore(snapshot : String) : String
            LXDSocket.i.not_nil.containers.restore @name, snapshot
        end

        def delete : String
            LXDSocket.i.not_nil.containers.delete @name
        end

        def changeState(toState : State) : String
            LXDSocket.i.not_nil.containers.changeState @name, toState
        end
    end

    struct ContainerState
        JSON.mapping(
            status: String,
            status_code: UInt16,
            cpu: Hash(String, UInt64),
            disk: Hash(String, UInt64),
            memory: MemoryUsage,
            network: Hash(String, Networks::NetworkState),
            pid: UInt32,
            processes: UInt16
        )
    end

    struct MemoryUsage
        JSON.mapping(
            usage: UInt64,
            usage_peak: UInt64,
            sawp_usage: UInt64,
            swap_usage_peak: UInt64
        )
    end

    abstract struct State
        JSON.mapping(
            action: String,
            timeout: UInt16,
            force: Bool,
            stateful: Bool
        )
    end

    struct Start < State
        def initialize(@timeout : UInt16 = 30, @force : Bool = false, @stateful : Bool = false)
            @action = "start"
        end
    end

    struct Restart < State
        def initialize(@timeout : UInt16 = 30, @force : Bool = false, @stateful : Bool = false)
            @action = "restart"
        end
    end

    struct Stop < State
        def initialize(@timeout : UInt16 = 30, @force : Bool = false, @stateful : Bool = false)
            @action = "stop"
        end
    end

    abstract struct Source
    end

    struct NoneSource < Source
        JSON.mapping( type: String )

        def initialize
            @type = "none"
        end
    end

    struct ImageAliasSource < Source
        JSON.mapping(
            type: String,
            "alias": String
        )

        def initialize(@alias)
            @type = "image"
        end
    end

    struct ImageFingerprintSource < Source
        JSON.mapping(
            type: String,
            fingerprint: String
        )

        def initialize(@fingerprint)
            @type = "image"
        end
    end

    struct ImagePropertiesSource < Source
        JSON.mapping(
            type: String,
            properties: Images::ImageProperties
        )

        def initialize(@properties)
            @type = "image"
        end
    end

    struct CopySource < Source
        JSON.mapping(
            type: String,
            container_only: Bool,
            source: String
        )

        def initialize(@source, @container_only : Bool = true)
            @type = "copy"
        end
    end

    struct PullMigrationSource < Source
        JSON.mapping(
            type: String,
            mode: String,
            operation: String,
            certificate: {type: String, nilable: true},
            "base_image": {type: String, nilable: true},
            container_only: Bool,
            secrets: Secrets
        )

        def initialize(@operation, @secrets, @container_only : Bool = true, @certificate : String? = nil, @base_image : String? = nil)
            @type = "migration"
            @mode = "pull"
        end

        struct Secrets
            JSON.mapping(
                control: String,
                criu: String,
                fs: String
            )

            def initialize(@control, @criu, @fs)
            end
        end
    end

    struct PushMigrationSource < Source
        JSON.mapping(
            type: String,
            mode: String,
            "base_image": {type: String, nilable: true},
            live: Bool,
            container_only: Bool
        )

        def initialize(@live : Bool = true, @container_only : Bool = true, @base_image : String = nil)
            @type = "migration"
            @mode = "push"
        end
    end
end