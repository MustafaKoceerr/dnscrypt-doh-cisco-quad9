#!/usr/bin/env bash
set -euo pipefail

# Kullanım:
#   sudo ./scripts/rollback.sh [--keep-config]
#
# --keep-config  : /etc/dnscrypt-proxy/dnscrypt-proxy.toml dosyasını silmez.

KEEP_CFG=0
for arg in "$@"; do
  case "$arg" in
    --keep-config) KEEP_CFG=1 ;;
    *) echo "Bilinmeyen seçenek: $arg" >&2; exit 2 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "[!] Lütfen root (sudo) ile çalıştırın." >&2
  exit 1
fi

echo "[*] dnscrypt-proxy durduruluyor ve devre dışı bırakılıyor..."
systemctl disable --now dnscrypt-proxy || true

echo "[*] NetworkManager global DNS kuralı kaldırılıyor..."
rm -f /etc/NetworkManager/conf.d/00-dnscrypt-global.conf || true
systemctl restart NetworkManager || true

echo "[*] /etc/resolv.conf serbest bırakılıyor..."
if command -v chattr >/dev/null 2>&1; then
  chattr -i /etc/resolv.conf 2>/dev/null || true
fi

# DHCP’den otomatik DNS alması için basit bir resolv.conf bırak
cat >/etc/resolv.conf <<'EOF'
# Managed by rollback.sh — dağıtımınız bu dosyayı yeniden yazabilir.
# NetworkManager/systemd-resolved yeniden etkinse kendi mekanizması devreye girecektir.
nameserver 192.168.1.1
EOF
chmod 644 /etc/resolv.conf

if [[ "$KEEP_CFG" -eq 0 ]]; then
  echo "[*] dnscrypt-proxy konfigürasyonu kaldırılıyor..."
  rm -f /etc/dnscrypt-proxy/dnscrypt-proxy.toml || true
fi

echo "[✓] Rollback tamamlandı."
echo "[i] Gerekirse systemd-resolved’ı yeniden etkinleştirin: sudo systemctl enable --now systemd-resolved"
