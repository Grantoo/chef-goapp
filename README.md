Go Webserver Cookbook for Amazon OpsWorks
===============================

We have several Go web applications that we run at http://www.crowdmob.com and wanted to be able to deploy them
using Amazon's OpsWorks http://aws.amazon.com/opsworks/ to get auto-scaling and auto-provisioning.

This is the recipe we use which we are using in production.  It `git clones` into a `releases/{NOW}` directory, builds the app (assuming your main package is defined in a go source file named `APPNAME.go`), symlinks the `current` directory to it, and tells `monit` to restart the service representing your server.

Dependencies
-----------------------------
This cookbook depends on the following:

- `golang`: the installation of go recipe at https://github.com/Grantoo/chef-golang
- `monit`: the monit package to ensure your server is running, and tries to restart it if not at https://github.com/Grantoo/chef-monit

Additionally, you must use `Godep` for storing code dependencies.

Only Use 64 Bit EC2 Instances
-----------------------------
At this time, the `golang` cookbook mentioned doesn't dynamically choose the right binary at runtime, based on CPU.  That means that it assumes a 64 bit ec2 instance, which is a large instance or better.

Select the `Custom` Layer Type
-----------------------------
When you make your Layer in OpsWorks, be sure to select Other > Custom, rather than "Rails App Server" or some other pre-defined stack. 

Custom Chef Recipes Setup
-----------------------------
To deploy your app, you'll have to make sure 2 of the recipes in this cookbook are run.

1. `golang::install` should run during the setup phase of your node in OpsWorks
2. `goapp::configure` should run during the configuration phase of your node in OpsWorks
3. `goapp::deploy` should run during (every) deployment phase of your node.

Databag Setup
-----------------------------
This cookbook relies on a databag which you should set in Amazon OpsWorks as your Stack's "Custom Chef JSON".

It expects that you are using the golang chef recipe listed above. So, the following example shows the
data bag that selects a version of Go. This is a fairly minimal set of parameters to be successful in deploying
a go server (web app for example):

```json
{
  "go": {
    "version": "1.4"
  },
  "deploy": {
    "YOUR_APPLICATION_SHORT_NAME": {
      "application_type": "goapp",
      "goapp": "ApiV2Server",
      "gofile": "main.go",
      "test_url": "/",
      "auto_go_get_on_deploy": true,
      "auto_go_build_on_deploy": true,
      "env": {
        "APP_ENV": "production",
        "PORT": 80
        "or_whatever": "you want in YOUR_APPLICATION_NAME.properties"
      },
      "custom_config_path":"conf/staging.config.json"
      "config": ["other"]
    }
  }
  "other": {
    "option1": "value1"
  }
}
```

Important note: this cookbook double-checks that your `application_type` is set to `goapp`. If `application_type` is not set to `goapp`, none of the cookbook will run for that app.  If `gofile` is omitted, uses `APPLICATION_NAME.go`.  `test_url` will be tested by monit to ensure server is still up (default "/").

If you include a layers key, only matching layer will deploy this application.  E.g.

```json
{
  "deploy": {
    "blog": {
      "application_type": "goapp",
      "layers": ["blog-server"]
    }
  }
}
```

The `blog` app will only deploy onto the `blog-server` layer.

If you include a config key, the matching root-level values will be copied to the properties file as sections, allowing other cookbook configuration to be made available to your application. e.g.

```json
{
  "deploy": {
    "blog": {
      "config": ["wordpress"],
    }
  },
  "wordpress": {
    "database": "db.host"
  }
}
```

The resulting blog.properties file will contain the following sections:

```
[wordpress]
database=db.host
```

How it Works
-----------------------------
This cookbook builds and runs a go webapp in the following way:

- The `APPNAME.go` source file is built using `go get .` followed by `go build -o ./goapp_APPNAME_server server.go`.  That results in an executable of your application at `/srv/www/APPNAME/current/goapp_APPNAME_server`
- A `APPNAME.properties` file is created using your databag and output at `/srv/www/APPNAME/shared/config/APPNAME.properties`
- A `goapp-APPNAME-server-daemon` shell script is created and placed in  `/srv/www/APPNAME/current/`, which handles start and restart commands, by calling  `/srv/www/APPNAME/current/goapp_APPNAME_server -c /srv/www/APPNAME/shared/config/APPNAME.properties` and outputting logs to `/srv/www/APPNAME/shared/log/goapp.log`
- A `goapp_APPNAME_server.monitrc` monit script is created, which utilizes the `goapp-APPNAME-server-daemon` script for startup and shutdown, and is placed in `/etc/monit.d` or `/etc/monit/conf.d`, depending on your OS (defined in the `monit` cookbook)
- `monit` is restarted, which incorporates the the new files.



A little about `goapp`
-----------------------------
For the purposes of this cookbook, though, the only thing that it assumes about your webapp is:

1. Your `main` function is in a file called `APPNAME.go` in the base of your project. 
2. Your `APPNAME.go` program won't die if it's sent a `-c` flag at the command line with a filepath after it, like `go run server.go -c /path/to/server.properties`.  Whether or not it uses that file, however, is up to it.


License and Author
===============================
Author:: Matthew Moore, Geoff Hayes

Copyright:: 2013


Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
