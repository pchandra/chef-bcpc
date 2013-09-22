#
# Cookbook Name:: bcpc
# Recipe:: anycast
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

include_recipe "bcpc::default"

ruby_block "initialize-anycast-config" do
    block do
        make_config('quagga-bgpd-password', secure_password)
        make_config('quagga-zebra-password', secure_password)
    end
end

package "quagga" do
	action :upgrade
end

template "/etc/network/interfaces.d/iface-lo:0" do
    source "network.anycast.erb"
    owner "root"
    group "root"
    mode 00644
end

bash "anycast-interface-up" do
    user "root"
    code <<-EOH
        ifup lo:0
    EOH
    not_if "ip addr show | grep lo:0"
end

template "/etc/quagga/daemons" do
    source "quagga-daemons.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[quagga]", :delayed
end

template "/etc/quagga/zebra.conf" do
    source "quagga-zebra.conf.erb"
    owner "root"
    group "root"
    mode 00644
    variables( :servers => get_head_nodes )
    notifies :restart, "service[quagga]", :delayed
end

template "/etc/quagga/bgpd.conf" do
    source "quagga-bgpd.conf.erb"
    owner "root"
    group "root"
    mode 00644
    variables( :servers => get_head_nodes )
    notifies :restart, "service[quagga]", :immediately
end

service "quagga" do
    action [ :enable, :start ]
end
