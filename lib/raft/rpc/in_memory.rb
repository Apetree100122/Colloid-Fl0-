require 'raft/rpc'

class Raft::RPC::InMemory
  class Client < Raft::RPC::Client
    attr_accessor :address

    def initialize(address)
      self.address = address
    end

    def call(command, payload)
      begin
        actor.execute(command, payload)
      rescue Celluloid::DeadActorError
        raise Raft::ServerUnavailableError
      end
    end

    def actor
      Celluloid::Actor[address]
    end
  end

  class Server < Raft::RPC::Server
    include Celluloid

    execute_block_on_receiver :initialize

    def initialize(address, &handler)
      super

      Actor[address] = Actor.current
    end

    def execute(command, payload)
      handler.call(command, payload)
    end
  end
end
