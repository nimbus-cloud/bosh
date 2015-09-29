# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::State do
  include FakeFS::SpecHelpers

  before(:each) do
    FileUtils.mkdir_p("/tmp")
    state_file = Tempfile.new("agent-state")

    Bosh::Agent::Config.state    = Bosh::Agent::State.new(state_file.path)
    Bosh::Agent::Config.settings = { "vm" => "zb", "agent_id" => "007" }

    Bosh::Agent::Monit.enabled = true
    @monit_mock = double('monit_api_client')
    Bosh::Agent::Monit.stub(:monit_api_client).and_return(@monit_mock)
  end

  it 'should have initial empty state' do
    handler = Bosh::Agent::Message::State.new
    initial_state = {
      "deployment"    => "",
      "networks"      => { },
      "resource_pool" => { },
      "agent_id"      => "007",
      "vm"            => "zb",
      "job_state"     => [ ],
      "drbd"          => {"connection_state"=>"not running", "role"=>"", "disk_state"=>"", "sync_state"=>""},
      "bosh_protocol" => Bosh::Agent::BOSH_PROTOCOL,
      "ntp"           => { "message" => Bosh::Agent::NTP::FILE_MISSING }
    }
    handler.stub(:job_state).and_return([])
    handler.state.should == initial_state
  end
  
  it "should parse and report drbd status" do

    FileUtils.mkdir_p("/proc")
    File.open('/proc/drbd', 'w+') do |f| 
      f.write("version: 8.4.4 (api:1/proto:86-101)\n")
      f.write("GIT-hash: 74402fecf24da8e5438171ee8c19e28627e1c98a build by @ubuntu, 2014-06-24 08:46:56\n")
      
      f.write("1: cs:Connected ro:Primary/Secondary ds:UpToDate/UpToDate A r-----\n")
      f.write("   ns:2842968 nr:0 dw:1167792 dr:1680521 al:19 bm:103 lo:0 pe:0 ua:0 ap:0 ep:1 wo:f oos:0\n")
      
    end

    initial_state = {
      "deployment"    => "",
      "networks"      => { },
      "resource_pool" => { },
      "agent_id"      => "007",
      "vm"            => "zb",
      "job_state"     => [ ],
      "drbd"          => {"connection_state"=>"Connected", "role"=>"Primary/Secondary", "disk_state"=>"UpToDate/UpToDate"},
      "bosh_protocol" => Bosh::Agent::BOSH_PROTOCOL,
      "ntp"           => { "message" => Bosh::Agent::NTP::FILE_MISSING }
    }
    handler = Bosh::Agent::Message::State.new
    handler.stub(:job_state).and_return([])
    handler.state.should == initial_state
  end

  it "should report job_state as running" do
    handler = Bosh::Agent::Message::State.new

    status = { "foo" => { :status => { :message => "running", :code => 0 }, :monitor => :yes }}
    @monit_mock.should_receive(:status).with(:group => "vcap").and_return(status)
    @monit_mock.should_receive(:status).with(:group => "vcap_monitor").and_return(status)

    handler.state['job_state'].should == "running"
  end

  it "should report job_state as starting" do
    handler = Bosh::Agent::Message::State.new

    status = { "foo" => { :status => { :message => "running" }, :monitor => :init }}
    @monit_mock.should_receive(:status).and_return(status)

    handler.state['job_state'].should == "starting"
  end

  it "should report job_state as failing" do
    handler = Bosh::Agent::Message::State.new

    status = { "foo" => { :status => { :message => "born to run" }, :monitor => :yes }}
    @monit_mock.should_receive(:status).and_return(status)

    handler.state['job_state'].should == "failing"
  end

  it "should report vitals" do
    handler = Bosh::Agent::Message::State.new(['full'])

    status = { "foo" => { :status => { :message => "running" }, :monitor => :yes }}
    @monit_mock.should_receive(:status).with(:group => "vcap").and_return(status)
    @monit_mock.should_receive(:status).with(:group => "vcap_monitor").and_return(status)

    vitals = {
      "foo" => {
        :raw => {
          "system" => {
            "load" => {"avg01" => "1", "avg05" => "5", "avg15" => "15"},
            "cpu" => {"user" => "u", "system" => "s", "wait" => "w"},
            "memory" => {"percent" => "p", "kilobyte" => "k"},
            "swap" => {"percent" => "p", "kilobyte" => "k"},
          }
        }
      }
    }
    @monit_mock.should_receive(:status).with(:type => :system).and_return(vitals)

    agent_vitals = handler.state['vitals']
    agent_vitals['load'].should == ["1", "5", "15"] &&
    agent_vitals['cpu']['user'].should == "u" &&
    agent_vitals['mem']['percent'].should == "p" &&
    agent_vitals['swap']['percent'].should == "p"
  end

end
