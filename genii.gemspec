# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{genii}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Bryan Stearns"]
  s.date = %q{2010-10-25}
  s.default_executable = %q{genii}
  s.description = %q{Yet another take on system setup in Ruby}
  s.email = %q{bryanstearns@gmail.com}
  s.executables = ["genii"]
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "bin/genii",
     "genii.gemspec",
     "lib/genii.rb",
     "lib/genii/execute.rb",
     "lib/genii/feature.rb",
     "lib/genii/features/apache_application.rb",
     "lib/genii/features/apache_vhost.rb",
     "lib/genii/features/apt_update.rb",
     "lib/genii/features/backup.rb",
     "lib/genii/features/backup/nightlybackup",
     "lib/genii/features/cron_job.rb",
     "lib/genii/features/directory.rb",
     "lib/genii/features/dns.rb",
     "lib/genii/features/etc_hosts.rb",
     "lib/genii/features/file.rb",
     "lib/genii/features/firewall.rb",
     "lib/genii/features/fonts.rb",
     "lib/genii/features/fstab_noatime.rb",
     "lib/genii/features/groups.rb",
     "lib/genii/features/monit.rb",
     "lib/genii/features/monit/monit_top",
     "lib/genii/features/mysql_server.rb",
     "lib/genii/features/network.rb",
     "lib/genii/features/packages.rb",
     "lib/genii/features/passenger.rb",
     "lib/genii/features/passenger/passenger.conf.erb",
     "lib/genii/features/rails_app_instance.rb",
     "lib/genii/features/redis.rb",
     "lib/genii/features/ruby_gem.rb",
     "lib/genii/features/rvm.rb",
     "lib/genii/features/rvm/install-system-wide",
     "lib/genii/features/search.rb",
     "lib/genii/features/send_mail.rb",
     "lib/genii/features/service.rb",
     "lib/genii/features/service_restart.rb",
     "lib/genii/features/shell.rb",
     "lib/genii/features/site_permissions.rb",
     "lib/genii/features/ssh.rb",
     "lib/genii/features/ssh/sshd_config",
     "lib/genii/features/ssh_keys.rb",
     "lib/genii/features/time_and_zone.rb",
     "lib/genii/features/user.rb",
     "lib/genii/file_cache.rb",
     "lib/genii/file_template.rb",
     "lib/genii/fu.rb",
     "lib/genii/git.rb",
     "lib/genii/initializers.rb",
     "lib/genii/log.rb",
     "lib/genii/machine.rb",
     "lib/genii/munge.rb",
     "lib/genii/random_password.rb",
     "lib/genii/relative_path.rb",
     "lib/genii/site_info.rb",
     "lib/genii/users_and_groups.rb",
     "test/genii-local.yml",
     "test/genii.yml",
     "test/helper.rb",
     "test/others/foo.erb",
     "test/others/hash_test",
     "test/test_execute.rb",
     "test/test_feature.rb",
     "test/test_file_cache.rb",
     "test/test_initializers.rb",
     "test/test_random_password.rb",
     "test/test_users_and_groups.rb"
  ]
  s.homepage = %q{http://github.com/bryanstearns/genii}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{System setup from scratch}
  s.test_files = [
    "test/test_users_and_groups.rb",
     "test/test_file_cache.rb",
     "test/helper.rb",
     "test/test_initializers.rb",
     "test/test_random_password.rb",
     "test/test_execute.rb",
     "test/test_feature.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    else
      s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    end
  else
    s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
  end
end

