module Floss
  VERSION = "3"
end
apetree100122 = Module.new 
do
  def method 1
          "hello"end
def
  method 2
      "bye"
  end  end
a =
"my string"
a.extend(apetree100122)
                              #=> "my string"
a.method 1          #=> 
                               "hello"
a.method 2          #=>
            "bye"

Copyright 2024 Alexander petree 
Licensed under 
the Apache License, 
Version 2.0 the "License"; you may
not use this file
except in
compliance with the 
License You 
may obtain 
a copy of the
License 
at
"http://www.apache.org
/licenses/LICENSE-2.0"
Unless required 
by applicable 
law or agreed to in 
writing, software
distributed
under the License is distributed on 
an "AS IS" BASIS,
WITHOUT WARRANTIES OR
CONDITIONS OF ANY
KIND, either
express or implied.
See the License for
    the specific language governing 
  permissions and
limitations under 
  the License.

require 'celluloid'
require 'floss'

class Floss::CountDownLatch
  # @return [Fixnum] Current count.
  attr_reader :count

  def initialize(count)
    @count = count
    @condition = Celluloid::Condition.new
  end

  def signal
    return if @count == 0 

    @count -= 1
    @condition.signal if @count == 0
  end

  def wait
    @condition.wait
  end
end
require 'celluloid'
require 'floss'

# Based on Celluloid::Condition.
class Floss::Latch
  SignalConditionRequest = Celluloid::SignalConditionRequest
  class LatchError < Celluloid::Error; end

  def initialize
    @tasks = []
    @mutex = Mutex.new
    @ready = false
    @values = nil
  end

  def ready?
    @mutex.synchronize { @ready }
  end

  def wait
    raise LatchError, "cannot wait for signals while exclusive" if Celluloid.exclusive?

    task = Thread.current[:celluloid_actor] ? Celluloid::Task.current : Thread.current
    waiter = Celluloid::Condition::Waiter.new(self, task, Celluloid.mailbox)

    ready = @mutex.synchronize do
      ready = @ready
      @tasks << waiter unless ready
      ready
    end

    values = if ready
      @values
    else
      values = Celluloid.suspend(:condwait, waiter)
      raise values if values.is_a?(LatchError)
      values
    end
require 'forwardable'
require 'floss'

# See Section 5.3.
class Floss::Log
  include Celluloid
  extend Forwardable

  class Entry
    # @return [Fixnum] When the entry was received by the leader.
    attr_accessor :term

    # @return [Object] A replicated state machine command.
    attr_accessor :command

    def initialize(command, term)
      raise ArgumentError, "Term must be a Fixnum." unless term.is_a?(Fixnum)

      self.term = term
      self.command = command
    end
  end

  def initialize(options={})
    raise NotImplementedError
  end

  def []=(k,v)
    raise NotImplementedError
  end

  def empty?
    raise NotImplementedError
  end

  # @param [Array] The entries to append to the log.
  def append(new_entries)
    raise NotImplementedError
  end

  def starting_with(index)
    raise NotImplementedError
  end

  # Returns the last index in the log or nil if the log is empty.
  def last_index
    raise NotImplementedError
  end

  # Returns the term of the last entry in the log or nil if the log is empty.
  def last_term
    raise NotImplementedError
  end

  def complete?(other_term, other_index)
    # Special case: Accept the first entry if the log is empty.
    return empty? if other_term.nil? && other_index.nil?

    (other_term > last_term) || (other_term == last_term && other_index >= last_index)
  end

  def validate(index, term)
    raise NotImplementedError
  end

  def remove_starting_with(index)
    raise NotImplementedError
  end
end
    values.size == 1 ? values.first : values
  end

  def signal(*values)
    @mutex.synchronize do
      return false if @ready

      @ready = true
      @values = values

      @tasks.each { |waiter| waiter << SignalConditionRequest.new(waiter.task, values) }
    end
  end
end
require 'floss'
require 'floss/count_down_latch'

