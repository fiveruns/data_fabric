ENV['RAILS_ENV']='test'
RAILS_ENV='test'

require 'rubygems'
require 'ruby-debug'
require 'active_support'
Dependencies.load_paths << File.join(File.dirname(__FILE__), '../lib')

require 'active_record'
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::INFO

require 'init'
