shard - a library for database sharding with ActiveRecord

What?

Sharding is the process of splitting a dataset across many independent databases.  This often
happens based on geographical region (e.g. craigslist) or category (e.g. ebay).

Why?

When you have a site which requires heavy database usage and lots of customers, a central database will eventually become the bottleneck, no matter how well tuned.

How?

A shard is an individual database.  A shard group is a set of databases which contain the same
type of data.

An ActiveRecord model is marked as "sharded" within a group which means that all access to the model will use a connection to a particular shard within the group.

The current shard for a group is set on a thread local variable so that you can set the shard
in an ActionController begin_filter based on the user as follows:

class ApplicationController < ActionController::Base
	begin_filter :select_shard
	
	private
	def select_shard
		Shard.activate(:city, @current_user.city)
	end
end

This assumes you have a shard group "city" based on the user's associated city.
The connection to the specific shard is pulled from the set of ActiveRecord connections by
establishing a connection to "#{prefix}_#{shard}_#{environment}" so it might look for something 
like "city_austin_development" in your config/database.yml.

Who?

Mike Perham <mperham+ruby@gmail.com>

Copyright (C) 2008 FiveRuns Corporation