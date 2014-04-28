#
# Cookbook Name:: bcpc
# Recipe:: opencontrail-head
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

# Install some of Ubuntu packaged dependencies for ifmap-server
%w{libcommons-codec-java
   libhttpcore-java
   liblog4j1.2-java}.each do |pkg|
    package "#{pkg}" do
        action :upgrade
    end
end

# Install some of Ubuntu packaged dependencies for opencontrail-config
%w{libzookeeper-mt2 
   python-kombu
   python-zope.interface
   python-lxml
   python-gevent
   python-netaddr
   python-netifaces
   python-psutil}.each do |pkg|
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
   opencontrail}.each do |pkg|
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
   opencontrail-config}.each do |pkg|
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
    notifies :restart, "service[ifmap-server]", :immediately
end

template "/etc/opencontrail/discovery.conf" do
    source "opencontrail-discovery.conf.erb"
    owner "opencontrail"
    group "opencontrail"
    mode 00644
    variables( :servers => get_head_nodes )
    notifies :restart, "service[opencontrail-discovery]", :immediately
end

template "/etc/opencontrail/contrail-api.conf" do
    source "opencontrail-api.conf.erb"
    owner "opencontrail"
    group "opencontrail"
    mode 00640
    variables( :servers => get_head_nodes )
    notifies :restart, "service[opencontrail-api]", :immediately
end

template "/etc/opencontrail/contrail-schema.conf" do
    source "opencontrail-schema.conf.erb"
    owner "opencontrail"
    group "opencontrail"
    mode 00640
    variables( :servers => get_head_nodes )
    notifies :restart, "service[opencontrail-schema]", :immediately
end

%w{ifmap-server
   opencontrail-discovery
   opencontrail-api
   opencontrail-schema}.each do |pkg|
    service "#{pkg}" do
        action [ :enable, :start ]
    end
end
