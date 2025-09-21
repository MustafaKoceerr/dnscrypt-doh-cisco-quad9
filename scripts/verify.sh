#!/usr/bin/env bash
set -euo pipefail

echo "=== DoH & Resolver Test ==="
echo "[*] Güncel loglardan sunucu seçimini göster:"
sudo journalctl -u dnscrypt-proxy -n 20 --no-pager | grep -E "(DoH)|lowest initial latency" || echo "Log bulunamadı."

echo "[*] Aktif TLS bağlantıları (Cisco/Quad9):"
ss -ntp | grep -E '(208\.67\.222\.222:443|9\.9\.9\.10:443|\[2620:119:35::35\]:443|\[2620:fe::10\]:443)' || echo "Aktif DoH TLS yok."

echo "[*] Test A ve AAAA sorguları:"
dig @127.0.2.1 +short example.com A
dig @127.0.2.1 +short example.com AAAA

echo "[*] DNS sızıntı testi (kimlik):"
dig @127.0.2.1 +short resolver.dnscrypt.info TXT || echo "resolver.dnscrypt.info sorgusu başarısız"