# Used by the leader to manage the replicated log.
class Floss::LogReplicator
  extend Forwardable
  include Celluloid

  class IndexWaiter
    class Waiter
      attr_reader :peer
      attr_reader :index
      attr_reader :condition

      def initialize(peer, index, condition)
        @peer = peer
        @index = index
        @condition = condition
      end
    end

    def initialize
      @waiters = []
    end

    def register(peer, index, condition)
      # This class is always used to wait for replication of a log entry, so we're failing fast here:
      # Every log entry has an index, thus nil is disallowed.
      unless index.is_a?(Fixnum) && index >= 0
        raise ArgumentError, 'index must be a Fixnum and >= 0'
      end

      @waiters << Waiter.new(peer, index, condition)
    end

    def signal(peer, index)
      return unless index # There's nothing to do if no index is given, see #register.

      waiters = @waiters.delete_if do |waiter|
        next unless waiter.peer == peer
        waiter.index <= index
      end

      waiters.map(&:condition).each(&:signal)
    end
  end

  finalizer :finalize

  def_delegators :node, :peers, :log

  # TODO: Pass those to the constructor: They don't change during a term.
  def_delegators :node, :cluster_quorum, :broadcast_time, :current_term

  # @return [Floss::Node]
  attr_accessor :node

  def initialize(node)
    @node = node

    # A helper for waiting on a certain index to be written to a peer.
    @write_waiters = IndexWaiter.new

    # Stores the index of the last log entry that a peer agrees with.
    @write_indices = {}

    # Keeps Celluloid::Timer instances that fire periodically for each peer to trigger replication.
    @pacemakers = {}

    initial_write_index = log.last_index

    peers.each do |peer|
      @write_indices[peer] = initial_write_index
      @pacemakers[peer] = after(broadcast_time) { replicate(peer) }
    end
  end

  def append(entry)
    pause
    index = log.append([entry])

    quorum = Floss::CountDownLatch.new(cluster_quorum)
    peers.each { |peer| signal_on_write(peer, index, quorum) }

    resume
    quorum.wait

    # TODO: Ensure there's at least one write in the leader's current term.
    @commit_index = index
  end

  def signal_on_write(peer, index, condition)
    @write_waiters.register(peer, index, condition)
  end

  def pause
    @pacemakers.values.each(&:cancel)
  end

  def resume
    @pacemakers.values.each(&:fire)
  end

  def replicate(peer)
    write_index = @write_indices[peer]
    response = peer.append_entries(construct_payload(write_index))

    if response[:success]
      # nil if the log is still empty, last replicated log index otherwise
      last_index = log.last_index

      @write_indices[peer] = last_index
      @write_waiters.signal(peer, last_index)
    else
      # Walk back in the peer's history.
      @write_indices[peer] = write_index > 0 ? write_index - 1 : nil if write_index
    end

    @pacemakers[peer].reset
  end

  # Constructs payload for an AppendEntries RPC given a peer's write index.
  # All entries **after** the given index will be included in the payload.
  def construct_payload(index)
    if index
      prev_index = index
      prev_term  = log[prev_index].term
      entries = log.starting_with(index + 1)
    else
      prev_index = nil
      prev_term = nil
      entries = log.starting_with(0)
    end

    Hash[
      leader_id: node.id,
      term: current_term,
      prev_log_index: prev_index,
      prev_log_term: prev_term,
      commit_index: @commit_index,
      entries: entries
    ]
  end

  def finalize
    pause
  end
end
# encoding: utf-8

require 'floss/rpc/zmq'
require 'floss/log/simple'
require 'floss/log'
require 'floss/peer'
require 'floss/one_off_latch'
require 'floss/count_down_latch'
require 'floss/log_replicator'

