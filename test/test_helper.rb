ENV['RAILS_ENV'] = 'test'
RAILS_ENV = 'test'
ROOT_PATH = File.expand_path(File.join(File.dirname(__FILE__), ".."))
DATABASE_YML_PATH = File.join(ROOT_PATH, "test", "database.yml")
Dir.chdir(ROOT_PATH)

require 'rubygems'
require 'test/unit'

version = ENV['AR_VERSION']
if version
  puts "Testing ActiveRecord #{version}"
  gem 'activerecord', "=#{version}"
end

require 'active_record'
require 'active_record/version'
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::WARN

# Bootstrap DF
deps = defined?(ActiveSupport::Dependencies) ? ActiveSupport::Dependencies : Dependencies
deps.load_paths << File.join(File.dirname(__FILE__), '../lib')
require 'init'

def load_database_yml
  filename = DATABASE_YML_PATH
  YAML::load(ERB.new(IO.read(filename)).result)
end

def ar22?
  ActiveRecord::VERSION::STRING >= '2.2.0'
end

if !File.exist?(DATABASE_YML_PATH)
  puts "\n*** ERROR ***:\n" <<
    "You must have a 'test/database.yml' file in order to run the unit tests. " <<
    "An example is provided in 'test/database.yml.example'.\n\n"
  exit 1
end
