#!/bin/bash -e

set -x

# Define the appropriate version of each binary to grab/build
VER_KIBANA=2581d314f12f520638382d23ffc03977f481c1e4
# newer versions of Diamond depend upon dh-python which isn't in precise/12.04
VER_DIAMOND=f33aa2f75c6ea2dfbbc659766fe581e5bfe2476d
VER_ESPLUGIN=9c032b7c628d8da7745fbb1939dcd2db52629943

if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi


# we now define CURL previously in proxy_setup.sh (called from
# setup_chef_server which calls this script. Default definition is
# CURL=curl
if [ -z "$CURL" ]; then
  CURL=curl
fi

DIR=`dirname $0`

mkdir -p $DIR/bins
pushd $DIR/bins/

# Install tools needed for packaging
apt-get -y install git \
                   rubygems \
                   make \
                   pbuilder \
                   python-mock \
                   python-configobj \
                   python-support \
                   cdbs \
                   python-all-dev \
                   python-stdeb \
                   libmysqlclient-dev \
                   libldap2-dev \
                   scons \
                   wget \
                   patch \
                   unzip \
                   flex \
                   bison \
                   gcc \
                   g++ \
                   libssl-dev \
                   autoconf \
                   automake \
                   libtool \
                   pkg-config \
                   vim \
                   python-setuptools \
                   python-lxml \
                   quilt \
                   openjdk-6-jdk \
                   javahelper \
                   ant \
                   libhttpcore-java \
                   liblog4j1.2-java \
                   libcommons-codec-java
if [ -z `gem list --local fpm | grep fpm | cut -f1 -d" "` ]; then
  gem install fpm --no-ri --no-rdoc
fi

# Fetch chef client and server debs
CHEF_CLIENT_URL=https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef_10.32.2-1_amd64.deb
#CHEF_CLIENT_URL=https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef_11.10.4-1.ubuntu.12.04_amd64.deb
CHEF_SERVER_URL=https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef-server_11.0.12-1.ubuntu.12.04_amd64.deb
if [ ! -f chef-client.deb ]; then
   $CURL -o chef-client.deb ${CHEF_CLIENT_URL}
fi

if [ ! -f chef-server.deb ]; then
   $CURL -o chef-server.deb ${CHEF_SERVER_URL}
fi
FILES="chef-client.deb chef-server.deb $FILES"

# Build kibana3 installable bundle
if [ ! -f kibana3.tgz ]; then
    git clone https://github.com/elasticsearch/kibana.git kibana3
    cd kibana3/src
    git archive --output ../../kibana3.tgz --prefix kibana3/ $VER_KIBANA
    cd ../..
    rm -rf kibana3
fi
FILES="kibana3.tgz $FILES"

# any pegged gem versions
REV_elasticsearch="0.2.0"

# Grab plugins for fluentd
for i in elasticsearch tail-multiline tail-ex record-reformer rewrite; do
    if [ ! -f fluent-plugin-${i}.gem ]; then
        PEG=REV_${i}
        if [[ ! -z ${!PEG} ]]; then
            VERS="-v ${!PEG}"
        else
            VERS=""
        fi
        gem fetch fluent-plugin-${i} ${VERS}
        mv fluent-plugin-${i}-*.gem fluent-plugin-${i}.gem
    fi
    FILES="fluent-plugin-${i}.gem $FILES"
done

# Fetch the cirros image for testing
if [ ! -f cirros-0.3.2-x86_64-disk.img ]; then
    $CURL -O -L http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
fi
FILES="cirros-0.3.2-x86_64-disk.img $FILES"

# Grab the Ubuntu 12.04 installer image
if [ ! -f ubuntu-12.04-mini.iso ]; then
    # Download this ISO to get the latest kernel/X LTS stack installer
    #$CURL -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise-updates/main/installer-amd64/current/images/raring-netboot/mini.iso
    $CURL -o ubuntu-12.04-mini.iso http://archive.ubuntu.com/ubuntu/dists/precise/main/installer-amd64/current/images/netboot/mini.iso
fi
FILES="ubuntu-12.04-mini.iso $FILES"

# Grab the CentOS 6 PXE boot images
if [ ! -f centos-6-initrd.img ]; then
    #$CURL -o centos-6-mini.iso http://mirror.net.cen.ct.gov/centos/6/isos/x86_64/CentOS-6.4-x86_64-netinstall.iso
    $CURL -o centos-6-initrd.img http://mirror.net.cen.ct.gov/centos/6/os/x86_64/images/pxeboot/initrd.img
fi
FILES="centos-6-initrd.img $FILES"