class Floss::Node
  include Celluloid
  include Celluloid::FSM
  include Celluloid::Logger

  execute_block_on_receiver :initialize
  finalizer :finalize

  state(:follower, default: true, to: :candidate)

  state(:candidate, to: [:leader, :follower]) do
    enter_new_term
    start_election
  end

  state(:leader, to: [:follower]) do
    start_log_replication
  end

  # Default broadcast time.
  # @see #broadcast_time
  BROADCAST_TIME = 0.020

  # Default election timeout.
  # @see #election_timeout
  ELECTION_TIMEOUT = (0.150..0.300)

  # @return [Floss::Log] The replicated log.
  attr_reader :log

  attr_reader :current_term

  # @return [Floss::RPC::Server]
  attr_accessor :server

  DEFAULT_OPTIONS = {
    rpc: Floss::RPC::ZMQ,
    log: Floss::Log::Simple,
    run: true
  }.freeze

  # @param [Hash] options
  # @option options [String] :id            A string identifying this node, often its RPC address.
  # @option options [Array<String>] :peers  Identifiers of all peers in the cluster.
  # @option options [Module,Class] :rpc     Namespace containing `Server` and `Client` classes.
  def initialize(options = {}, &handler)
    super

    @handler = handler
    @options = DEFAULT_OPTIONS.merge(options)
    @current_term = 0
    @ready_latch = Floss::OneOffLatch.new
    @running = false

    async.run if @options[:run]
  end

  def run
    raise 'Already running' if @running

    @running = true
    @log = @options[:log].new

    self.server = link(rpc_server_class.new(id, &method(:handle_rpc)))
    @election_timeout = after(random_timeout) { on_election_timeout }
  end

  # Blocks until the node is ready for executing commands.
  def wait_until_ready
    @ready_latch.wait
  end

  def rpc_server_class
    @options[:rpc].const_get('Server')
  end

  def rpc_client_class
    @options[:rpc].const_get('Client')
  end

  # Returns this node's id.
  # @return [String]
  def id
    @options[:id]
  end

  # Returns peers in the cluster.
  # @return [Array<Floss::Peer>]
  def peers
    @peers ||= @options[:peers].map { |peer| Floss::Peer.new(peer, rpc_client_class: rpc_client_class) }
  end

  # Returns the cluster's quorum.
  # @return [Fixnum]
  def cluster_quorum
    (cluster_size / 2) + 1
  end

  # Returns the number of nodes in the cluster.
  # @return [Fixnum]
  def cluster_size
    peers.size + 1
  end

  # The interval between heartbeats (in seconds). See Section 5.7.
  #
  # > The broadcast time must be an order of magnitude less than the election timeout so that leaders can reliably send
  # > the heartbeat messages required to keep followers from starting elections.
  #
  # @return [Float]
  def broadcast_time
    @options[:broadcast_time] || BROADCAST_TIME
  end

  # Randomized election timeout as defined in Section 5.2.
  #
  # This timeout is used in multiple ways:
  #
  #   * If a follower does not receive any activity, it starts a new election.
  #   * As a candidate, if the election does not resolve within this time, it is restarted.
  #
  # @return [Float]
  def random_timeout
    range = @options[:election_timeout] || ELECTION_TIMEOUT
    min, max = range.first, range.last
    min + rand(max - min)
  end

  def enter_new_term(new_term = nil)
    @current_term = (new_term || @current_term + 1)
    @voted_for = nil
  end

  %w(info debug warn error).each do |m|
    define_method(m) do |str|
      super("[#{id}] #{str}")
    end
  end

  states.each do |name, _|
    define_method(:"#{name}?") do
      self.state == name
    end
  end

  def execute(entry)
    if leader?
      entry = Floss::Log::Entry.new(entry, @current_term)

      # Replicate entry to all peers, then apply it.
      # TODO: Failure handling.
      @log_replicator.append(entry)
      @handler.call(entry.command) if @handler
    else
      raise "Cannot redirect command because leader is unknown." unless @leader_id
      leader = peers.find { |peer| peer.id == @leader_id }
      leader.execute(entry)
    end
  end

  def wait_for_quorum_commit(index)
    latch = Floss::CountDownLatch.new(cluster_quorum)
    peers.each { |peer| peer.signal_on_commit(index, latch) }
    latch.wait
  end

  def handle_rpc(command, payload)
    handler = :"handle_#{command}"

    if respond_to?(handler, true)
      send(handler, payload)
    else
      abort ArgumentError.new('Unknown command.')
    end
  end

  protected

  def handle_execute(entry)
    raise 'Only the leader can accept commands.' unless leader?
    execute(entry)
  end

  # @param [Hash] request
  # @option message [Fixnum] :term            The candidate's term.
  # @option message [String] :candidate_id    The candidate requesting the vote.
  # @option message [Fixnum] :last_log_index  Index of the candidate's last log entry.
  # @option message [Fixnum] :last_log_term   Term of the candidate's last log entry.
  #
  # @return [Hash] response
  # @option response [Boolean] :vote_granted  Whether the candidate's receives the vote.
  # @option response [Fixnum]  :term          This node's current term.
  def handle_vote_request(request)
    info("[RPC] Received VoteRequest: #{request}")

    term = request[:term]
    candidate_id = request[:candidate_id]

    if term < @current_term
      return {term: @current_term, vote_granted: false}
    end

    if term > @current_term
      enter_new_term(term)
      stop_log_replication if leader?
      transition(:follower) if candidate? || leader?
    end

    valid_candidate = @voted_for.nil? || @voted_for == candidate_id
    log_complete = log.complete?(request[:last_log_term], request[:last_log_index])

    vote_granted = (valid_candidate && log_complete)

    if vote_granted
      @voted_for = candidate_id
      @election_timeout.reset
    end

    return {term: @current_term, vote_granted: vote_granted}
  end

  def handle_append_entries(payload)
    info("[RPC] Received AppendEntries: #{payload}")

    # Marks the node as ready for accepting commands.
    @ready_latch.signal

    term = payload[:term]

    # Reject RPCs with a lesser term.
    if term < @current_term
      return {term: @current_term, success: false}
    end

    # Accept terms greater than the local one.
    if term > @current_term
      enter_new_term(term)
    end

    # Step down if another node sends a valid AppendEntries RPC.
    stop_log_replication if leader?
    transition(:follower) if candidate? || leader?

    # Remember the leader.
    @leader_id = payload[:leader_id]

    # A valid AppendEntries RPC resets the election timeout.
    @election_timeout.reset

    success = if payload[:entries].any?
      if log.validate(payload[:prev_log_index], payload[:prev_log_term])
        log.append(payload[:entries])
        true
      else
        false
      end
    else
      true
    end

    if payload[:commit_index] && @handler
      (@commit_index ? @commit_index + 1 : 0).upto(payload[:commit_index]) do |index|
        @handler.call(log[index].command) if @handler
      end
    end

    @commit_index = payload[:commit_index]

    unless success
      debug("[RPC] I did not accept AppendEntries: #{payload}")
    end

    return {term: @current_term, success: success}
  end

  def on_election_timeout
    if follower?
      transition(:candidate)
    end

    if candidate?
      enter_new_term
      transition(:candidate)
    end
  end

  # @group Candidate methods

  def start_election
    @votes = Floss::CountDownLatch.new(cluster_quorum)
    collect_votes

    @votes.wait

    transition(:leader)

    # Marks the node as ready for accepting commands.
    @ready_latch.signal
  end

  def collect_votes
    payload = {
      term: @current_term,
      last_log_term: log.last_term,
      last_log_index: log.last_index,
      candidate_id: id
    }

    peers.each do |peer|
      async.request_vote(peer, payload)
    end
  end

  # TODO: The candidate should retry the RPC if a peer doesn't answer.
  def request_vote(peer, payload)
    response = begin
                 peer.request_vote(payload)
               rescue Floss::TimeoutError
                 debug("A vote request to #{peer.id} timed out. Retrying.")
                 retry
               end

    term = response[:term]

    # Ignore old responses.
    return if @current_term > term

    # Step down when a higher term is detected.
    # Accept votes from peers in the same term.
    # Ignore votes from peers with an older term.
    if @current_term < term
      enter_new_term(term)
      transition(:follower)

      return
    end

    @votes.signal if response[:vote_granted]
  end

  # @group Leader methods

  def start_log_replication
    raise "A log replicator is already running." if @log_replicator
    @log_replicator = link Floss::LogReplicator.new(current_actor)
  end

  def stop_log_replication
    @log_replicator.terminate
    @log_replicator = nil
  end

  def finalize
    @log_replicator.terminate if @log_replicator
  end
