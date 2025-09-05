#!/bin/bash
yum -y install amazon-cloudwatch-agent
curl -o /usr/local/bin/app https://s3.ap-northeast-2.amazonaws.com/{bucket}/app
chmod +x /usr/local/bin/app
cat >/etc/systemd/system/app.service <<'EOF'
[Unit] Description=Go API
[Service] ExecStart=/usr/local/bin/app
Restart=always
[Install] WantedBy=multi-user.target
EOF
systemctl enable --now app
