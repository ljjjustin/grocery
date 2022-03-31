#!/bin/bash

 # change working dir
 cd $(dirname $0)
 TOPDIR=$(pwd)

 # ensure user
 if ! grep -qw monitoring /etc/passwd; then
     useradd -s /sbin/nologin -M monitoring
 fi
 chown -R monitoring:monitoring $TOPDIR

 # ensure directories
 mkdir -p bin loki/data promtail prometheus/data

 # ensure binary files
 ensure_install_file() {
     local url=$1
     local md5=$2
     local file=$(basename $1)

     if [ ! -e $file ]; then
         # download binary files
 	curl -O -L $url
     fi

     #realmd5=$(md5sum $file)
     #if [ "$realmd5" != "$md5" ]; then
     #    echo "$file MD5 is wrong, exiting..."
     #    exit
     #fi
}

# install node_exporter
ensure_install_file https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz

if [ ! -e $TOPDIR/bin/node_exporter ]; then
    tar xf node_exporter-1.3.1.linux-amd64.tar.gz
    mv node_exporter-1.3.1.linux-amd64/node_exporter $TOPDIR/bin/
fi

cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=node_exporter
After=network.target

[Service]
User=monitoring
Group=monitoring
Type=simple
ExecStart=$TOPDIR/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable node_exporter
systemctl start  node_exporter
systemctl status node_exporter

# install loki

ensure_install_file https://github.com/grafana/loki/releases/download/v2.4.2/loki-linux-amd64.zip

if [ ! -e $TOPDIR/bin/loki ]; then
    unzip loki-linux-amd64.zip
    mv loki-linux-amd64 $TOPDIR/bin/loki
fi

cat > $TOPDIR/loki/loki-config.yaml << EOF
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: $TOPDIR/loki
  storage:
    filesystem:
      chunks_directory: $TOPDIR/loki/chunks
      rules_directory: $TOPDIR/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h
EOF

cat > /etc/systemd/system/loki.service << EOF
[Unit]
Description=loki
After=network.target

[Service]
User=monitoring
Group=monitoring
Type=simple
ExecStart=$TOPDIR/bin/loki --config.file=$TOPDIR/loki/loki-config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable loki
systemctl start  loki
systemctl status loki


# install promtail
ensure_install_file https://github.com/grafana/loki/releases/download/v2.4.2/promtail-linux-amd64.zip

if [ ! -e $TOPDIR/bin/promtail ]; then
    unzip promtail-linux-amd64.zip
    mv promtail-linux-amd64 $TOPDIR/bin/promtail
fi

cat > $TOPDIR/promtail/promtail-config.yaml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: $TOPDIR/promtail/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      job: system
      agent: promtail
      __path__: /var/log/messages

  - targets:
      - localhost
    labels:
      job: nginx
      agent: promtail
      __path__: /var/log/nginx/*log
EOF

cat > /etc/systemd/system/promtail.service << EOF
[Unit]
Description=promtail
After=network.target

[Service]
User=monitoring
Group=monitoring
Type=simple
ExecStart=$TOPDIR/bin/promtail --config.file=$TOPDIR/promtail/promtail-config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

chmod a+r /var/log/nginx
chmod a+r /var/log/nginx/*
chmod a+r /var/log/messages

systemctl enable promtail
systemctl start  promtail
systemctl status promtail

# install prometheus
ensure_install_file https://github.com/prometheus/prometheus/releases/download/v2.33.4/prometheus-2.33.4.linux-amd64.tar.gz

if [ ! -e $TOPDIR/bin/prometheus ]; then
    tar xf prometheus-2.33.4.linux-amd64.tar.gz
    mv prometheus-2.33.4.linux-amd64/prometheus $TOPDIR/bin/
    mv prometheus-2.33.4.linux-amd64/promtool $TOPDIR/bin/
fi

cat > $TOPDIR/prometheus/prometheus.yaml <<EOF
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
    - targets: ["localhost:9090"]
  - job_name: "node_exporter"
    static_configs:
    - targets: ["localhost:9100"]
EOF

# create systemd services
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/
After=network.target

[Service]
User=monitoring
Group=monitoring
Type=simple
ExecStart=$TOPDIR/bin/prometheus --config.file=$TOPDIR/prometheus/prometheus.yaml --storage.tsdb.path=$TOPDIR/prometheus/data
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable prometheus
systemctl start  prometheus
systemctl status prometheus

# install grafana
ensure_install_file https://dl.grafana.com/enterprise/release/grafana-8.4.2.linux-amd64.tar.gz

if [ ! -d $TOPDIR/grafana ]; then
    tar xf grafana-8.4.2.linux-amd64.tar.gz
    mv grafana-8.4.2 grafana
fi
mkdir -p grafana/data
chown -R monitoring:monitoring grafana

cat > /etc/systemd/system/grafana-server.service << EOF
[Unit]
Description=Grafana
After=network.target

[Service]
User=monitoring
Group=monitoring
Type=notify
ExecStart=$TOPDIR/grafana/bin/grafana-server -homepath $TOPDIR/grafana
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable grafana-server
systemctl start  grafana-server
systemctl status grafana-server