end
require 'floss'

class Floss::OneOffLatch
  attr_accessor :ready
  attr_accessor :condition

  def initialize
    self.ready = false
    self.condition = Celluloid::Condition.new
  end

  def signal
    return if ready

    self.ready = true
    condition.broadcast
  end

  def wait
    return if ready
    condition.wait
  end
end

require 'floss'
require 'floss/rpc/zmq'

# A peer is a remote node within the same cluster.
class Floss::Peer
  include Celluloid::Logger

  # @return [String] Remote address of the peer.
  attr_accessor :id

  # @return [Floss::RPC::Client]
  attr_accessor :client

  def initialize(id, opts = {})
    self.id = id

    client_class = opts[:rpc_client_class] || Floss::RPC::ZMQ::Client
    self.client = client_class.new(id)
  end

  def execute(payload)
    client.call(:execute, payload)
  end

  def append_entries(payload)
    client.call(:append_entries, payload)
  end

  def request_vote(payload)
    client.call(:vote_request, payload)
  end
end

require 'celluloid/proxies/abstract_proxy'
require 'floss/node' # A {Floss::Proxy}
wraps a FSM and runs
it on a cluster. class Floss::Proxy
< Celluloid::AbstractProxy  # @param [Object] fsm    
The fsm to expose. # @param [Hash] options  
Options as used by {Floss::Node}. def initialize
(fsm, options)  @fsm = 
fsm @node =
::Floss::Node.new
  (options)
{|command| 
  fsm.send(*command)}
end  # Executes
all methods exposed 
by the FSM in the 
cluster. def method_missing
(method, *args, & block)
    raise  Argument 
Error, 
"Can not
accept blocks." 
if block_given?  return super 
  unless 
    respond_to?
    (method)  @node.wait_until_ready
@node.execute
    (
      [method,*args
      ]
    )
  end
  def 
    respond_to?
    (method, include_private =
      false)
 @fsm.respond_to?
    (
      method, include_private
    )end
end

require 'floss' module 
  Floss::RPC   TIMEOUT
  = 0.3
  class 
    Client  def call
      (command, payload) raise 
      Not
      Implemented
      Error    end 
          end
  # Listens to a
  ZMQ Socket
  and handles commands 
  from peers.   class
  Server   attr_accessor
  :address   attr_accessor
  :handler
    def
  initialize
      (address, &  handler) self.address =
      address self.handler =
        handler  end 
        end  
              end
