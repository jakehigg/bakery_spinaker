#!/usr/bin/env bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PACKER_VERSION=0.12.2

# Fixes current Oracle Ubuntu hostname bug

echo $(hostname -I | cut -d\  -f1) $(hostname) | tee -a /etc/hosts

function install_packer() {
    mkdir -p /tmp/packer
    pushd /tmp/packer
    curl -s -L -O https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
    unzip -u -o -q packer_${PACKER_VERSION}_linux_amd64.zip -d /usr/bin
    popd
    rm -rf /tmp/packer
}

function install_redis () {
    apt-get install -y redis-server
}

apt-get update
sleep 30

# Python 2 doesn't exist on Ubuntu 16 but is needed by Spinnaker

apt-get install -y python-simplejson

# Install Redis
# ==================================================
install_redis

# Install Spinnaker
# ==================================================
echo "deb https://dl.bintray.com/spinnaker/debians trusty spinnaker" > \
     /etc/apt/sources.list.d/spinnaker.list

curl -s -f "https://bintray.com/user/downloadSubjectPublicKey?username=spinnaker" | apt-key add -

add-apt-repository -y ppa:openjdk-r/ppa
apt-get update
apt-get install -y \
        openjdk-8-jdk \
        spinnaker-clouddriver \
        spinnaker-deck \
        spinnaker-echo \
        spinnaker-front50 \
        spinnaker-gate \
        spinnaker-igor \
        spinnaker-orca \
        spinnaker-rosco \
        spinnaker \
        unzip

# Spinnaker init scripts
# ==================================================
for service in front50 fiat clouddriver echo gate igor orca rosco; do
    tee /lib/systemd/system/${service}.service <<EOF >/dev/null
[Unit]
Description=${service}

[Service]
Type=simple
User=spinnaker
Group=spinnaker
ExecStart=/opt/${service}/bin/${service}

[Install]
WantedBy=multi-user.target
EOF
done

# Configure Apache
# ==================================================
echo "Listen 0.0.0.0:9000" >> /etc/apache2/ports.conf
sed -i 's#VirtualHost 127.0.0.1:9000#VirtualHost 0.0.0.0:9000#g' /etc/apache2/sites-enabled/spinnaker.conf
service apache2 restart

# Install Packer
# ==================================================
install_packer

# Start and enable services
# ==================================================
for i in front50 fiat clouddriver echo gate igor orca rosco
do
    systemctl enable $i
    systemctl start $i
done