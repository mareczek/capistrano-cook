Capistrano::Configuration.instance.load do
  set_default(:unicorn_user)          { user }
  set_default(:unicorn_template)      { File.expand_path("../../templates/unicorn.rb.erb", __FILE__) }
  set_default(:unicorn_init_template) { File.expand_path("../../templates/unicorn_init.erb", __FILE__) }
  set_default(:unicorn_pid)           { "#{current_path}/tmp/pids/unicorn.pid" }
  set_default(:unicorn_config)        { "#{shared_path}/config/unicorn.rb" }
  set_default(:unicorn_log)           { "#{shared_path}/log/unicorn.log" }
  set_default(:unicorn_workers, 2)
  set_default(:rails_server, :unicorn)

  namespace :unicorn do
    desc "Setup Unicorn initializer and app configuration"
    task :setup, roles: :app do
      run "#{sudo} mkdir -p #{shared_path}/config"
      template unicorn_template, "/tmp/unicorn.rb"
      run "#{sudo} mv /tmp/unicorn.rb #{unicorn_config}"
      template unicorn_init_template, "/tmp/unicorn_init"
      run "chmod +x /tmp/unicorn_init"
      run "#{sudo} mv /tmp/unicorn_init /etc/init.d/unicorn_#{application}"
      run "#{sudo} update-rc.d -f unicorn_#{application} defaults"
    end
    after "deploy:setup", "unicorn:setup" if rails_server == :unicorn

    %w[start stop restart].each do |command|
      desc "#{command} unicorn"
      task command, roles: :app do
        run "service unicorn_#{application} #{command}"
      end
      after "deploy:#{command}", "unicorn:#{command}" if rails_server == :unicorn
    end
  end
end