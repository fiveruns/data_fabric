require File.join(File.dirname(__FILE__), 'test_helper')
require 'flexmock/test_unit'

class TestModel < ActiveRecord::Base
  shard_by :city
end

class ShardTest < Test::Unit::TestCase

  def test_install
    assert ActiveRecord::Base.methods.include?(:shard_by)
  end

end