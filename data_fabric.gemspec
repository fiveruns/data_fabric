Gem::Specification.new do |s|
	s.name = 'fiveruns-data_fabric'
	s.version = '1.0.0'
	s.authors = ['Mike Perham']
	s.email = 'mike@fiveruns.com'
	s.homepage = 'http://github.com/fiveruns/data_fabric'
	s.summary = 'A Database Shard API for ActiveRecord 2.x'
	s.description = s.summary

	s.require_path = 'lib'

	s.files = ["README.rdoc", "License.txt", "History.txt", "Rakefile", "init.rb", "lib/data_fabric.rb", "test/connection_test.rb", "test/database.yml", "test/database_test.rb", "test/shard_test.rb", "test/test_helper.rb"]
	s.test_files = ["test/test_data_fabric.rb"]
end
