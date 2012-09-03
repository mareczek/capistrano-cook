require "digest"

Capistrano::Configuration.instance.load do
  set_default(:copy_ssh_key, true)
  set_default(:ssh_key_name) do
    Capistrano::CLI.ui.ask "Provide name for the rsa file (default is 'id', come up with with smth more meaningful): "
  end
  set_default(:ssh_key_passphrase) do
    Capistrano::CLI.ui.ask "Yo dude, this shit is important! Type a strong passphrase: "
  end

  def template(from, to)
    if File.exists?("deploy/templates/#{from}")
      logger.info "using template form #{File.absolute_path('deploy/template/' + from)}"
      erb = File.read("deploy/templates/#{from}")
    else
      erb = File.read(File.expand_path("templates/#{from}", File.dirname(__FILE__)))
    end
    put ERB.new(erb).result(binding), to
  end

  def set_default(name, *args, &block)
    set(name, *args, &block) unless  exists?(name)
  end

  def generate_password(len=16)
    Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{user}--")[0,len]
  end

  namespace :deploy do
    desc "Install everything on server"
    task :install do
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install python-software-properties curl build-essential git-core libssl-dev"
    end

    desc "fix privilages for shared folders"
    task :setup_privilages do
      run "#{sudo} chown -R #{user} #{shared_path}"
      run "#{sudo} chown -R #{user} #{deploy_to}"
    end
    after "deploy:setup", "deploy:setup_privilages"
  end

  namespace :root do
    desc "create depoly user and add proper privilages"
    task :add_user do
      set_default(:usr_password) { Capistrano::CLI.password_prompt "Password for new user:" }
      set :base_user, user
      set :user, 'root'
      begin
        run "addgroup admin"
      rescue Capistrano::CommandError => e
        logger.info "group admin already exists."
      end
      run "useradd -s /bin/bash -G admin -mU #{base_user}"
      run "echo '#{usr_password}' >  tmp_pass"
      run "echo '#{usr_password}' >> tmp_pass"
      run "passwd #{base_user} < tmp_pass"
      run "rm tmp_pass"
      set :user, base_user
    end

    task :copy_ssh_key do
      if copy_ssh_key 

        begin
          run "mkdir ~/.ssh"
        rescue Capistrano::CommandError => e
          logger.info ".ssh directory already exists in the home directory of #{user}"
        end

        id_rsa_name     = copy_ssh_key
        rsa_passphrase  = ssh_key_passphrase

        id_rsa_name ||= 'id_rsa'

        begin
          existing_file = system("ls -x1 ~/.ssh/#{id_rsa_name}.pub")
        rescue Capistrano::CommandError => e
          logger.info "File does not exist, need to generate one"
          existing_file = false
        end

        if existing_file == false
          rsa_passphrase && rsa_passphrase.length > 0 ? 
            run("ssh-keygen -f ~/.ssh/#{id_rsa_name} -N #{rsa_passphrase}") : 
            run("ssh-keygen -f ~/.ssh/#{id_rsa_name}")
          existing_file = "~/.ssh/#{id_rsa_name}.pub"
        end

        if existing_file != false
          key = system("cat ~/.ssh/#{id_rsa_name}.pub")
          if key && key.length > 0
            begin
              run "mkdir ~/.ssh"
            rescue Capistrano::CommandError => e
              logger.info "remote .ssh directory already exists"
            end
            run "echo '#{key}' >> ~/.ssh/authorized_keys"
          end
        end

      end
    end
    after "root:add_user", "root:copy_ssh_key"
  end
end