if [ ! -f centos-6-vmlinuz ]; then
    $CURL -o centos-6-vmlinuz http://mirror.net.cen.ct.gov/centos/6/os/x86_64/images/pxeboot/vmlinuz
fi
FILES="centos-6-vmlinuz $FILES"

# Make the diamond package
if [ ! -f diamond.deb ]; then
    git clone https://github.com/BrightcoveOS/Diamond.git
    cd Diamond
    git checkout $VER_DIAMOND
    make builddeb
    VERSION=`cat version.txt`
    cd ..
    mv Diamond/build/diamond_${VERSION}_all.deb diamond.deb
    rm -rf Diamond
fi
FILES="diamond.deb $FILES"

# Snag elasticsearch
ES_VER=1.1.1
if [ ! -f elasticsearch-${ES_VER}.deb ]; then
    $CURL -O -L https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${ES_VER}.deb
fi
if [ ! -f elasticsearch-${ES_VER}.deb.sha1.txt ]; then
    $CURL -O -L https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${ES_VER}.deb.sha1.txt
fi
if [[ `shasum elasticsearch-${ES_VER}.deb` != `cat elasticsearch-${ES_VER}.deb.sha1.txt` ]]; then
    echo "SHA mismatch detected for elasticsearch ${ES_VER}!"
    echo "Have: `shasum elasticsearch-${ES_VER}.deb`"
    echo "Expected: `cat elasticsearch-${ES_VER}.deb.sha1.txt`"
    exit 1
fi

FILES="elasticsearch-${ES_VER}.deb elasticsearch-${ES_VER}.deb.sha1.txt $FILES"

if [ ! -f elasticsearch-plugins.tgz ]; then
    git clone https://github.com/mobz/elasticsearch-head.git
    cd elasticsearch-head
    git archive --output ../elasticsearch-plugins.tgz --prefix head/_site/ $VER_ESPLUGIN
    cd ..
    rm -rf elasticsearch-head
fi
FILES="elasticsearch-plugins.tgz $FILES"

# Fetch pyrabbit
if [ ! -f pyrabbit-1.0.1.tar.gz ]; then
    $CURL -O -L https://pypi.python.org/packages/source/p/pyrabbit/pyrabbit-1.0.1.tar.gz
fi
FILES="pyrabbit-1.0.1.tar.gz $FILES"

# Build graphite packages
if [ ! -f python-carbon_0.9.12_all.deb ] || [ ! -f python-whisper_0.9.12_all.deb ] || [ ! -f python-graphite-web_0.9.12_all.deb ]; then
    $CURL -L -O http://pypi.python.org/packages/source/c/carbon/carbon-0.9.12.tar.gz
    $CURL -L -O http://pypi.python.org/packages/source/w/whisper/whisper-0.9.12.tar.gz
    $CURL -L -O http://pypi.python.org/packages/source/g/graphite-web/graphite-web-0.9.12.tar.gz
    tar zxf carbon-0.9.12.tar.gz
    tar zxf whisper-0.9.12.tar.gz
    tar zxf graphite-web-0.9.12.tar.gz
    fpm --python-install-bin /opt/graphite/bin -s python -t deb carbon-0.9.12/setup.py
    fpm --python-install-bin /opt/graphite/bin  -s python -t deb whisper-0.9.12/setup.py
    fpm --python-install-lib /opt/graphite/webapp -s python -t deb graphite-web-0.9.12/setup.py
    rm -rf carbon-0.9.12 carbon-0.9.12.tar.gz whisper-0.9.12 whisper-0.9.12.tar.gz graphite-web-0.9.12 graphite-web-0.9.12.tar.gz
fi
FILES="python-carbon_0.9.12_all.deb python-whisper_0.9.12_all.deb python-graphite-web_0.9.12_all.deb $FILES"

