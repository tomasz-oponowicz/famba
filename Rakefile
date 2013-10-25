require_relative "famba.rb"

task :add_sample_website do
	settings.database['applications'].insert({:_id => BSON::ObjectId("513dfad9e779892946000048"), :name => "Sample website"})
end

task :minify_javascripts do
	`java -jar ./bin/compiler.jar --warning_level VERBOSE -D ENABLE_DEBUG=false --compilation_level ADVANCED_OPTIMIZATIONS --js public/js/famba.js --js_output_file public/js/famba.min.js`
end