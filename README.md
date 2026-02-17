# SART Checker (Şartname Takip Sistemi)

Teknofest yarışma şartnamelerini (PDF) otomatik olarak takip eden, dosya içeriğinde herhangi bir değişiklik olduğunda masaüstü bildirimi gönderen Bash script ve Systemd servisi.

## Özellikler

- **Web Scraping:** Belirtilen URL adreslerinden güncel PDF bağlantılarını otomatik olarak bulur.
- **Akıllı İndirme:** User-Agent spoofing yöntemiyle bot korumalarını aşar.
- **Değişiklik Tespiti:** SHA256 hash kontrolü ile dosya içeriğindeki en ufak değişikliği yakalar.
- **Masaüstü Entegrasyonu:** `notify-send` kullanarak kritik seviyede masaüstü bildirimi gönderir.
- **Loglama:** Yapılan işlemleri ve hataları `log/sart_checker.log` dosyasına kaydeder.

## Desteklenen Sistemler ve Masaüstü Ortamları

| Masaüstü Ortamı | Görüntü Sunucusu | Bildirim Altyapısı |
|-----------------|------------------|--------------------|
| KDE Plasma      | X11 / Wayland    | Plasma Notifications |
| GNOME           | X11 / Wayland    | GNOME Shell built-in |
| XFCE            | X11              | xfce4-notifyd      |
| Hyprland        | Wayland          | dunst, mako veya swaync |

## Gereksinimler ve Kurulum

Sisteminize uygun paket yöneticisini kullanarak gerekli bağımlılıkları yükleyin.

**Arch Linux**
```bash
sudo pacman -S curl grep sed awk libnotify coreutils

```

**Ubuntu / Debian**

```bash
sudo apt install curl libnotify-bin coreutils

```

**Fedora**

```bash
sudo dnf install curl libnotify coreutils

```

**openSUSE**

```bash
sudo zypper install curl libnotify-tools coreutils

```

*Not: Hyprland veya pencere yöneticisi kullananların `dunst`, `mako` veya `swaync` gibi bir bildirim sunucusuna sahip olması gerekmektedir.*

## Dizin Yapısı

```text
sart_checker/
├── src/
│   └── check.sh           # Ana kontrol betiği
├── known/                 # Referans PDF dosyaları (Değişiklik buna göre kıyaslanır)
├── recent/                # İndirilen güncel PDF dosyaları
├── log/
│   └── sart_checker.log   # İşlem kayıtları
├── sart_checker.service   # Systemd servis dosyası
├── sart_checker.timer     # Systemd zamanlayıcı dosyası
├── LICENSE                # Lisans dosyası
└── README.md              # Dokümantasyon

```

## Yapılandırma ve Kurulum Adımları

### 1. Yetkilendirme

Betik dosyasını çalıştırılabilir hale getirin:

```bash
chmod +x src/check.sh

```

### 2. İlk Çalıştırma ve Referans Oluşturma

Sistemin çalışabilmesi için önce güncel dosyaların indirilmesi ve referans olarak tanımlanması gerekir.

Betiği manuel olarak çalıştırın:

```bash
./src/check.sh

```

İndirilen dosyaları kontrol edin ve referans klasörüne kopyalayın:

```bash
cp recent/*.pdf known/

```

Bu işlemden sonra script, `recent` klasörüne inen yeni dosyaları `known` klasöründekilerle kıyaslayacaktır.

### 3. Otomasyon Kurulumu (Systemd)

Servis ve zamanlayıcı dosyalarını kullanıcı dizinine kopyalayın ve yapılandırın:

```bash
mkdir -p ~/.config/systemd/user

cp sart_checker.service sart_checker.timer ~/.config/systemd/user/

sed -i "s|ExecStart=.*|ExecStart=$(pwd)/src/check.sh|" ~/.config/systemd/user/sart_checker.service

systemctl --user daemon-reload
systemctl --user enable --now sart_checker.timer

```

## Kullanım ve Kontrol

### Manuel Kontrol

İstediğiniz zaman betiği elle çalıştırarak kontrol sağlayabilirsiniz:

```bash
./src/check.sh

```

### Servis Durumunu Kontrol Etme

Zamanlayıcının ve servisin durumunu kontrol etmek için:

```bash
systemctl --user status sart_checker.timer
systemctl --user list-timers sart_checker.timer

```

### Logları İzleme

Arka planda yapılan işlemleri canlı olarak takip etmek için:

```bash
tail -f log/sart_checker.log

```

veya systemd günlükleri için:

```bash
journalctl --user -u sart_checker.service -n 50

```

## Yeni Yarışma Ekleme

Yeni bir yarışma eklemek için `src/check.sh` dosyasını açın ve `SOURCES` dizisine ilgili yarışmanın sayfa URL'sini ve kaydedilecek dosya adını ekleyin.

Format:
`"URL_ADRESI|KAYDEDILECEK_DOSYA_ADI.pdf"`

Örnek:

```bash
SOURCES=(
    "[https://www.teknofest.org/tr/yarismalar/ornek-yarisma/](https://www.teknofest.org/tr/yarismalar/ornek-yarisma/)|ORNEK_SARTNAME.pdf"
)

```

## Çalışma Mantığı

1. Belirtilen web sayfasının HTML içeriği çekilir.
2. Sayfa içerisindeki güncel PDF bağlantısı (regex ile) tespit edilir.
3. PDF dosyası indirilerek `recent/` dizinine kaydedilir.
4. İndirilen dosyanın SHA-256 özeti, `known/` dizinindeki referans dosya ile karşılaştırılır.
5. Özetler farklıysa, dosya değişmiş demektir ve masaüstü bildirimi gönderilir.
6. Özetler aynıysa işlem sonlandırılır.

## Devre Dışı Bırakma

Servisi durdurmak ve otomatik başlatmayı kapatmak için:

```bash
systemctl --user stop sart_checker.timer
systemctl --user disable sart_checker.timer

```