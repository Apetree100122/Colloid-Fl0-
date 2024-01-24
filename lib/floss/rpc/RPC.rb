2024 (c) Alexander petree <Apetree100122><Apetree1001@email.phoenix.edu>
require 'floss/rpc'
require 'celluloid/io/stream'
require 'celluloid/zmq'

class Floss::RPC::ZMQ
  class Client < Floss::RPC::Client
    include Celluloid::ZMQ

    # @return [Celluloid::IO::Stream::Latch]
    attr_accessor :latch

    attr_accessor :address

    # @return [Celluloid::ZMQ::ReqSocket]
    attr_accessor :socket

    # Disconnect when shutting the client down.
    finalizer :disconnect

    def initialize(address)
      self.latch = Celluloid::IO::Stream::Latch.new
      self.address = address
      connect
    end

    def connect
      self.socket = Celluloid::ZMQ::ReqSocket.new
      socket.connect(address)
    end

    def disconnect
      socket.close if socket
    end

    def call(command, payload)
      message = encode_request(command, payload)
      response = latch.synchronize { request(message) }
      decode_response(response)
    end

    def request(message)
      timeout(Floss::RPC::TIMEOUT) do
        socket.send(message)
        socket.read
      end
    rescue Celluloid::Task::TimeoutError
      disconnect
      connect
      abort Floss::TimeoutError.new("RPC timed out (#{address}).")
    end

    def encode_request(command, payload)
      "#{command}:#{Marshal.dump(payload)}"
    end

    def decode_response(response)
      Marshal.load(response)
    end
  end

  class Server < Floss::RPC::Server
    include Celluloid::ZMQ
    include Celluloid::Logger

    attr_accessor :socket

    execute_block_on_receiver :initialize
    finalizer :finalize

    def initialize(address, &handler)
      super
      async.run
    end

    def run
      self.socket = RepSocket.new

      begin
        info("Binding to #{address}")
        socket.bind(address)
      rescue IOError
        socket.close
        raise
      end

      async.loop!
    end

    def loop!
      loop { handle(socket.read) }
    end

    # @param [String] request  A request string containing command and payload separated by a colon.
    def handle(request)
      command, payload = decode_request(request)
      response = handler.call(command, payload)
      socket.send(encode_response(response))
    end

    def encode_response(response)
      Marshal.dump(response)
    end

    def decode_request(request)
      command, payload = request.split(':', 2)
      payload = Marshal.load(payload)

      [command.to_sym, payload]
    end

    def finalize
      socket.close if socket
    end

    def terminate
      super
      socket.close if socket
    end
  end
  end
  require 'floss/rpc'

class Floss::RPC::InMemory
  class Client < Floss::RPC::Client
    include Celluloid

    attr_accessor :address

    def initialize(address)
      self.address = address
    end

    def call(command, payload)
      timeout(Floss::RPC::TIMEOUT) { actor.execute(command, payload) }
    rescue Celluloid::DeadActorError, Celluloid::Task::TimeoutError
      raise Floss::TimeoutError
    end

    def actor
      Celluloid::Actor[address]
    end
  end

  class Server < Floss::RPC::Server
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
