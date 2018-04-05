# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chargeio/version'

Gem::Specification.new do |gem|
  gem.name          = "chargeio"
  gem.version       = ChargeIO::VERSION
  gem.authors       = ["James Sparrow"]
  gem.email         = ["james@affinipay.com"]
  gem.description   = "ChargeIO Merchant Gem"
  gem.license       = 'MIT'
  gem.summary       = ""
  gem.homepage      = ""


  gem.add_dependency 'httparty'
  gem.add_dependency 'activesupport'

  gem.add_development_dependency "rake"
  gem.add_development_dependency "bundler", ">= 1.0.0"
  gem.add_development_dependency "rspec", ">= 3.5.0"
  gem.add_development_dependency "money"
  gem.add_development_dependency "pry-byebug"
  gem.add_development_dependency "net-http-spy"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  
end
