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

# Install some of the required dependencies for the opencontrail-config package
%w{libzookeeper-mt2 python-kombu python-zope.interface python-lxml python-gevent python-netaddr python-netifaces python-psutil python-zookeeper}.each do |pkg|
    package "#{pkg}" do
        action :upgrade
    end
end

# Install python dependencies that we package ourselves
%w{backports.ssl_match_hostname bitarray bottle certifi geventhttpclient kazoo ncclient thrift pycassa requests stevedore xmltodict opencontrail}.each do |pkg|
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

cookbook_file "/tmp/opencontrail-config.deb" do
    source "bins/opencontrail-config.deb"
    owner "root"
    mode 00444
end

package "opencontrail-config" do
    provider Chef::Provider::Package::Dpkg
    source "/tmp/opencontrail-config.deb"
    action :install
end
