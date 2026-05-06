#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

USERNAME="${1:-hermes}"

echo "[1/7] apt packages"
sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  vim \
  htop \
  jq \
  unzip \
  tmux \
  ufw \
  fail2ban

echo "[2/7] directories"
sudo mkdir -p \
  /opt/hermes \
  /opt/hermes/worker \
  /opt/models \
  /opt/data \
  /var/log/hermes
sudo chown -R "${USERNAME}:${USERNAME}" /opt/hermes /opt/models /opt/data /var/log/hermes

echo "[3/7] docker repo"
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.asc.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.asc.gpg
fi
sudo chmod a+r /etc/apt/keyrings/docker.asc.gpg

ARCH="$(dpkg --print-architecture)"
. /etc/os-release

if [ -n "${UBUNTU_CODENAME:-}" ]; then
  DOCKER_CODENAME="${UBUNTU_CODENAME}"
else
  DOCKER_CODENAME="${VERSION_CODENAME}"
fi

echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc.gpg] https://download.docker.com/linux/ubuntu ${DOCKER_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[4/7] docker install"
sudo apt-get update
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "[5/7] docker service"
sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker || true

echo "[6/7] docker group"
sudo usermod -aG docker "${USERNAME}"

echo "[7/7] healthcheck"
cat <<'EOF' | sudo tee /usr/local/bin/hermes-worker-health >/dev/null
#!/usr/bin/env bash
set -euo pipefail
echo "HOSTNAME=$(hostname)"
echo "DATE=$(date -Iseconds)"
echo "KERNEL=$(uname -r)"
echo "DOCKER=$(docker --version 2>/dev/null || echo unavailable)"
echo "DOCKER_COMPOSE=$(docker compose version 2>/dev/null || echo unavailable)"
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "NVIDIA_SMI=present"
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader || true
else
  echo "NVIDIA_SMI=absent"
fi
EOF
sudo chmod +x /usr/local/bin/hermes-worker-health

echo "Bootstrap complete on $(hostname)"
