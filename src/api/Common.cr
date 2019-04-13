
# Common code for API

class Common
    struct Device
        JSON.mapping(
            path: String,
            type: String,
            name: String?,
            nictype: String?,
            parent: String?
        )
    end

    struct Resource
        JSON.mapping(
            used: UInt64,
            total: UInt64
        )
    end

    def self.errorHandler(res : HTTP::Client::Response, method : String, path : String, log : Logger) : HTTP::Client::Response
        case res.status_code
        when 400
            Handler(FailureException).handle res, method, path, log
        when 401
            Handler(CancelledException).handle res, method, path, log
        when 404
            Handler(NotFoundException).handle res, method, path, log
        when 409
            Handler(ConflictException).handle res, method, path, log
        when 500
            Handler(NotImplementedException).handle res, method, path, log
        end
        if res.status_code > 400
            log.error "=================================="
            log.error "Unknown Error with code #{res.status_code}!"
            log.error res.body
            log.error "=================================="
            raise "Unknown error!"
        end
        res
    end

    class Handler(T)
        def self.handle(res, method, path, log)
            case path
            when .includes? "/1.0/containers"
                case T.to_s
                when NotFoundException.to_s
                    raise T.new "Container '#{path.split("/")[3]}'"
                when ConflictException.to_s
                    raise T.new "Container with that name already exists!"
                else
                    raise T.new
                end
            when .includes?("/1.0/images/aliases")
                case T.to_s
                when NotFoundException.to_s
                    raise T.new "Image Fingerprint not found!" if method == "POST"
                    raise T.new "Alias '#{path.split("/")[4]}' not found!"
                when ConflictException.to_s
                    raise T.new "Alias with that name already exists!"
                else
                    raise T.new
                end
            when .includes? "/1.0/images"
                case T.to_s
                when NotFoundException.to_s
                    raise T.new "Container not found!" if method == "POST"
                    raise T.new "Image fingerprint not found!"
                else
                    raise T.new
                end
            when .includes? "/1.0/networks"
                case T.to_s
                when NotFoundException.to_s
                    raise T.new "Network '#{path.split("/")[3]}' not found!"
                when ConflictException.to_s
                    raise T.new "Network with that name already exists!"
                else
                    raise T.new
                end
            when .includes? "/1.0/operations"
                case T.to_s
                when NotFoundException.to_s
                    raise T.new "Operation id not found!"
                else
                    raise T.new
                end
            when .includes? "/1.0/profiles"
                case T.to_s
                when NotFoundException.to_s
                    raise T.new "Profile '#{path.split("/")[3]}' not found!"
                when ConflictException.to_s
                    raise T.new "Profile with that name already exists!"
                when ForbiddenException.to_s
                    raise T.new "It is Forbidden to delete the default profile!" if method == "DELETE"
                    raise T.new "It is Forbidden to rename the default profile!"
                else
                    raise T.new
                end
            when .includes? "/1.0/storage-pools"
                case T.to_s
                when NotFoundException.to_s
                    raise T.new "Storage Pool '#{path.split("/")[3]}' not found!"
                when ConflictException.to_s
                    raise T.new "Storage Pool with that name already exists!"
                else
                    raise T.new
                end
            when .includes? "/1.0/cluster/members"
                case T.to_s
                when NotFoundException.to_s
                    raise T.new "Member '#{path.split("/")[4]}' not found!"
                when ConflictException.to_s
                    raise T.new "Member with that name already exists!"
                else
                    raise T.new
                end
            when .includes? "/1.0/cluster"
                case T.to_s
                when NotFoundException.to_s
                    raise T.new "Cluster '#{path.split("/")[3]}' not found!"
                else
                    raise T.new
                end
            end
            log.error "Unknown path!"
            raise T.new
        end
    end

    macro except(name, message)
        class {{name}} < Exception
            def initialize(@message : String? = nil, @cause : Exception? = nil)
                @message = {{message}} if @message.nil?
            end
        end
    end

    except FailureException, "The Operation ended in Failure!" # 400

    except CancelledException, "The Operation has been Canceled!" # 401

    except ForbiddenException, "The Operation is Forbidden!" # 403

    except NotFoundException, "Not Found!" # 404

    except ConflictException, "The Operation encountered a Conflict!" # 409

    except NotImplementedException, "Not yet Implemented!" # 500
end