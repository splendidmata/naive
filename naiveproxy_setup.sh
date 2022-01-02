#!/bin/bash
echo "Installing caddy"
curl https://getcaddy.com | bash -s personal http.forwardproxy

cat << EOF > /usr/lib/systemd/system/caddy.service
[Unit]
Description=Caddy HTTP/2 web server
Documentation=https://caddyserver.com/docs
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
StartLimitIntervalSec=14400
StartLimitBurst=10

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/caddy -log stdout -agree -conf /etc/caddy/caddy.conf -root=/usr/share/caddy
ExecReload=/usr/bin/kill -USR1 $MAINPID

# Do not allow the process to be restarted in a tight loop. If the
# process fails to start, something critical needs to be fixed.
Restart=on-abnormal

# Use graceful shutdown with a reasonable timeout
KillMode=mixed
KillSignal=SIGQUIT
TimeoutStopSec=5s

LimitNOFILE=1048576
LimitNPROC=512

[Install]
WantedBy=multi-user.target
EOF

echo "Caddy installation completed"

echo "Installing naiveproxy"
curl -s "https://api.github.com/repos/klzgrad/naiveproxy/releases/latest" | \
	grep linux-x64 | grep browser_download_url | \
	cut -d : -f 2,3 | tr -d \" | wget -qi -

tar -xvf naive*tar.xz
cp naive*/naive /usr/local/bin/naiveproxy

cat << EOF > /usr/lib/systemd/system/naiveproxy.service
[Unit]
Description=naiveproxy - Make a fortune quietly
Documentation=https://github.com/klzgrad/naiveproxy/blob/master/USAGE.txt
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
# If the version of systemd is 240 or above, then uncommenting Type=exec and commenting out Type=simple
Type=exec
#Type=simple
# Runs as root or add CAP_NET_BIND_SERVICE ability can bind 1 to 1024 port.
# This service runs as root. You may consider to run it as another user for security concerns.
# By uncommenting User=naiveproxy and commenting out User=root, the service will run as user naiveproxy.

User=root
#User=naiveproxy
#AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=/usr/local/bin/naiveproxy /etc/naiveproxy/config.json
Restart=on-failure
# Don't restart in the case of configuration error
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

echo "naiveproxy completed"

mkdir /etc/naiveproxy/ /etc/caddy

echo "setting up caddy"

printf "Input domain name: "
read domain
printf "Input your email address: "
read email
printf "Input username: "
read username
printf "Input password: "
read password

cat << EOF > /etc/caddy/caddy.conf
$domain
root /var/www/html
tls $email
forwardproxy {
  basicauth $username $password
  hide_ip
  hide_via
  probe_resistance secret.localhost
  upstream http://127.0.0.1:8080
}
EOF

echo "setting up naiveproxy"

cat << EOF > /etc/naiveproxy/config.json
{
    "listen": "http://127.0.0.1:8080",
    "padding": "true"
}
EOF

systemctl daemon-reload
systemctl enable naiveproxy caddy --now
