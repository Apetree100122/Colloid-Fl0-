2024 Alexander petree Apetree1001@email.phoenix.edu 
require 'floss/rpc'
require 'floss/rpc/zmq'
require 'floss/rpc/in_memory'

class TestActor
  include Celluloid

  execute_block_on_receiver :exec

  def exec
    yield
  end
end

shared_examples 'an RPC implementation' do
  def actor_run(&block)
    actor = TestActor.new
    result = actor.exec(&block)
    actor.terminate
    result
  end

  let(:server_class) { described_class::Server }
  let(:client_class) { described_class::Client }

  let(:command) { :command }
  let(:payload) { Hash[key: 'value'] }

  it 'executes calls' do
    server = server_class.new(address) { |command, payload| [command, payload] }
    client = client_class.new(address)
    actor_run { client.call(command, payload) }.should eq([command, payload])
  end

  it 'executes multiple calls sequentially' do
    calls = 3.times.map { |i| [:command, i] }
    server = server_class.new(address) { |command, payload| [command, payload] }
    client = client_class.new(address)
    actor_run { calls.map { |args| client.call(*args) } }.should eq(calls)
  end

  it 'raises an error if server is not available' do
    client = client_class.new(address)
    expect { actor_run { client.call(:command, :payload) } }.to raise_error(Floss::TimeoutError)
    expect { client.to be_alive }
  end

  it 'raises an error if server does not respond in time' do
    server = server_class.new(address) { |command, payload| sleep 1.5; [command, payload] }
    client = client_class.new(address)
    expect { actor_run { client.call(:command, :payload) } }.to raise_error(Floss::TimeoutError)
    expect { client.to be_alive }
  end
end

describe Floss::RPC::InMemory do
  let(:address) { :node1 }

  before(:each) do
    Celluloid.shutdown
    Celluloid.boot
  end

  it_should_behave_like 'an RPC implementation'
end

describe Floss::RPC::ZMQ do
  let(:address) { 'tcp://127.0.0.1:12345' }

  before(:each) do
    Celluloid.shutdown
    Celluloid.boot
  end

  it_should_behave_like 'an RPC implementation'
end

require 'floss/node'

describe Floss::Node do
  it "doesn't crash when all of its peers are down" do
    opts = {id: 'tcp://127.0.0.1:7001', peers: ['tcp://127.0.0.1:7002', 'tcp://127.0.0.1:7003']}
    node = described_class.new(opts)
    sleep(node.broadcast_time)
    expect(node).to be_alive
  end
end
require 'floss/log'
require 'floss/log/simple'

shared_examples 'a Log implementation' do

  before do
    @log = described_class.new {}
    @log.remove_starting_with(0)
  end

  it 'returns empty when there are no entries' do
    @log.should be_empty
  end

  it 'appends entries' do
    entries = [Floss::Log::Entry.new('command1',1),
               Floss::Log::Entry.new('command2',1),
               Floss::Log::Entry.new('command3',1)
    ]
    @log.append(entries)
  end

  it 'can return an entry by index' do
    entries = [Floss::Log::Entry.new('command1',1)]
    @log.append(entries)
    entry = @log[0]
    entry.command.should eql('command1')
  end

  it 'can return a range of entries' do
    entries = [Floss::Log::Entry.new('command1',1),
               Floss::Log::Entry.new('command2',1),
               Floss::Log::Entry.new('command3',1)
    ]
    @log.append(entries)
    range = @log.starting_with(1)
    range.size.should eql(2)
    range[0].command.should eql('command2')
  end

  it 'can return index of the last entry' do
    @log.append([Floss::Log::Entry.new('command1',1),
                Floss::Log::Entry.new('command2',1)])
    idx = @log.last_index
    idx.should eql(1)
  end

  it 'returns the term of the last entry' do
    @log.append([Floss::Log::Entry.new('command1',1),
                Floss::Log::Entry.new('command2',1)])
    term = @log.last_term
    term.should eql(1)
  end

end

describe Floss::Log::Simple do
  it_should_behave_like 'a Log implementation'
end

$: << File.expand_path('../../lib', __FILE__)

require 'logger'
require 'celluloid'

logfile = File.open(File.expand_path("../../log/test.log", __FILE__), 'w')
logfile.sync = true
Celluloid.logger = Logger.new(logfile)
Celluloid.shutdown_timeout = 1