# Build the zabbix packages
if [ ! -f zabbix-agent.tar.gz ] || [ ! -f zabbix-server.tar.gz ]; then
    $CURL -L -O http://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/2.2.2/zabbix-2.2.2.tar.gz
    tar zxf zabbix-2.2.2.tar.gz
    rm -rf /tmp/zabbix-install && mkdir -p /tmp/zabbix-install
    cd zabbix-2.2.2
    ./configure --prefix=/tmp/zabbix-install --enable-agent --with-ldap
    make install
    tar zcf zabbix-agent.tar.gz -C /tmp/zabbix-install .
    rm -rf /tmp/zabbix-install && mkdir -p /tmp/zabbix-install
    ./configure --prefix=/tmp/zabbix-install --enable-server --with-mysql --with-ldap
    make install
    cp -a frontends/php /tmp/zabbix-install/share/zabbix/
    cp database/mysql/* /tmp/zabbix-install/share/zabbix/
    tar zcf zabbix-server.tar.gz -C /tmp/zabbix-install .
    rm -rf /tmp/zabbix-install
    cd ..
    cp zabbix-2.2.2/zabbix-agent.tar.gz .
    cp zabbix-2.2.2/zabbix-server.tar.gz .
    rm -rf zabbix-2.2.2 zabbix-2.2.2.tar.gz
fi
FILES="zabbix-agent.tar.gz zabbix-server.tar.gz $FILES"

# Build the packages for installing OpenContrail
if [ ! -f opencontrail-*.deb ]; then
    rm -rf contrail && mkdir -p contrail
    cd contrail
    # Get the git-repo extension to git
    $CURL -L -O http://commondatastorage.googleapis.com/git-repo-downloads/repo
    chmod +x repo
    # Permanently add the github host key to avoid failures on checkout
    ssh -o 'StrictHostKeyChecking no' github.com || true
    # Get the meta-repo and then pull all the source
    ./repo init -u git@github.com:Juniper/contrail-vnc < /dev/null
    ./repo sync
    # Fetch build dependencies for OpenContrail
    python third_party/fetch_packages.py
    # Now build the debian packages
    make -f packages.make
    cd build/packages
    for i in *.deb; do
        BASE=${i/_*/}
        mv $i ${BASE}.deb
    done
    cp *.deb ../../../
    cd ../../../
    rm -rf contrail
fi

# Build the neutron packages that have the opencontrail plugin
if [ ! -f neutron-*.deb ]; then
    rm -rf neutron
    git clone -b packages https://github.com/pchandra/neutron
    cd neutron
    python setup.py --command-packages=stdeb.command sdist_dsc
    rm -rf deb_dist/neutron-2013.2/debian
    cp -R debian deb_dist/neutron-2013.2/
    cd deb_dist/neutron-2013.2/
    fakeroot debian/rules binary
    cd ..
    for i in *.deb; do
        BASE=${i/_*/}
        mv $i ${BASE}.deb
    done
    cp *.deb ../../
    cd ../../
    rm -rf neutron
fi

# Build a bunch of python debs that are OpenContrail dependencies
for i in https://pypi.python.org/packages/source/b/backports.ssl_match_hostname/backports.ssl_match_hostname-3.4.0.2.tar.gz \
         https://pypi.python.org/packages/source/b/bitarray/bitarray-0.8.0.tar.gz \
         https://pypi.python.org/packages/source/b/bottle/bottle-0.12.5.tar.gz \
         https://pypi.python.org/packages/source/c/certifi/certifi-1.0.1.tar.gz \
         https://pypi.python.org/packages/source/g/geventhttpclient/geventhttpclient-1.0a.tar.gz \
         https://pypi.python.org/packages/source/k/kazoo/kazoo-1.3.1.zip \
         https://pypi.python.org/packages/source/n/ncclient/ncclient-0.4.1.tar.gz \
         https://pypi.python.org/packages/source/p/pycassa/pycassa-1.11.0.tar.gz \
         https://pypi.python.org/packages/source/r/requests/requests-2.2.1.tar.gz \
         https://pypi.python.org/packages/source/s/stevedore/stevedore-0.15.tar.gz \
         https://pypi.python.org/packages/source/t/thrift/thrift-0.9.1.tar.gz \
         https://pypi.python.org/packages/source/x/xmltodict/xmltodict-0.9.0.tar.gz; do
    # Setup some variables and assume it's a tarball unless it ends in .zip
    UNCOMPRESS="tar zxf"
    if [[ $i == *.zip ]]; then UNCOMPRESS="unzip"; fi
    FILE=`basename $i`
    BASE=${FILE/-*/}
    if [ ! -f python-${BASE}.deb ]; then
        # Grab the file and uncompress it
        $CURL -L -O $i
        $UNCOMPRESS $FILE
        cd ${BASE}*
        touch README.md
        rm -rf debian
        python setup.py --command-packages=stdeb.command bdist_deb
        cp deb_dist/python-*.deb ../python-${BASE}.deb
        cd ..
        rm -rf ${BASE}*
    fi
done

# Get some python libs 
if [ ! -f python-requests-aws_0.1.5_all.deb ]; then
    $CURL -L -O http://pypi.python.org/packages/source/r/requests-aws/requests-aws-0.1.5.tar.gz
    tar zxf requests-aws-0.1.5.tar.gz
    fpm -s python -t deb requests-aws
    rm -rf requests-aws-0.1.5 requests-aws-0.1.5.tar.gz
fi
FILES="python-requests-aws_0.1.5_all.deb $FILES"


popd
