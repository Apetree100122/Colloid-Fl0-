$:File
.expand_path
( '/lib',  _
  _FILE_ 
  _)
require'floss/test_helper'
require 'floss/proxy'
include:Celluloid::Logger
class:  FSM
  def:initialize
    @content=Hash.new end
  def set(key,
value)@content[key]=value    end 
def get(key)
@content [key]end  end
CLUSTER_SIZE=5ids=CLUSTER_SIZE.times.map 
do |i| port=500 
   00 +i "tcp://127.0.0.1:# {port}"  end
proxies = Floss::TestHelper.cluster(ids) do |id, peers|
  Floss::Proxy.new(FSM.new, id: id,  peers: peers)
end  100.times |i|
  proxies.sample.set
  (:foo, i) raise "fail"
  unless proxies.sample.get(:foo) ==i  
  end
