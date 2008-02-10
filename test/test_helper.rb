ENV['RAILS_ENV']='test'
RAILS_ENV='test'

require 'rubygems'
require 'active_support'
Dependencies.load_paths << File.join(File.dirname(__FILE__), '../lib')

require 'init'
