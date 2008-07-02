require 'rake/testtask'
require 'fileutils'
include FileUtils

RAILS_ROOT=File.dirname(__FILE__)

Rake::TestTask.new do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task :default => [:pretest, :test]

namespace :app do
	task :prepare do
		mkdir_p 'example/vendor/plugins/data_fabric'
		cp_r 'lib', 'example/vendor/plugins/data_fabric'
		cp 'init.rb', 'example/vendor/plugins/data_fabric'
	end

	task :clean do
		rm_rf 'example/vendor/plugins/data_fabric'
	end

	task :test => [:clean, :prepare] do
	end
end

task :pretest do
	setup_connection
  databases = %w( vr_austin_master vr_austin_slave vr_dallas_master vr_dallas_slave )
  databases.each do |db|
    using_connection do
			execute "use #{db}"
      execute "drop table if exists the_whole_burritos"
      execute "drop table if exists enchiladas"
      execute "create table enchiladas (id integer not null auto_increment, name varchar(30) not null, primary key(id))"
      execute "insert into enchiladas (id, name) values (1, '#{db}')"
      execute "create table the_whole_burritos (id integer not null auto_increment, name varchar(30) not null, primary key(id))"
      execute "insert into the_whole_burritos (id, name) values (1, '#{db}')"
		end
	end
end

task :changelog do
	`git log > History.txt`
end

def setup_connection
  require 'rubygems'
  require 'active_record'
  ENV['RAILS_ENV'] = 'test'

  ActiveRecord::Base.configurations = { 'test' => { :adapter => 'mysql', :host => 'localhost', :database => 'mysql' } }
  ActiveRecord::Base.establish_connection 'test'
end

def using_connection(&block)
	ActiveRecord::Base.connection.instance_eval(&block)
end

task :create_db do
	setup_connection

  databases = %w( vr_austin_master vr_austin_slave vr_dallas_master vr_dallas_slave )
  databases.each do |db|
    using_connection do
      execute "drop database #{db}"
      execute "create database #{db}"
      execute "use #{db}"
      execute "create table enchiladas (id integer not null auto_increment, name varchar(30) not null, primary key(id))"
      execute "insert into enchiladas (id, name) values (1, '#{db}')"
      execute "create table the_whole_burritos (id integer not null auto_increment, name varchar(30) not null, primary key(id))"
      execute "insert into the_whole_burritos (id, name) values (1, '#{db}')"
		end  
  end
end
