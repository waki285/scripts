#!/bin/bash

# root check
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." 1>&2
    exit 1
fi

for cmd in wget tar; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd command is required." 1>&2
        exit 1
    fi
done

latest_version=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
version=${latest_version#v}

# architecture check
arch=$(uname -m)
case $arch in
    amd64|x86_64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *)
        echo "Unsupported architecture: $arch" 1>&2
        exit 1
        ;;
esac

# Download and install
download_url="https://github.com/prometheus/node_exporter/releases/download/${latest_version}/node_exporter-${version}.linux-${arch}.tar.gz"
wget $download_url -O node_exporter.tar.gz
tar xvfz node_exporter.tar.gz
mkdir -p /srv/node_exporter
mv node_exporter-${version}.linux-${arch}/node_exporter /srv/node_exporter/

# create user
useradd -M -U exporter
chown -R exporter:exporter /srv/node_exporter

# create service
cat << EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter Server
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target

[Service]
User=exporter
Group=exporter
Restart=on-failure
ExecStart=/srv/node_exporter/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# start service
systemctl enable node_exporter
systemctl start node_exporter

echo "Node Exporter has been installed successfully."

# Clean up
rm -rf node_exporter.tar.gz node_exporter-${version}.linux-${arch}

