require 'rspec/core/formatters/console_codes'

RSpec.configure do |config|
  if ENV['OS_IMAGE']
    config.before(:all) do
      @os_image_dir = Dir.mktmpdir('os-image')
      Bosh::Core::Shell.new.run("sudo tar xf #{ENV['OS_IMAGE']} -C #{@os_image_dir}")
      SpecInfra::Backend::Exec.instance.chroot_dir = @os_image_dir
    end

    config.after(:all) do
      FileUtils.rm_rf(@os_image_dir) if ENV['OS_IMAGE']
    end
  else
    warning = 'All OS_IMAGE tests are being skipped. ENV["OS_IMAGE"] must be set to test OS images'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding os_image: true
  end
end
