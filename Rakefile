require 'rubygems'
require 'echoe'

require File.dirname(__FILE__) << "/lib/data_fabric/version"

Echoe.new 'fiveruns_manage' do |p|
	p.version = DataFabric::Version::STRING
	p.author = "Mike Perham"
	p.email  = 'mperham@gmail.com'
	p.project = 'fiveruns'
	p.summary = 'Sharding and replication support for ActiveRecord 2.x'
	p.url = "http://github.com/fiveruns/data_fabric"
	p.dependencies = ['activerecord >=2.0.2']
	p.include_rakefile = true
end

require 'rake/testtask'

RAILS_ROOT=File.dirname(__FILE__)

Rake::TestTask.new do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task :pretest do
	setup(false)
end

task :create_db do
	setup(true)
end

task :changelog do
	`git log | grep -v git-svn-id > History.txt`
end

def setup_connection
  require 'active_record'
  ENV['RAILS_ENV'] = 'test'

  ActiveRecord::Base.configurations = { 'test' => { :adapter => 'mysql', :host => 'localhost', :database => 'mysql' } }
  ActiveRecord::Base.establish_connection 'test'
end

def using_connection(&block)
  ActiveRecord::Base.connection.instance_eval(&block)
end

def setup(create = false)
  setup_connection

  databases = %w( vr_austin_master vr_austin_slave vr_dallas_master vr_dallas_slave )
  databases.each do |db|
    using_connection do
			if create
				execute "drop database if exists #{db}"
				execute "create database #{db}"
			end
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
