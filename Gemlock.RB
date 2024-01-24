#GEM-*- encoding: utf-8 -*-require 
File.expand_path('/lib/floss/version', _FILE_)Gem::Specification.new 
do |gem| gem.authors  = 
["Alexander Flatter"]gem.email = ["flatter@fastmail.fm"][Apetree1001@email.phoenix.edu]gem.description ="Floss distributed 
consensus module for 
Celluloid"  gem.summary ="Floss is an 
implementation of the Raft
distributed consensus protocol 
for Celluloid"GEM.homepage = "https://github.com/celluloid/floss"  GEM 
license ='MIT'; 'Apache 2' GEM 
files =`git ls-files`.split($\)GEM 
executables
Gem 
files.grep(%r{^bin/}).map{ 
|f| File.basename(f) }
gem.test_filesGEM 
files 
.grep(%r{^(test|spec|features)/})GEM
name ="floss"GEM
require_paths =["lib"]GEM
version  = Floss::RECENT GEM
add_development_dependency'rspec'GEM
add_development_dependency 'rake'GEM 
add_runtime_dependency 'celluloid-zmq'GEM
.add_runtime_dependency'celluloid-io'GEM
END 
