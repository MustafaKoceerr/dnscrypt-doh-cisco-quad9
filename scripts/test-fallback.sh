#!/usr/bin/env bash
set -euo pipefail

# Kullanım:
#   sudo ./scripts/test-fallback.sh

if [[ $EUID -ne 0 ]]; then
  echo "[!] Lütfen root (sudo) ile çalıştırın." >&2
  exit 1
fi

CISCO_V4=208.67.222.222
CISCO_V6=2620:119:35::35
Q9_V4=9.9.9.10
Q9_V6=2620:fe::10

clean_rules() {
  iptables  -D OUTPUT -p tcp --dport 443 -d "$CISCO_V4" -j REJECT 2>/dev/null || true
  ip6tables -D OUTPUT -p tcp --dport 443 -d "$CISCO_V6" -j REJECT 2>/dev/null || true
  iptables  -D OUTPUT -p tcp --dport 443 -d "$Q9_V4"    -j REJECT 2>/dev/null || true
  ip6tables -D OUTPUT -p tcp --dport 443 -d "$Q9_V6"    -j REJECT 2>/dev/null || true
}

trap clean_rules EXIT

echo "[1/4] Başlangıç durumu:"
journalctl -u dnscrypt-proxy -n 8 --no-pager | grep -E "(DoH)|lowest initial latency" || true
echo

echo "[2/4] Cisco’yu geçici engelle (IPv4+IPv6) -> Quad9 devreye girmeli"
iptables  -I OUTPUT -p tcp --dport 443 -d "$CISCO_V4" -j REJECT
ip6tables -I OUTPUT -p tcp --dport 443 -d "$CISCO_V6" -j REJECT
systemctl restart dnscrypt-proxy
sleep 1
journalctl -u dnscrypt-proxy -n 12 --no-pager | grep -E "quad9-doh-.*(DoH)|lowest initial latency" || true
echo

echo "[3/4] Cisco engelini kaldır, Quad9’u engelle -> Cisco devreye dönmeli"
iptables  -D OUTPUT -p tcp --dport 443 -d "$CISCO_V4" -j REJECT || true
ip6tables -D OUTPUT -p tcp --dport 443 -d "$CISCO_V6" -j REJECT || true
iptables  -I OUTPUT -p tcp --dport 443 -d "$Q9_V4"    -j REJECT
ip6tables -I OUTPUT -p tcp --dport 443 -d "$Q9_V6"    -j REJECT
systemctl restart dnscrypt-proxy
sleep 1
journalctl -u dnscrypt-proxy -n 12 --no-pager | grep -E "cisco-doh-.*(DoH)|lowest initial latency" || true
echo

echo "[4/4] Tüm engelleri temizle"
clean_rules
systemctl restart dnscrypt-proxy
sleep 1
journalctl -u dnscrypt-proxy -n 8 --no-pager | grep -E "(DoH)|lowest initial latency" || true
echo "[✓] Test bitti."
