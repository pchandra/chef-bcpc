#
# Cookbook Name:: bcpc
# Recipe:: scalr
#
# Copyright 2013, Bloomberg L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "bcpc::mysql"
include_recipe "bcpc::horizon"

ruby_block "initialize-scalr-config" do
    block do
        make_config('mysql-scalr-user', "scalr")
        make_config('mysql-scalr-password', secure_password)
        make_config('mysql-phpmyadmin-password', secure_password)
        make_config('scalr-admin-password', secure_password)
        make_config('scalr-id', 8.times.map{((0..9).to_a + ('a'..'f').to_a)[rand(16)].to_s}.join)
    end
end

%w{apache2-mpm-prefork php5 php5-mysql php5-curl php5-mcrypt php5-snmp libssh2-php apparmor-utils php-pear rrdtool librrd-dev libcurl4-openssl-dev snmp debconf-utils}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

cookbook_file "/tmp/scalr.tgz" do
    source "bins/scalr.tgz"
    owner "root"
    mode 00444
end

user node[:bcpc][:scalr][:user] do
    shell "/bin/false"
    home "/opt/scalr"
    gid node[:bcpc][:scalr][:group]
    system true
end

bash "install-scalr-server" do
    code <<-EOH
        tar zxf /tmp/scalr.tgz -C /opt/
        chown -R #{node[:bcpc][:scalr][:user]}:#{node[:bcpc][:scalr][:group]} /opt/scalr
        chmod -R 2755 /opt/scalr
    EOH
    not_if "test -d /opt/scalr"
end

template "/opt/scalr/app/etc/id" do
    source "scalr-id.erb"
    owner node[:bcpc][:scalr][:user]
    group node[:bcpc][:scalr][:group]
    mode 00644
end

directory "/opt/scalr/app/cache" do
    owner node[:bcpc][:scalr][:user]
    group node[:bcpc][:scalr][:group]
    mode 02775
end

%w{graphics log app/rrd app/rrd/x1x6 app/rrd/x2x7 app/rrd/x3x8 app/rrd/x4x9 app/rrd/x5x0}.each do |dir|
    directory "/opt/scalr/#{dir}" do
        owner node[:bcpc][:scalr][:user]
        group node[:bcpc][:scalr][:group]
        mode 0755
    end
end

template "/opt/scalr/app/etc/config.yml" do
    source "scalr-config.yml.erb"
    owner node[:bcpc][:scalr][:user]
    group node[:bcpc][:scalr][:group]
    mode 0640
end

ruby_block "scalr-database-creation" do
    block do
        if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['scalr_dbname']}\"'|grep \"#{node['bcpc']['scalr_dbname']}\"" then
            puts %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['scalr_dbname']} CHARACTER SET UTF8;"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['scalr_dbname']}.* TO '#{get_config('mysql-scalr-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-scalr-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['scalr_dbname']}.* TO '#{get_config('mysql-scalr-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-scalr-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
                mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['scalr_dbname']} < /opt/scalr/sql/structure.sql
                mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['scalr_dbname']} < /opt/scalr/sql/data.sql
                HASH=`echo -n "#{get_config('scalr-admin-password')}" | sha256sum | awk '{print $1}'`
                mysql -uroot -p#{get_config('mysql-root-password')} #{node['bcpc']['scalr_dbname']} -e "UPDATE account_users SET password=\\"$HASH\\" WHERE email=\\"admin\\";"
            ]
        end
    end
end

bash "install-scalr-python" do
    code <<-EOH
        cd /opt/scalr/app/python
        python setup.py install
        touch setup.py.installed
    EOH
    not_if "test -f /opt/scalr/app/python/setup.py.installed"
end

%w{rrd http yaml}.each do |pkg|
    cookbook_file "/tmp/pecl-#{pkg}.tgz" do
        source "bins/pecl-#{pkg}.tgz"
        owner "root"
        mode 00444
    end
    bash "pecl-install-#{pkg}" do
        user "root"
        code <<-EOH
            printf '\n\n\n\n' | pecl install /tmp/pecl-#{pkg}.tgz
        EOH
        not_if "pecl list | grep #{pkg}"
    end
    file "/etc/php5/apache2/conf.d/#{pkg}.ini" do
        owner "root"
        content "extension=#{pkg}.so"
        notifies :restart, "service[apache2]", :delayed
    end
end

bash "apache-enable-rewrite" do
    user "root"
    code <<-EOH
        a2enmod rewrite
    EOH
    not_if "test -r /etc/apache2/mods-enabled/rewrite.load"
    notifies :restart, "service[apache2]", :delayed
end

template "/etc/apache2/conf.d/scalr.conf" do
    source "apache-scalr.conf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[apache2]", :delayed
end

template "/etc/cron.d/scalr" do
    source "cron-scalr.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[cron]", :delayed
end

package "bind9" do
    action :upgrade
end

bash "postfix-debconf-setup" do
    user "root"
    code <<-EOH
        echo 'postfix postfix/main_mailer_type        select  Local only' | debconf-set-selections
    EOH
    not_if "debconf-get-selections | grep postfix"
end

package "mailutils" do
    action :upgrade
end
