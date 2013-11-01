require 'rake/testtask'
require_relative 'famba.rb'

task :default => [:test, :minify_javascripts]

task :add_sample_website do
  settings.database['applications'].insert({:_id => BSON::ObjectId("513dfad9e779892946000048"), :name => "Sample website"})
end

task :add_indexes do
  settings.database['events'].create_index({ :application_id => Mongo::ASCENDING, :previous_url => Mongo::ASCENDING, :timestamp => Mongo::DESCENDING })
end

task :minify_javascripts do
  puts "Minifying JavaScript files..."
  `java -jar ./bin/compiler.jar --warning_level VERBOSE -D ENABLE_DEBUG=false --compilation_level ADVANCED_OPTIMIZATIONS --js public/js/famba.js --js_output_file public/js/famba.min.js`
end

Rake::TestTask.new do |t|

  # set test enviorment
  ENV['RACK_ENV'] = 'test'

  # invoke all test in directory 'test/functional'
  t.libs << "test"
  t.test_files = FileList['test/functional/*_test.rb']
  t.verbose = true
end