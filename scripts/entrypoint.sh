#!/usr/bin/env bash
set -e

if [ "${TS_ENABLED:-}" = "true" ] && [ -n "${TS_AUTHKEY:-}" ]; then
  echo "[tailscale] starting tailscaled (userspace-networking)..."
  mkdir -p /var/run/tailscale /var/lib/tailscale
  /usr/sbin/tailscaled \
    --tun=userspace-networking \
    --socks5-server=localhost:1055 \
    --outbound-http-proxy-listen=localhost:1099 \
    --state=/var/lib/tailscale/tailscaled.state \
    --socket=/var/run/tailscale/tailscaled.sock \
    >/tmp/tailscaled.log 2>&1 &

  for i in $(seq 1 20); do
    [ -S /var/run/tailscale/tailscaled.sock ] && break
    sleep 0.25
  done

  echo "[tailscale] tailscale up..."
  /usr/bin/tailscale --socket=/var/run/tailscale/tailscaled.sock up \
    --authkey="$TS_AUTHKEY" \
    --hostname="${TS_HOSTNAME:-railway-clawdbot}" \
    --accept-dns=false
  /usr/bin/tailscale --socket=/var/run/tailscale/tailscaled.sock status || true

  if [ -f /data/.ssh/id_ed25519 ]; then
    echo "[ssh] restoring key + config from /data/.ssh..."
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    cp /data/.ssh/id_ed25519 /root/.ssh/id_ed25519 && chmod 600 /root/.ssh/id_ed25519
    [ -f /data/.ssh/id_ed25519.pub ] && cp /data/.ssh/id_ed25519.pub /root/.ssh/id_ed25519.pub
    if [ -n "${SSH_MAC_IP:-}" ] && [ -n "${SSH_MAC_USER:-}" ]; then
      cat > /root/.ssh/config <<EOF
Host mac
  HostName ${SSH_MAC_IP}
  User ${SSH_MAC_USER}
  IdentityFile /root/.ssh/id_ed25519
  ProxyCommand nc -X 5 -x localhost:1055 %h %p
  StrictHostKeyChecking accept-new
EOF
      chmod 600 /root/.ssh/config
      echo "[ssh] alias 'mac' configured -> ${SSH_MAC_USER}@${SSH_MAC_IP}"
    fi
  fi
else
  echo "[tailscale] TS_ENABLED!=true or TS_AUTHKEY empty; skipping"
fi

exec node src/server.js
