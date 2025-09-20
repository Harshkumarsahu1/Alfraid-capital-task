#!/usr/bin/env bash
set -euxo pipefail

SERVER_IP="${server_ip}"
REGION="${region}"

# Update and install dependencies
apt-get update -y
apt-get install -y unzip curl jq gnupg lsb-release apt-transport-https ca-certificates

# Install Docker
apt-get install -y docker.io
systemctl enable --now docker

# Install Nomad (hardcoded version to avoid Terraform template interpolation)
cd /tmp
curl -fsSLo nomad.zip "https://releases.hashicorp.com/nomad/1.8.1/nomad_1.8.1_linux_amd64.zip"
unzip nomad.zip -d /usr/local/bin/
chmod +x /usr/local/bin/nomad

# Create nomad user and dirs
useradd --system --home /etc/nomad.d --shell /bin/false nomad || true
mkdir -p /opt/nomad
mkdir -p /etc/nomad.d
chmod 750 /etc/nomad.d
chown -R nomad:nomad /opt/nomad /etc/nomad.d

# Nomad server config
cat > /etc/nomad.d/server.hcl <<EOF
log_level = "INFO"
bind_addr = "0.0.0.0"

advertise {
  http = "$${SERVER_IP}:4646"
  rpc  = "$${SERVER_IP}:4647"
  serf = "$${SERVER_IP}:4648"
}

server {
  enabled          = true
  bootstrap_expect = 1
}

ui {
  enabled = true
}

addresses {
  http = "127.0.0.1" # UI/API only on localhost; use IAP/SSH tunnel
}

datacenter = "dc1"
EOF

# Systemd unit
cat > /etc/systemd/system/nomad.service <<'EOF'
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
User=nomad
Group=nomad
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Install Google Ops Agent (logs/metrics)
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

systemctl daemon-reload
systemctl enable --now nomad

# Allow nomad user to use Docker
usermod -aG docker nomad || true

# Print status
nomad version || true
