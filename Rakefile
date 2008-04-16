require 'rake/testtask'

RAILS_ROOT=File.dirname(__FILE__)

Rake::TestTask.new do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task :default => :test

task :create_db do
  require 'rubygems'
  require 'active_record'
  ENV['RAILS_ENV'] = 'test'

  ActiveRecord::Base.configurations = { 'test' => { :adapter => 'mysql', :host => 'localhost', :database => 'mysql' } }
  ActiveRecord::Base.establish_connection 'test'

  def using_connection(&block)
    ActiveRecord::Base.connection.instance_eval(&block)
  end

  databases = %w( vr_austin_master vr_austin_slave vr_dallas_master vr_dallas_slave )
  databases.each do |db|
    using_connection {
      execute "drop database #{db}"
      execute "create database #{db}"
      execute "use #{db}"
      execute "create table the_whole_burritos (id integer not null auto_increment, name varchar(30) not null, primary key(id))"
      execute "insert into the_whole_burritos (id, name) values (1, '#{db}')"
    }  
  end
end
