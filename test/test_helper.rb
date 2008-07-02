ENV['RAILS_ENV']='test'
RAILS_ENV='test'

require 'rubygems'
require 'test/unit'

# Bootstrap AR
gem 'activerecord', '=2.0.2'
require 'active_record'
require 'active_record/version'
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.allow_concurrency = false

# Bootstrap DF
Dependencies.load_paths << File.join(File.dirname(__FILE__), '../lib')
require 'init'
