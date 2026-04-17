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
else
  echo "[tailscale] TS_ENABLED!=true or TS_AUTHKEY empty; skipping"
fi

exec node src/server.js
