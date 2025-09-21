# dnscrypt-doh-cisco-quad9

🔒 **Güvenli ve hızlı DNS çözümleme:** Cisco OpenDNS DoH (IPv4 + IPv6)
**öncelikli**, Quad9 DoH **otomatik fallback**.\
Bu repo, `dnscrypt-proxy` ile hem IPv4 hem IPv6 üzerinde güvenli DoH
çözümleme ayarlarını ve kurulum scriptlerini içerir.

------------------------------------------------------------------------

## 📦 Proje Yapısı

    dnscrypt-doh-cisco-quad9/
    ├─ config/
    │  └─ dnscrypt-proxy.toml     # Cisco + Quad9 DoH yapılandırması (hazır)
    ├─ scripts/
    │  ├─ install.sh              # Kurulum, servis enable + resolv.conf sabitleme
    │  ├─ rollback.sh             # Orijinal duruma geri alma
    │  ├─ test-fallback.sh        # Cisco engelle → Quad9 fallback test
    │  └─ verify.sh               # DoH/IPv6 test & DNS sızıntı kontrolü
    ├─ LICENSE
    └─ README.md

------------------------------------------------------------------------

## 🚀 Kurulum

### 1️⃣ Adım --- Repo'yu Klonla

``` bash
git clone https://github.com/MustafaKoceerr/dnscrypt-doh-cisco-quad9.git
cd dnscrypt-doh-cisco-quad9
```

### 2️⃣ Adım --- Scriptleri Çalıştır

> İlk çalıştırmada sudo şifresi istenir.

``` bash
chmod +x scripts/*.sh
sudo ./scripts/install.sh
```

Kurulum tamamlandıktan sonra `dnscrypt-proxy` servisiniz aktif
olacaktır.\
Bütün DNS istekleriniz artık **Cisco DoH** üzerinden, hata durumunda ise
**Quad9 DoH** üzerinden çözülecektir.

------------------------------------------------------------------------

## ✅ Doğrulama

Kurulumdan sonra şu komut ile test edebilirsin:

``` bash
./scripts/verify.sh
```

Bu script: - Hangi resolver'ın seçildiğini loglardan okur - Aktif TLS
bağlantılarını gösterir (`cisco-doh-ip4`, `quad9-doh-ip6` vs.) - Hem A
hem AAAA sorgularını test eder - `resolver.dnscrypt.info` üzerinden
hangi sunucu ile konuştuğunu doğrular

------------------------------------------------------------------------

## 🛠 Cisco → Quad9 Fallback Testi

Cisco'yu engelleyip Quad9'a geçişi gözlemlemek için:

``` bash
./scripts/test-fallback.sh
```

> Test sonunda engelleme kuralları otomatik kaldırılır.

------------------------------------------------------------------------

## 🔄 Geri Alma

Kurulumdan tamamen çıkmak veya sistem ayarlarını eski haline döndürmek
için:

``` bash
sudo ./scripts/rollback.sh
```

------------------------------------------------------------------------

## 🧠 Sık Karşılaşılan Hatalar

  -----------------------------------------------------------------------------------------
  Hata / Durum                                    Çözüm
  ----------------------------------------------- -----------------------------------------
  `No servers configured`                         `dnscrypt-proxy.toml` bozulmuş olabilir.
                                                  `config/` klasöründeki orijinali tekrar
                                                  kopyala ve servisi yeniden başlat.

  `connection refused`                            Servis çalışmıyor olabilir.
                                                  `sudo systemctl restart dnscrypt-proxy`
                                                  ile yeniden başlat.

  IPv6 sorguları yanıt vermiyor                   ISP IPv6'yı desteklemiyor olabilir.
                                                  `config/dnscrypt-proxy.toml` içinde
                                                  `ipv6_servers = false` yapabilirsin.

  Cisco engellenmiş gözüküyor ama Quad9'a         `systemd-resolved` veya `NetworkManager`
  geçmiyor                                        başka DNS kullanıyor olabilir.
                                                  `install.sh` scripti resolv.conf'u
                                                  kilitler, doğru çalıştığından emin ol.
  -----------------------------------------------------------------------------------------

------------------------------------------------------------------------

## 📜 Lisans

Bu proje **MIT Lisansı** ile yayınlanmıştır.\
Detaylar için [LICENSE](./LICENSE) dosyasına bakabilirsiniz.

------------------------------------------------------------------------

## 🌐 Bağlantılar

-   📂 GitHub:
    [dnscrypt-doh-cisco-quad9](https://github.com/MustafaKoceerr/dnscrypt-doh-cisco-quad9)
-   📖 dnscrypt-proxy belgeleri:
    <https://github.com/DNSCrypt/dnscrypt-proxy/wiki>

------------------------------------------------------------------------

💡 **Not:** Bu repo distro-bağımsızdır (Fedora, Ubuntu, Arch
vs. üzerinde çalışır).\
Sadece paket yöneticisi farklılık gösterir (`dnf`, `apt`, `pacman`).
