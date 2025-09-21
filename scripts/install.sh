#!/usr/bin/env bash
set -euo pipefail

# dnscrypt-proxy + Cisco(DoH) öncelikli, Quad9(DoH) fallback
# Dual-stack (IPv4/IPv6) — /etc/dnscrypt-proxy/dnscrypt-proxy.toml'ı
# repo içindeki config/dnscrypt-proxy.toml’dan kopyalar.
#
# Kullanım:
#   sudo ./scripts/install.sh [--disable-resolved] [--no-chattr]
#
# Seçenekler:
#   --disable-resolved   systemd-resolved varsa devre dışı bırakır (Ubuntu vb.)
#   --no-chattr          /etc/resolv.conf için chattr +i uygulamaz

DISABLE_RESOLVED=0
USE_CHATTR=1
for arg in "$@"; do
  case "$arg" in
    --disable-resolved) DISABLE_RESOLVED=1 ;;
    --no-chattr)        USE_CHATTR=0 ;;
    *) echo "Bilinmeyen seçenek: $arg" >&2; exit 2 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "[!] Lütfen root (sudo) ile çalıştırın." >&2
  exit 1
fi

# --- Paket yöneticisini tespit et ve dnscrypt-proxy kur ---
echo "[+] dnscrypt-proxy kuruluyor..."
if command -v dnf >/dev/null 2>&1; then
  dnf -y install dnscrypt-proxy
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y dnscrypt-proxy
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm dnscrypt-proxy
elif command -v zypper >/dev/null 2>&1; then
  zypper --non-interactive in dnscrypt-proxy
else
  echo "[!] Desteklenen bir paket yöneticisi bulunamadı. dnscrypt-proxy’yi elle kurun." >&2
fi

# --- Klasörler ve yedek ---
install -d -m 0755 /etc/dnscrypt-proxy
install -d -m 0755 /var/cache/dnscrypt-proxy

TS="$(date +%F-%H%M%S)"
if [[ -f /etc/dnscrypt-proxy/dnscrypt-proxy.toml ]]; then
  cp -a /etc/dnscrypt-proxy/dnscrypt-proxy.toml "/etc/dnscrypt-proxy/dnscrypt-proxy.toml.backup.$TS"
  echo "[+] Mevcut toml yedeklendi: /etc/dnscrypt-proxy/dnscrypt-proxy.toml.backup.$TS"
fi

# --- Repo içindeki config dosyasını kopyala ---
SRC_CFG="$(dirname "$0")/../config/dnscrypt-proxy.toml"
if [[ ! -f "$SRC_CFG" ]]; then
  echo "[!] config/dnscrypt-proxy.toml bulunamadı. Repo yapısını koruduğunuzdan emin olun." >&2
  exit 1
fi
install -m 0644 "$SRC_CFG" /etc/dnscrypt-proxy/dnscrypt-proxy.toml
echo "[+] Konfig kopyalandı: /etc/dnscrypt-proxy/dnscrypt-proxy.toml"

# --- systemd-resolved yönetimi (opsiyonel) ---
if systemctl is-enabled systemd-resolved >/dev/null 2>&1 || systemctl is-active systemd-resolved >/dev/null 2>&1; then
  if [[ "$DISABLE_RESOLVED" -eq 1 ]]; then
    echo "[*] systemd-resolved devre dışı bırakılıyor..."
    systemctl disable --now systemd-resolved || true
    # Ubuntu’da /etc/resolv.conf genelde bir symlink’tir; kırık ise temizle
    if [[ -L /etc/resolv.conf || ! -e /etc/resolv.conf ]]; then
      rm -f /etc/resolv.conf || true
    fi
  else
    echo "[i] systemd-resolved aktif görünüyor. İstersen --disable-resolved ile kapatabilirsin."
  fi
fi

# --- Global DNS: /etc/resolv.conf -> 127.0.2.1 ---
# Not: Bu yaklaşım tüm bağlantılar için dnscrypt-proxy’yi zorlar.
echo "nameserver 127.0.2.1" > /etc/resolv.conf
chmod 644 /etc/resolv.conf
if command -v chattr >/dev/null 2>&1 && [[ "$USE_CHATTR" -eq 1 ]]; then
  chattr -i /etc/resolv.conf 2>/dev/null || true
  chattr +i /etc/resolv.conf 2>/dev/null || true
  echo "[+] /etc/resolv.conf sabitlendi (chattr +i)."
else
  echo "[i] chattr uygulanmadı. (—no-chattr kullanıldı veya chattr yok)"
fi

# --- NetworkManager genel ayar (her Wi-Fi’da kalıcı olması için) ---
install -d -m 0755 /etc/NetworkManager/conf.d
cat >/etc/NetworkManager/conf.d/00-dnscrypt-global.conf <<'EOF'
[main]
dns=default

[global-dns]
# Tüm bağlantılar için yerel resolver
dns=127.0.2.1;
EOF

systemctl restart NetworkManager || true

# --- dnscrypt-proxy cache temizle + servis başlat ---
rm -f /var/cache/dnscrypt-proxy/*.md 2>/dev/null || true
systemctl enable --now dnscrypt-proxy

sleep 1
echo "[+] dnscrypt-proxy durumu:"
journalctl -u dnscrypt-proxy -n 25 --no-pager || true

echo
echo "[✓] Kurulum tamam. Hızlı testler:"
echo "    dig @127.0.2.1 example.com A +short"
echo "    dig @127.0.2.1 example.com AAAA +short"
echo
echo "[i] Aktif seçilen resolver’ı görmek için:"
echo "    journalctl -u dnscrypt-proxy -n 40 --no-pager | grep -E '(DoH)|lowest initial latency'"
