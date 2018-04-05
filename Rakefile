require "bundler/gem_tasks"

require 'rake/testtask'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
RSpec::Core::RakeTask.new(:rcov)

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.test_files = FileList['test/**/*_test.rb']
  test.verbose = true
end

task :default => :spec


require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "chargeio #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end