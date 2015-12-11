define :goapp_deploy_config_and_monit do
  # application_name
  # revision
  # goapp_application_settings
  # hostname
  # deploy_to
  # env_vars
  # config_vars
  # monit_conf_dir
  # group
  # user
  # custom_config_path

  service 'monit' do
    action :nothing
  end

  template "#{params[:config_file]}" do
    source  'config.properties.erb'
    mode    '0660'
    owner    params[:user]
    group    params[:group]
    variables(
      :application_name => params[:application_name],
      :deploy_path      => params[:deploy_to],
      :env_vars         => params[:env_vars],
      :config_vars      => params[:config_vars],
      :revision         => params[:revision]
    )
  end
  
  template "#{params[:deploy_to]}/current/goapp-#{params[:application_name]}-server-daemon" do
    source   'goapp-server-daemon.erb'
    owner    params[:user]
    group    params[:group]
    mode     '0751'
    variables(
      :deploy_to        => params[:deploy_to],
      :pid_file         => params[:goapp_application_settings][:pid_file],
      :release_path     => "#{params[:deploy_to]}/current",
      :application_name => params[:application_name],
      :config_file      => params[:goapp_application_settings][:config_file],
      :output_file      => params[:goapp_application_settings][:output_file],
      :custom_config_path => "#{params[:deploy_to]}/current/#{params[:custom_config_path]}"
    )
    
    only_if do
      File.exists?("#{params[:deploy_to]}/current")
    end
  end

  template "/etc/logrotate.d/#{params[:application_name]}" do
    source   'logrotate.erb'
    owner    params[:user]
    group    params[:group]
    mode     '0751'
    variables(
        :deploy_to        => params[:deploy_to],
        :application_name => params[:application_name]
    )
  end

  bash "set up go application to use ports 80 and 443" do
    user "root"
    cwd "/tmp"
    code <<-EOH
      setcap 'cap_net_bind_service=+ep' #{params[:deploy_to]}/current/bin/goapp_#{params[:application_name]}_server
    EOH
  end
  
  template "#{params[:monit_conf_dir]}/goapp_#{params[:application_name]}_server.monitrc" do
    source  'goapp_server.monitrc.erb'
    owner   'root'
    group   'root'
    mode    '0644'
    variables(
      :deploy_to        => params[:deploy_to],
      :application_name => params[:application_name],
      :release_path     => "#{params[:deploy_to]}/current",
      :port             => params[:env_vars]['PORT'],
      :test_url         => params[:test_url]
    )
    
    only_if do
      File.exists?("#{params[:deploy_to]}/current")
    end

    notifies :restart, resources(:service => 'monit'), :immediately
  end
end
