
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

    def get (name : String) : Container # GET /1.0/containers/<name>
        json = JSON.parse @lxd.not_nil!.get("/1.0/containers/#{name.gsub("/1.0/containers/","")}").body
        @lxd.not_nil!.logger.debug json
        cont = json["metadata"]
        conf = {} of String => String
        cont["expanded_config"].as_h.each { |k, v| conf[k] = v.to_s }
        cat = Time::Format::YAML_DATE.parse? cont["created_at"].to_s
        dev = {} of String => ContainerDevice
        cont["expanded_devices"].as_h.each { |k, v| dev[k] = ContainerDevice.new(v.dig?("path") != nil ? v["path"].to_s : "", v["type"].to_s, v.dig?("nictype") != nil ? v["nictype"].to_s : "", v.dig?("parent") != nil ? v["parent"].to_s : "") }
        luat = Time::Format::YAML_DATE.parse? cont["last_used_at"].to_s
        prof = [] of String
        cont["profiles"].as_a.each { |p| prof << p.to_s }
        Container.new(cont["architecture"].to_s, conf, cat.nil? ? Time.new : cat, dev, cont["ephemeral"].as_bool, luat.nil? ? Time.new : luat, cont["name"].to_s, cont["description"].to_s, prof, cont["stateful"].as_bool, cont["status"].to_s, cont["status_code"].as_i, self)
    end

    def getState(name : String) : ContainerState # GET /1.0/containers/<name>/state
        json = JSON.parse @lxd.not_nil!.get("/1.0/containers/#{name.gsub("/1.0/containers/", "")}/state").body
        @lxd.not_nil!.logger.debug json
        state = json["metadata"]
        cpu = {} of String => Int64
        state["cpu"].as_h.each { |k, v| cpu[k] = v.as_i64 }
        disk = {} of String => Int64
        state["disk"].as_h.each { |k, v| disk[k] = v.as_i64 } if state.dig?("disk") != nil
        m = state["memory"]
        mem = MemoryUsage.new(m["usage"].as_i64, m["usage_peak"].as_i64, m["swap_usage"].as_i64, m["swap_usage_peak"].as_i64)
        net = {} of String => Networks::NetworkState
        if state.dig?("network") != nil
            state["network"].as_h.each do |k, v|
                nadd = [] of Networks::NetworkAddress
                v["addresses"].as_a.each { |a| nadd << Networks::NetworkAddress.new(a["family"] == "inet6" ? Socket::Family::INET6 : Socket::Family::INET, a["address"].to_s, a["netmask"].to_s.to_i16, a["scope"].to_s) }
                count = {} of String => Int64
                v["counters"].as_h.each { |k, v| count[k] = v.as_i64 }
                ty = v["type"] == "broadcast" ? Networks::NetworkStateType::Broadcast : Networks::NetworkStateType::None
                net[k] = Networks::NetworkState.new(nadd, count, v["hwaddr"].to_s, v["host_name"].to_s, v["mtu"].as_i, v["state"].to_s, ty)
            end
        end
        ContainerState.new(state["status"].to_s, state["status_code"].as_i, cpu, disk, mem, net, state["pid"].as_i64, state["processes"].as_i)
    end

    struct Container
        property architecture, config, created_at, devices, ephemeral, last_used_at, name, description,  profiles, stateful, status, status_code

        def initialize(@architecture : String, @config : Hash(String, String), @created_at : Time, @devices : Hash(String, ContainerDevice), @ephemeral : Bool, @last_used_at : Time, @name : String, @description : String, @profiles : Array(String), @stateful : Bool, @status : String, @status_code : Int32, @conts : Containers)
        end

        def getState
            @conts.getState @name
        end
    end

    struct ContainerDevice # @ToDo: Rewrite to use JSON::Any on initialize # @ToDo: Move to Common
        property path, type, nictype, parent

        def initialize(@path : String, @type : String, @nictype : String = "", parent : String = "") # @ToDo: Make type enum
        end
    end

    struct ContainerState
        property status, status_code, cpu, disk, memory, network, pid, processes

        def initialize(@status : String, @status_code : Int32, @cpu : Hash(String, Int64), @disk : Hash(String, Int64), @memory : MemoryUsage, @network : Hash(String, Networks::NetworkState), @pid : Int64, @processes : Int32)
        end
    end

    struct MemoryUsage
        property usage, usage_peak, swap, swap_peak
        
        def initialize(@usage : Int64, @usage_peak : Int64, @swap : Int64, @swap_peak : Int64)
        end
    end
end