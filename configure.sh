#!/usr/bin/env bash
# Configure SSH aliases and enable root-key SSH access on all nodes.
#
# Usage:
#   chmod +x configure.sh
#   ./configure.sh
#
# Requires:
#   - terraform2425.pem and terraform2426.pem in ~/.ssh (or PEM_DIR)
#   - ~/.ssh/id_rsa.pub (or LOCAL_PUBKEY)

set -euo pipefail

# ---------- Configuration ----------
PEM_DIR="${PEM_DIR:-$HOME/.ssh}"
LOCAL_PUBKEY="${LOCAL_PUBKEY:-$HOME/.ssh/id_rsa.pub}"
SSH_CONFIG="$HOME/.ssh/config"

HOSTS=(
  admin
  puppetca1
  puppetca2
  puppetmaster1
  puppetmaster2
  puppetmaster3
  worker1
  worker2
  worker3
)

declare -A HOST_IPS=(
  [admin]="3.236.196.113"
  [puppetca1]="3.237.80.243"
  [puppetca2]="3.91.172.2"
  [puppetmaster1]="3.235.6.172"
  [puppetmaster2]="35.171.193.46"
  [puppetmaster3]="3.210.200.137"
  [worker1]="3.218.249.159"
  [worker2]="44.200.236.126"
  [worker3]="100.62.23.114"
)

declare -A HOST_KEYS=(
  [puppetca1]="terraform2425.pem"
  [puppetmaster1]="terraform2425.pem"
  [puppetmaster2]="terraform2425.pem"
  [puppetmaster3]="terraform2425.pem"
  [puppetca2]="terraform2426.pem"
  [admin]="terraform2426.pem"
  [worker1]="terraform2426.pem"
  [worker2]="terraform2426.pem"
  [worker3]="terraform2426.pem"
)

# ---------- 1. Update ~/.ssh/config ----------
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$SSH_CONFIG"

for host in "${HOSTS[@]}"; do
  ip="${HOST_IPS[$host]}"
  tmp_config="$(mktemp "${SSH_CONFIG}.tmp.XXXXXX")"

  # Remove an existing exact Host <name> block, if present.
  awk -v target="Host $host" '
    $0 == target {
      skipping = 1
      next
    }
    skipping && /^Host[[:space:]]/ {
      skipping = 0
    }
    !skipping {
      print
    }
  ' "$SSH_CONFIG" > "$tmp_config"

  mv "$tmp_config" "$SSH_CONFIG"

  cat >> "$SSH_CONFIG" <<EOF

Host $host
  HostName $ip
  User root
EOF
done

chmod 600 "$SSH_CONFIG"

echo "Updated $SSH_CONFIG:"
for host in "${HOSTS[@]}"; do
  echo "  - $host -> ${HOST_IPS[$host]} (User root)"
done
echo

# ---------- 2. Configure remote hosts ----------
if [[ ! -f "$LOCAL_PUBKEY" ]]; then
  echo "ERROR: Public key not found: $LOCAL_PUBKEY" >&2
  echo "Create one with: ssh-keygen -t rsa -b 4096 -f \"$HOME/.ssh/id_rsa\"" >&2
  exit 1
fi

# Base64 avoids quoting problems while passing the public key to the remote host.
PUBKEY_B64="$(base64 < "$LOCAL_PUBKEY" | tr -d '\r\n')"

for host in "${HOSTS[@]}"; do
  ip="${HOST_IPS[$host]}"
  key_file="${PEM_DIR}/${HOST_KEYS[$host]}"

  if [[ ! -f "$key_file" ]]; then
    echo "ERROR: PEM key not found for $host: $key_file" >&2
    exit 1
  fi

  chmod 400 "$key_file"

  echo "=== $host ($ip) ==="

  ssh -i "$key_file" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "centos@$ip" "PUBKEY_B64='$PUBKEY_B64' TARGET_HOST='$host' bash -s" <<'REMOTE'
set -euo pipefail

pubkey="$(printf '%s' "$PUBKEY_B64" | base64 -d)"

sudo mkdir -p /root/.ssh
sudo chmod 700 /root/.ssh
sudo touch /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys

if ! sudo grep -qxF "$pubkey" /root/.ssh/authorized_keys; then
  printf '%s\n' "$pubkey" | sudo tee -a /root/.ssh/authorized_keys > /dev/null
fi

sudo sed -i -E \
  's/^[[:space:]]*#?[[:space:]]*PermitRootLogin[[:space:]].*/PermitRootLogin yes/' \
  /etc/ssh/sshd_config

if ! sudo grep -qx 'PermitRootLogin yes' /etc/ssh/sshd_config; then
  echo 'PermitRootLogin yes' | sudo tee -a /etc/ssh/sshd_config > /dev/null
fi

sudo sshd -t

sudo hostnamectl set-hostname "$TARGET_HOST"

if grep -q '^127.0.1.1' /etc/hosts; then
  sudo sed -i -E \
    "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1 $TARGET_HOST/" \
    /etc/hosts
else
  echo "127.0.1.1 $TARGET_HOST" | sudo tee -a /etc/hosts > /dev/null
fi

sudo systemctl restart ssh || sudo systemctl restart sshd

echo "Configured successfully."
REMOTE

  echo
done

echo "All hosts processed. You can now connect, for example:"
echo "  ssh puppetmaster1"