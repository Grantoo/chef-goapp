
node[:deploy].each do |application, _|
  is_goapp = node[:deploy][application][:application_type] == 'goapp'
  instance_is_proper_layer = node[:deploy][application][:layers] && node[:deploy][application][:layers].any? {|app_layer| node[:opsworks][:instance][:layers].include?(app_layer)}
  if  !is_goapp || !instance_is_proper_layer
          Chef::Log.debug("Skipping goapp::deploy for application #{application} as it is not set as a goapp app for #{application} - restricted to layers: #{node[:deploy][application][:layers] || '<any>'}")
    next
  end

  goapp_deploy_dir do
    user    node[:deploy][application][:user]
    group   node[:deploy][application][:group]
    path    node[:deploy][application][:deploy_to]
  end

  goapp_scm do
    deploy_data   node[:deploy][application]
    app           application
    go_get?       node[:goapp][application][:auto_go_get_on_deploy]
    go_build?     node[:goapp][application][:auto_go_build_on_deploy]
    gopath        "#{node[:deploy][application][:deploy_to]}/current/build"
  end

  revision = (node[:deploy][application][:scm][:revision] rescue nil)
  config = (node[:goapp][application][:config] or {})
  goapp_deploy_config_and_monit do
    application_name             application
    revision                     revision
    hostname                     node[:hostname]
    basicauth_users              node[:goapp][application][:basicauth_users]
    goapp_application_settings   node[:goapp][application]
    deploy_to                    node[:deploy][application][:deploy_to]
    env_vars                     node[:goapp][application][:env]
    config_vars                  config
    config_file                  node[:goapp][application][:config_file]
    custom_config_path           node[:deploy][application][:custom_config_path]
    monit_conf_dir               node[:monit][:conf_dir]
    group                        node[:deploy][application][:group]
    user                         node[:deploy][application][:user]
    test_url                     node[:deploy][application][:test_url]
  end

  ruby_block "restart goapp application #{application}" do
    block do
      Chef::Log.info("restart goapp app server via: #{node[:goapp][application][:restart_server_command]}")
      Chef::Log.info(`#{node[:goapp][application][:restart_server_command]}`)
      $? == 0
    end
  end
end
