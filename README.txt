data_fabric - flexible database connection switching for ActiveRecord

What?

We needed two features to scale our mysql database: application-level sharding and master/slave replication.
Sharding is the process of splitting a dataset across many independent databases.  This often happens based on geographical region (e.g. craigslist) or category (e.g. ebay).  Replication provides a near-real-time copy of a database which can be used for fault tolerance and to reduce load on the master node.  Combined, you get a scalable database solution which does not require huge hardware to scale to huge volumes.  Or: DPAYEIOB - don't put all your eggs in one basket.  :-)


How?

You need to describe the topology for your database infrastructure in your model(s).  As with ActiveRecord normally, different models can use different topologies.

class MyHugeVolumeOfDataModel < ActiveRecord::Base
  connection_topology :replicated => true, :shard_by => :city
end

There are four supported modes of operation, depending on the options given to the connection_topology method.  The plugin will look for connections in your config/database.yml with the following convention:

No connection topology:
#{environment} - this is the default, as with ActiveRecord, e.g. "production"

connection_topology :replicated => true
#{environment}_#{role} - no sharding, just replication, where role is "master" or "slave", e.g. "production_master"

connection_topology :shard_by => :city
#{group}_#{shard}_#{environment} - sharding, no replication, e.g. "city_austin_production"

connection_topology :replicated => true, :shard_by => :city
#{group}_#{shard}_#{environment}_#{role} - sharding with replication, e.g. "city_austin_production_master"


When marked as replicated, all write and transactional operations for the model go to the master, whereas read operations go to the slave.

Since sharding is an application-level concern, your application must set the shard to use based on the current request or environment.  The current shard for a group is set on a thread local variable.  For example, you can set the shard in an ActionController begin_filter based on the user as follows:

class ApplicationController < ActionController::Base
	begin_filter :select_shard
	
	private
	def select_shard
		DataFabric.activate_shard(:city, @current_user.city)
	end
end


Thanks to...

Rick Olsen - for the Masochism plugin, which I borrowed heavily from to bend AR's connection handling to my will
Bradley Taylor - for the advice to shard


Who?

Mike Perham <mperham+ruby@gmail.com>

Copyright (C) 2008 FiveRuns Corporation

Parts of the code are:
Copyright (c) 2007 Rick Olson