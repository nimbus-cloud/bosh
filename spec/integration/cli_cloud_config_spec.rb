require 'spec_helper'

describe "cli cloud config", type: :integration do
  with_reset_sandbox_before_each

  it "can upload a cloud config" do
    bosh_runner.run("target #{current_sandbox.director_url}")
    bosh_runner.run("login test test")
    Dir.mktmpdir do |tmpdir|
      cloud_config_filename = File.join(tmpdir, 'cloud_config.yml')
      File.write(cloud_config_filename, Psych.dump(Bosh::Spec::Deployments.simple_cloud_config))
      expect(bosh_runner.run("update cloud-config #{cloud_config_filename}")).to include("Successfully updated cloud config")
    end
  end

  it "gives nice errors for common problems when uploading", no_reset: true do
    bosh_runner.run("target #{current_sandbox.director_url}")

    # not logged in
    expect(bosh_runner.run("update cloud-config some/path", failure_expected: true)).to include("Please log in first")

    bosh_runner.run("login test test")

    # no file
    expect(bosh_runner.run("update cloud-config /some/nonsense/file", failure_expected: true)).to include("Cannot find file `/some/nonsense/file'")

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      cloud_config_filename = File.join(tmpdir, 'cloud_config.yml')
      File.write(cloud_config_filename, "---\n}}}i'm not really yaml, hah!")
      expect(bosh_runner.run("update cloud-config #{cloud_config_filename}", failure_expected: true)).to include("Incorrect YAML structure")
    end
  end

  it "can download a cloud config" do
    bosh_runner.run("target #{current_sandbox.director_url}")
    bosh_runner.run("login test test")

    # none present yet
    expect(bosh_runner.run("cloud-config")).to eq("Acting as user 'test' on 'Test Director'\n")

    Dir.mktmpdir do |tmpdir|
      cloud_config_filename = File.join(tmpdir, 'cloud_config.yml')
      cloud_config = Psych.dump(Bosh::Spec::Deployments.simple_cloud_config)
      File.write(cloud_config_filename, cloud_config)
      bosh_runner.run("update cloud-config #{cloud_config_filename}")

      expect(bosh_runner.run("cloud-config")).to include(cloud_config)
    end
  end
end
