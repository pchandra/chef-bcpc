#
# Cookbook Name:: bcpc
# Recipe:: neutron-head
#
# Copyright 2013, Bloomberg Finance L.P.
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
include_recipe "bcpc::openstack"

ruby_block "initialize-neutron-config" do
    block do
        make_config('mysql-neutron-user', "neutron")
        make_config('mysql-neutron-password', secure_password)
    end
end

%w{neutron-server neutron-plugin-contrail}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

service "neutron-server" do
    action [:enable, :start]
end

bash "config-contrail-ini" do
    user "root"
    code <<-EOH
        sed --in-place '/^NEUTRON_PLUGIN_CONFIG=/d' /etc/default/neutron-server
        echo 'NEUTRON_PLUGIN_CONFIG=\"/etc/neutron/plugins/opencontrail/ContrailPlugin.ini\"' >> /etc/default/neutron-server
    EOH
    not_if "grep -e '^NEUTRON_PLUGIN_CONFIG' /etc/default/neutron-server | grep /etc/neutron/plugins/opencontrail/ContrailPlugin.ini"
    notifies :restart, "service[neutron-server]", :delayed
end

template "/etc/neutron/neutron.conf" do
    source "neutron.conf.erb"
    owner "neutron"
    group "neutron"
    mode 00600
    notifies :restart, "service[neutron-server]", :delayed
end

# Ensure neutron user can read contrail directory
directory "/etc/contrail" do
    owner "contrail"
    group "contrail"
    mode 00755
end

template "/etc/contrail/vnc_api_lib.ini" do
    source "contrail-vnc_api_lib.ini.erb"
    owner "neutron"
    group "neutron"
    mode 00644
    notifies :restart, "service[neutron-server]", :delayed
end

template "/etc/neutron/plugins/opencontrail/ContrailPlugin.ini" do
    source "contrailplugin.ini.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[neutron-server]", :immediately
end

ruby_block "neutron-database-creation" do
    block do
        if not system "mysql -uroot -p#{get_config('mysql-root-password')} -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node['bcpc']['neutron_dbname']}\"'|grep \"#{node['bcpc']['neutron_dbname']}\"" then
            %x[ mysql -uroot -p#{get_config('mysql-root-password')} -e "CREATE DATABASE #{node['bcpc']['neutron_dbname']};"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['neutron_dbname']}.* TO '#{get_config('mysql-neutron-user')}'@'%' IDENTIFIED BY '#{get_config('mysql-neutron-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "GRANT ALL ON #{node['bcpc']['neutron_dbname']}.* TO '#{get_config('mysql-neutron-user')}'@'localhost' IDENTIFIED BY '#{get_config('mysql-neutron-password')}';"
                mysql -uroot -p#{get_config('mysql-root-password')} -e "FLUSH PRIVILEGES;"
            ]
        end
    end
end
