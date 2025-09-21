# dnscrypt-opendns-quad9

Hızlı ve tutarlı **DoH (DNS over HTTPS)** çözümlemesi için **Cisco/OpenDNS (primary)** + **Quad9 (fallback)** ayarlı, dağıtım-agnostik bir `dnscrypt-proxy` yapılandırması.  
Amaç: **düşük gecikme**, **failover**, **kolay kurulum** ve **her Wi‑Fi’de global olarak** çalışması.

> Test ortamı: Fedora 42 + NetworkManager. Ubuntu/Debian/Arch/Fedora için kurulum adımları yer alır.

---

## İçerik

- `configs/dnscrypt-proxy.toml` — Çalışan örnek TOML (Cisco DoH v4/v6 ana, Quad9 DoH v4/v6 yedek).
- `install.sh` — Otomatik kurulum (root/sudo ile tek adım).
- `linux/setup.sh` — Etkileşimli kurulum/ince ayar sihirbazı.
- `tools/dnscrypt-on.sh` — Global DoH’i aç.
- `tools/dnscrypt-off.sh` — Global DoH’i kapat (DHCP DNS’e dön).
- `tools/dnscrypt-status.sh` — Hızlı durum kontrolü.
- `tools/dnscrypt-switch.sh` — Cisco ↔︎ Quad9 hızlı geçiş.

> **Not:** Bu repo sistem genelinde (`/etc/resolv.conf`) DNS’i `127.0.2.1`’e yönlendirir; böylece **tüm Wi‑Fi/ethernet profillerinde** aynı ayarlar kullanılmaya devam eder.

---

## Hızlı Başlangıç

```bash
# 1) İndir ve içeriğine gir
git clone https://github.com/USER/dnscrypt-opendns-quad9.git
cd dnscrypt-opendns-quad9

# 2) Kur (paketleri yükler, configi kopyalar, global DNS'i 127.0.2.1 yapar)
sudo bash install.sh

# 3) Durum kontrolü
sudo tools/dnscrypt-status.sh
```

---

## Failover Mantığı

- **Primary:** Cisco OpenDNS DoH (IPv4 + IPv6)
- **Fallback:** Quad9 DoH (IPv4 + IPv6)
- `dnscrypt-proxy` en düşük RTT’li erişilebilir sunucuyu seçer. Cisco/Quad9 erişilemez olduğunda otomatik olarak diğerine geçer.
- İstersen **Cisco’yu zorunlu öncelik** yapmak için `server_names` sırasını yalnızca `['cisco-doh-ip4','cisco-doh-ip6']` olarak bırakıp Quad9’u geçici olarak çıkarabilir veya testte tekrar dahil edebilirsin.

---

## Doğrulama Komutları

```bash
# Etkin sunucular ve gecikme
sudo journalctl -u dnscrypt-proxy -n 40 --no-pager | grep -E "(DoH)|lowest initial latency"

# Quad9/Cisco üzerinden doğrudan test (DoH bağlantıları)
ss -ntp | grep -E '(9\.9\.9\.10:443|\[2620:fe::10\]:443|208\.67\.222\.222:443|\[2620:119:35::35\]:443)' || echo "Aktif DoH TLS yok"

# IPv4/IPv6 çözümleme
dig @127.0.2.1 example.com A +short
dig @127.0.2.1 example.com AAAA +short
```

---

## Sık Karşılaşılan Hatalar & Çözümler

### 1) `No servers configured` / `Invalid stamp`
- Çoğunlukla hatalı `server_names` veya bozuk static `stamp` tanımlarından olur.  
  **Çözüm:** Bu repodaki `configs/dnscrypt-proxy.toml` dosyasını **aynen** kullan. Static `[static.'...']` bölümleri **yok**; çözücüler `public-resolvers.md` üzerinden **ad** ile seçiliyor.
- Cache’i temizle: `sudo rm -f /var/cache/dnscrypt-proxy/*.md && sudo systemctl restart dnscrypt-proxy`

### 2) `resolv.conf` yazılamıyor / NetworkManager DNS’i geri alıyor
- `/etc/resolv.conf` bir symlink olabilir veya immutable olabilir.
- **Çözüm (scriptler zaten yapar):**
  ```bash
  sudo chattr -i /etc/resolv.conf 2>/dev/null || true
  sudo rm -f /etc/resolv.conf
  echo "nameserver 127.0.2.1" | sudo tee /etc/resolv.conf >/dev/null
  sudo chmod 644 /etc/resolv.conf
  sudo chattr +i /etc/resolv.conf
  # NetworkManager’ın dokunmaması için:
  sudo mkdir -p /etc/NetworkManager/conf.d
  printf "[main]\ndns=none\n" | sudo tee /etc/NetworkManager/conf.d/00-dns.conf >/dev/null
  sudo systemctl restart NetworkManager
  ```

### 3) `systemd-resolved` çakışmaları
- Ubuntu/Fedora’da `systemd-resolved` aktifse, stub resolver çakışması yaşanabilir.
- **Çözüm:** `sudo systemctl disable --now systemd-resolved` (gerekirse tekrar aktifleştirilebilir).

### 4) IPv6’da çözüm gelmiyor
- ISP IPv6’ı kırpıyor olabilir ya da firewall engelliyordur.
- **Kontrol:** `ping -6 google.com -c 3` ve `dig @127.0.2.1 cloudflare.com AAAA`  
- **Geçici çözüm:** `ipv6_servers = false` yaparak yalnızca IPv4 ile çalıştır.

### 5) DNS sızıntı testi beklenenden farklı ülke/AS gösteriyor
- DoH son noktaları **Anycast** çalışır; en yakın POP’a yönlenirsin (ör. Amsterdam/Frankfurt). Bu normaldir ve çözümleme gecikmesini düşürür.

---

## Desteklenen Dağıtımlar

- **Fedora, Ubuntu/Debian, Arch** için `install.sh` gerekli paketleri kurar ve yapılandırır.
- Diğer dağıtımlar da çalışır; `dnscrypt-proxy` paket adı farklı olabilir. Mantık aynı: servis kurulumu + `/etc/resolv.conf` → `127.0.2.1` + NetworkManager DNS override.

---

## Lisans
MIT
