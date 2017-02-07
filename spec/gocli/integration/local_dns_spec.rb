require_relative '../spec_helper'
require 'fileutils'

describe 'local DNS', type: :integration do
  with_reset_sandbox_before_each(dns_enabled: false, local_dns: {'enabled' => true, 'include_index' => false})

  let(:cloud_config) { Bosh::Spec::Deployments.simple_cloud_config }
  let(:network_name) { 'local_dns' }

  before do
    cloud_config['networks'][0]['name'] = network_name
    cloud_config['compilation']['network'] = network_name
    upload_cloud_config({:cloud_config_hash => cloud_config})
    upload_stemcell
    create_and_upload_test_release
  end

  let(:ip_regexp) { /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/ }
  let(:job_name) { 'job_to_test_local_dns' }
  let(:canonical_job_name) { 'job-to-test-local-dns' }
  let(:deployment_name) { 'simple.local_dns' }
  let(:canonical_deployment_name) { 'simplelocal-dns' }
  let(:uuid_hostname_regexp) { /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.#{canonical_job_name}\.#{network_name}\.#{canonical_deployment_name}\.bosh/ }
  let(:index_hostname_regexp) { /\d+\.#{canonical_job_name}\.#{network_name}\.#{canonical_deployment_name}\.bosh/ }

  context 'small 1 instance deployment' do
    it 'sends sync_dns action agent and updates /etc/hosts' do
      initial_deployment(1)
    end
  end

  context 'upgrade and downgrade increasing concurrency' do
    context 'upgrade deployment from 1 to 10 instances' do
      it 'sends sync_dns action to all agents and updates all /etc/hosts' do
        manifest_deployment = initial_deployment(1, 5)
        manifest_deployment['jobs'][0]['instances'] = 10
        deploy_simple_manifest(manifest_hash: manifest_deployment)

        etc_hosts = parse_agent_etc_hosts(9)
        expect(etc_hosts.size).to eq(10)
        expect(etc_hosts).to match_array(generate_vms_dns)
      end
    end

    context 'concurrency tests' do
      let(:manifest_deployment) { initial_deployment(10, 5) }

      it 'deploys and downgrades with max_in_flight' do
        pending("#126335577")
        manifest_deployment['jobs'][0]['instances'] = 5
        deploy_simple_manifest(manifest_hash: manifest_deployment)
        etc_hosts = parse_agent_etc_hosts(4)
        expect(etc_hosts.size).to eq(5)
        expect(etc_hosts).to match_array(generate_vms_dns)

        manifest_deployment['jobs'][0]['instances'] = 6
        deploy_simple_manifest(manifest_hash: manifest_deployment)
        etc_hosts = parse_agent_etc_hosts(5)
        expect(etc_hosts.size).to eq(6)
        expect(etc_hosts).to match_array(generate_vms_dns)
      end
    end
  end

  context 'recreate' do
    context 'recreates VMs and updates all agents /etc/hosts' do
      context 'manual networking' do
        it 'updates /etc/hosts with the new info for an instance hostname' do
          manifest_deployment = initial_deployment(5)

          deploy_simple_manifest(manifest_hash: manifest_deployment, recreate: true)
          etc_hosts = parse_agent_etc_hosts(4)
          expect(etc_hosts.size).to eq(5)
          expect(etc_hosts).to match_array(generate_vms_dns)
        end
      end

      context 'dynamic networking' do
        before do
          cloud_config['networks'][0]['type'] = 'dynamic'
          cloud_config['networks'][0]['subnets'][0]['range'] = ''
          cloud_config['networks'][0]['subnets'][0]['dns'] = []
          cloud_config['networks'][0]['subnets'][0]['static'] = []

          upload_cloud_config({:cloud_config_hash => cloud_config})
        end

        it 'updates /etc/hosts with the new info for an instance hostname' do
          manifest_deployment = initial_deployment(5)
          old_ips = current_sandbox.cpi.all_ips

          deploy_simple_manifest(manifest_hash: manifest_deployment, recreate: true)

          current_sandbox.cpi.all_ips.each do |new_ip|
            expect(old_ips).to_not include(new_ip)
          end

          etc_hosts = parse_agent_etc_hosts(4)
          expect(etc_hosts.size).to eq(5)
          expect(etc_hosts).to match_array(generate_vms_dns)
        end
      end
    end

    context 'recreates missing VMs with cck' do
      let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

      it 'automatically recreates missing VMs when cck --auto is used' do
        manifest_deployment = initial_deployment(5)

        current_sandbox.cpi.vm_cids.each do |vm_cid|
          current_sandbox.cpi.delete_vm(vm_cid)
        end

        cloudcheck_response = bosh_run_cck_with_auto
        expect(cloudcheck_response).to match(regexp('missing.'))
        expect(cloudcheck_response).to match(regexp('Applying problem resolutions'))
        expect(cloudcheck_response).to match(regexp('Succeeded'))
        expect(cloudcheck_response).to_not match(regexp('0 problems'))
        expect(cloudcheck_response).to_not match(regexp('1. Skip for now
  2. Reboot VM
  3. Recreate VM using last known apply spec
  4. Delete VM
  5. Delete VM reference (DANGEROUS!)'))

        expect(runner.run('cloud-check --report', deployment_name: deployment_name)).to match(regexp('0 problems'))

        etc_hosts = parse_agent_etc_hosts(4)
        expect(etc_hosts).to match_array(generate_vms_dns)
      end
    end
  end

  def initial_deployment(number_of_instances, max_in_flight=1)
    manifest_deployment = Bosh::Spec::Deployments.test_release_manifest
    manifest_deployment.merge!(
        {
            'update' => {
                'canaries'          => 2,
                'canary_watch_time' => 4000,
                'max_in_flight'     => max_in_flight,
                'update_watch_time' => 20
            },

            'jobs' => [Bosh::Spec::Deployments.simple_job(
                name: job_name,
                instances: number_of_instances)]
        })
    manifest_deployment['name'] = deployment_name
    manifest_deployment['jobs'][0]['networks'][0]['name'] = network_name
    deploy_simple_manifest(manifest_hash: manifest_deployment)

    etc_hosts = parse_agent_etc_hosts(number_of_instances - 1)
    expect(etc_hosts.size).to eq(number_of_instances)
    manifest_deployment
  end

  def parse_agent_etc_hosts(instance_index)
    vm = director.vm('job_to_test_local_dns', instance_index.to_s)

    vm.read_etc_hosts.lines.map do |line|
      words = line.strip.split(' ')
      { 'hostname' => words[1], 'ip' => words[0]}
    end
  end

  def generate_vms_dns
    director.vms.map do |vm|
      {
        'hostname' => "#{vm.instance_uuid}.job-to-test-local-dns.local_dns.simplelocal-dns.bosh",
        'ip' => vm.ips[0],
      }
    end
  end

  def check_ip(ip, ips)
    case ips
    when String
      return true if ip == ips
    when Array
      return ips.include?(ip)
    else
      return false
    end
  end

  def bosh_run_cck_with_auto
    output = bosh_runner.run("cloud-check --auto", deployment_name: deployment_name)
    if $?.exitstatus != 0
      fail("Cloud check failed, output: #{output}")
    end
    output
  end
end
