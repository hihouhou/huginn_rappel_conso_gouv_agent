require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::RappelConsoGouvAgent do
  before(:each) do
    @valid_options = Agents::RappelConsoGouvAgent.new.default_options
    @checker = Agents::RappelConsoGouvAgent.new(:name => "RappelConsoGouvAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
