
directory "/usr/local/bin/checks" do
  action :create
  owner "root"
  group "root"
  mode 00775
end

directory "/usr/local/etc/checks" do
  action :create
  owner "root"
  group "root"
  mode 00775
end

 template  "/usr/local/etc/checks/default.yml" do
   source "checks/default.yml.erb"
   owner "root"
   group "root"
   mode 00640
 end

 cookbook_file "/usr/local/bin/check" do
   source "checks/check"
   owner "root"
   mode "00755"
 end
