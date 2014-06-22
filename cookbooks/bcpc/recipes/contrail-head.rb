#
# Cookbook Name:: bcpc
# Recipe:: contrail-head
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

include_recipe "bcpc::contrail-common"

ruby_block "initialize-contrail-config" do
    block do
        make_config('contrail-api-passwd', secure_password)
        make_config('contrail-schema-passwd', secure_password)
        make_config('contrail-svc-monitor-passwd', secure_password)
        make_config('contrail-control-passwd', secure_password)
        make_config('contrail-dns-passwd', secure_password)
        make_config('contrail-metadata-secret', secure_password)
    end
end

%w{ifmap-server
   contrail-config
   contrail-config-openstack
   contrail-analytics
   contrail-control
   contrail-utils}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

template "/etc/ifmap-server/ifmap.properties" do
    source "ifmap.properties.erb"
    mode 00644
    notifies :restart, "service[ifmap-server]", :delayed
end

template "/etc/ifmap-server/basicauthusers.properties" do
    source "ifmap-basicauthusers.properties.erb"
    mode 00644
    variables(:servers => get_head_nodes)
    notifies :restart, "service[ifmap-server]", :immediately
end

template "/etc/contrail/discovery.conf" do
    source "contrail-discovery.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00644
    variables(:servers => get_head_nodes)
    notifies :restart, "service[contrail-discovery]", :immediately
end

template "/etc/contrail/contrail-api.conf" do
    source "contrail-api.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables(:servers => get_head_nodes)
    notifies :restart, "service[contrail-api]", :immediately
end

template "/etc/contrail/contrail-schema.conf" do
    source "contrail-schema.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables(:servers => get_head_nodes)
    notifies :restart, "service[contrail-schema]", :immediately
end

template "/etc/contrail/svc-monitor.conf" do
    source "contrail-svc-monitor.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables(:servers => get_head_nodes)
    notifies :restart, "service[contrail-svc-monitor]", :immediately
end

%w{contrail-analytics-api
   contrail-collector
   contrail-query-engine}.each do |pkg|
    template "/etc/contrail/#{pkg}.conf" do
        source "#{pkg}.conf.erb"
        owner "contrail"
        group "contrail"
        mode 00640
        variables(:servers => get_head_nodes)
        notifies :restart, "service[#{pkg}]", :immediately
    end
end

template "/etc/contrail/control-node.conf" do
    source "contrail-control-node.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    notifies :restart, "service[contrail-control]", :immediately
end

template "/etc/contrail/dns.conf" do
    source "contrail-dns.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    notifies :restart, "service[contrail-dns]", :immediately
end

%w{ifmap-server
   contrail-discovery
   contrail-api
   contrail-schema
   contrail-svc-monitor
   contrail-analytics-api
   contrail-collector
   contrail-query-engine
   contrail-control
   contrail-dns}.each do |pkg|
    service pkg do
        action [:enable, :start]
    end
end

include_recipe "bcpc::contrail-work"
