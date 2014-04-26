#
# Cookbook Name:: bcpc
# Recipe:: redis
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

apt_repository "redis" do
    uri node['bcpc']['repos']['redis']
    distribution node['lsb']['codename']
    components ["main"]
    key "redis.key"
end

package "redis-server" do
    action :upgrade
end

template "/etc/redis/redis.conf" do
    source "redis.conf.erb"
    mode 00640
    owner "redis"
    group "redis"
    variables( :port => 6379,
               :count => "" )
    notifies :restart, "service[redis-server]", :immediately
end

# Use one layer of indirection for this file since the process
# will rewrite it with current state (and we don't want each)
# chef-client run to blow it away back to the original unless
# there was some meaningful change
template "/etc/redis/redis-sentinel.conf.chef" do
    source "redis-sentinel.conf.erb"
    mode 00640
    owner "redis"
    group "redis"
    variables( :servers => get_head_nodes,
               :min_quorum => get_head_nodes.length/2 + 1 )
    notifies :restart, "service[redis-sentinel]", :delayed
    notifies :run, "bash[install-chef-sentinel-conf]", :immediately
end

bash "install-chef-sentinel-conf" do
    action :nothing
    user "root"
    code <<-EOH
        cp -f /etc/redis/redis-sentinel.conf.chef /etc/redis/redis-sentinel.conf
        chown redis:redis /etc/redis/redis-sentinel.conf
    EOH
end

template "/etc/init.d/redis-sentinel" do
    source "init.d-redis-sentinel.erb"
    mode 00755
    notifies :restart, "service[redis-sentinel]", :immediately
end

service "redis-server" do
    action [ :enable, :start ]
end

service "redis-sentinel" do
    action [ :enable, :start ]
end

# For HA, we'll run additional redis-servers in slave mode so that the
# sentinel processes can agree to shuffle the slave to where they are
# needed (or promote them to masters) in the event of failures.
# For this to work in the event of network partitions, we'll need
# N/2+1 total depth for each redis partition, which means one master 
# and N/2 slaves. To do this, we get each headnode's redis slaves to slave
# to N/2 machines to the 'right' of themselves (wrapping around the Array
# if needed).
ips = get_head_nodes.collect{|x| x['bcpc']['management']['ip']}.sort
offset = ips.index(node['bcpc']['management']['ip']) || 0
(ips.length/2).times do |count|
    template "/etc/redis/redis#{count+2}.conf" do
        source "redis.conf.erb"
        mode 00640
        owner "redis"
        group "redis"
        variables( :port => 6379+count+1,
                   :count => "#{count+2}",
                   :slave => ips[(offset+count+1)%ips.length] )
        notifies :restart, "service[redis-server#{count+2}]", :delayed
    end
    template "/etc/init.d/redis-server#{count+2}" do
        source "init.d-redis-server.erb"
        mode 00755
        variables( :count => "#{count+2}" )
        notifies :restart, "service[redis-server#{count+2}]", :immediately
    end
    service "redis-server#{count+2}" do
        action [ :enable, :start ]
    end
end
