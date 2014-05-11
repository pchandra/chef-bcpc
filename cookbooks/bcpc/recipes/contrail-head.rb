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

include_recipe "bcpc::default"

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

# Install some of Ubuntu packaged dependencies for ifmap-server
%w{libcommons-codec-java
   libhttpcore-java
   liblog4j1.2-java}.each do |pkg|
    package "#{pkg}" do
        action :upgrade
    end
end

# Install some of Ubuntu packaged dependencies for contrail
%w{libzookeeper-mt2
   python-kombu
   python-zope.interface
   python-lxml
   python-gevent
   python-netaddr
   python-netifaces
   python-psutil
   python-paramiko
   python-crypto
   python-redis}.each do |pkg|
    package "#{pkg}" do
        action :upgrade
    end
end

# Install python dependencies that we package ourselves
%w{backports.ssl_match_hostname
   bitarray
   bottle
   certifi
   geventhttpclient
   kazoo
   ncclient
   thrift
   pycassa
   requests
   stevedore
   xmltodict
   zc
   redis
   contrail}.each do |pkg|
    cookbook_file "/tmp/python-#{pkg}.deb" do
        source "bins/python-#{pkg}.deb"
        owner "root"
        mode 00444
    end
    package "python-#{pkg}" do
        provider Chef::Provider::Package::Dpkg
        source "/tmp/python-#{pkg}.deb"
        action :install
    end
end

# Install the package to fix-up python-zookeeper dependencies
cookbook_file "/tmp/bcpc-dependency-fix.deb" do
    source "bins/bcpc-dependency-fix.deb"
    owner "root"
    mode 00444
end
package "bcpc-dependency-fix" do
    provider Chef::Provider::Package::Dpkg
    source "/tmp/bcpc-dependency-fix.deb"
    action :install
end

%w{ifmap-python-client
   ifmap-server
   contrail-lib
   contrail-config
   contrail-config-openstack
   contrail-analytics
   contrail-control}.each do |pkg|
    cookbook_file "/tmp/#{pkg}.deb" do
        source "bins/#{pkg}.deb"
        owner "root"
        mode 00444
    end
    package "#{pkg}" do
        provider Chef::Provider::Package::Dpkg
        source "/tmp/#{pkg}.deb"
        action :install
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
    variables( :servers => get_head_nodes )
    notifies :restart, "service[ifmap-server]", :immediately
end

template "/etc/contrail/discovery.conf" do
    source "contrail-discovery.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00644
    variables( :servers => get_head_nodes )
    notifies :restart, "service[contrail-discovery]", :immediately
end

template "/etc/contrail/contrail-api.conf" do
    source "contrail-api.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables( :servers => get_head_nodes )
    notifies :restart, "service[contrail-api]", :immediately
end

template "/etc/contrail/contrail-schema.conf" do
    source "contrail-schema.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables( :servers => get_head_nodes )
    notifies :restart, "service[contrail-schema]", :immediately
end

template "/etc/contrail/svc-monitor.conf" do
    source "contrail-svc-monitor.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables( :servers => get_head_nodes )
    notifies :restart, "service[contrail-svc-monitor]", :immediately
end

template "/etc/contrail/svc-monitor.conf" do
    source "contrail-svc-monitor.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables( :servers => get_head_nodes )
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
        variables( :servers => get_head_nodes )
        notifies :restart, "service[#{pkg}]", :immediately
    end
end

template "/etc/contrail/control-node.conf" do
    source "contrail-control-node.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables( :servers => get_head_nodes )
    notifies :restart, "service[contrail-control]", :immediately
end

template "/etc/contrail/dns.conf" do
    source "contrail-dns.conf.erb"
    owner "contrail"
    group "contrail"
    mode 00640
    variables( :servers => get_head_nodes )
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
    service "#{pkg}" do
        action [ :enable, :start ]
    end
end

include_recipe "bcpc::contrail-work"
