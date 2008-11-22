require 'rubygems'
require 'echoe'

#gem 'rails', '=2.0.2'

require File.dirname(__FILE__) << "/lib/data_fabric/version"

Echoe.new 'data_fabric' do |p|
  p.version = DataFabric::Version::STRING
  p.author = "Mike Perham"
  p.email  = 'mperham@gmail.com'
  p.project = 'fiveruns'
  p.summary = 'Sharding and replication support for ActiveRecord 2.x'
  p.url = "http://github.com/fiveruns/data_fabric"
  p.dependencies = ['activerecord >=2.0.2']
  p.development_dependencies = []
  p.rubygems_version = nil
  p.include_rakefile = true
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

def load_database_yml
  filename = "test/database.yml"
  if !File.exist?(filename)
    STDERR.puts "\n*** ERROR ***:\n" <<
      "You must have a 'test/database.yml' file in order to create the test database. " <<
      "An example is provided in 'test/database.yml.mysql'.\n\n"
    exit 1
  end
  YAML::load(ERB.new(IO.read(filename)).result)
end

def setup_connection
  require 'active_record'
  ActiveRecord::Base.configurations = load_database_yml
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  ActiveRecord::Base.logger.level = Logger::DEBUG
end

def using_connection(database_identifier, &block)
  ActiveRecord::Base.establish_connection(database_identifier)
  ActiveRecord::Base.connection.instance_eval(&block)
end

def setup(create = false)
  setup_connection
  
  ActiveRecord::Base.configurations.each_pair do |identifier, config|
    using_connection(identifier) do
      send("create_#{config['adapter']}", create, config['database'])
    end  
  end
end

def create_sqlite3(create, db_name)
  execute "drop table if exists the_whole_burritos"
  execute "drop table if exists enchiladas"
  execute "create table enchiladas (id integer not null primary key, name varchar(30) not null)"
  execute "insert into enchiladas (id, name) values (1, '#{db_name}')"
  execute "create table the_whole_burritos (id integer not null primary key, name varchar(30) not null)"
  execute "insert into the_whole_burritos (id, name) values (1, '#{db_name}')"
end

def create_mysql(create, db_name)
  if create
    execute "drop database if exists #{db_name}"
    execute "create database #{db_name}"
  end
  execute "use #{db_name}"
  execute "drop table if exists the_whole_burritos"
  execute "drop table if exists enchiladas"
  execute "create table enchiladas (id integer not null auto_increment, name varchar(30) not null, primary key(id))"
  execute "insert into enchiladas (id, name) values (1, '#{db_name}')"
  execute "create table the_whole_burritos (id integer not null auto_increment, name varchar(30) not null, primary key(id))"
  execute "insert into the_whole_burritos (id, name) values (1, '#{db_name}')"
end
