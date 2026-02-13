# sart_checker

Teknofest yarisma sayfalarindaki sartname PDF dosyalarini otomatik kontrol edip, degisiklik tespit ettiginde masaustu bildirimi gonderen otomasyon araci.

## Takip Edilen Yarismalar

| Yarisma | Dosya Adi |
|---------|-----------|
| [Insansiz Su Alti Sistemleri](https://www.teknofest.org/tr/yarismalar/insansiz-su-alti-sistemleri-yarismasi/) | `AUV_REPORT.pdf` |
| [Insansiz Deniz Araci](https://www.teknofest.org/tr/yarismalar/insansiz-deniz-araci-yarismasi/) | `USV_REPORT.pdf` |
| [Su Alti Roket](https://www.teknofest.org/tr/yarismalar/su-alti-roket-yarismasi/) | `AUR_REPORT.pdf` |

## Desteklenen Sistemler

| Masaustu | Display Server | Bildirim Altyapisi |
|----------|---------------|-------------------|
| KDE Plasma | X11 / Wayland | Plasma Notifications |
| GNOME | X11 / Wayland | GNOME Shell built-in |
| XFCE | X11 | xfce4-notifyd |
| Hyprland | Wayland | dunst / mako / swaync (kullanici kurmali) |

## Bagimliliklar

```bash
# Arch Linux
sudo pacman -S curl libnotify coreutils

# Ubuntu / Debian
sudo apt install curl libnotify-bin coreutils

# Fedora
sudo dnf install curl libnotify coreutils

# openSUSE
sudo zypper install curl libnotify-tools coreutils
```

Hyprland kullanicilari icin bildirim daemon'u gereklidir: `dunst`, `mako` veya `swaync`.

## Dizin Yapisi

```
sart_checker/
├── src/check.sh               # Ana kontrol scripti
├── known/                      # Referans PDF dosyalari (manuel)
├── recent/                     # Indirilen guncel PDF dosyalari
├── log/sart_checker.log        # Her calistirmada 1 satirlik ozet
├── sart_checker.service        # Systemd user servisi
├── sart_checker.timer          # Systemd zamanlayici
└── .gitignore
```

## Kurulum

### 1. Ilk calistirma ve referans olusturma

```bash
bash src/check.sh
cp recent/*.pdf known/
```

### 2. Systemd timer kurulumu

```bash
mkdir -p ~/.config/systemd/user
cp sart_checker.service sart_checker.timer ~/.config/systemd/user/

# ExecStart yolunu otomatik ayarla
sed -i "s|ExecStart=.*|ExecStart=$(pwd)/src/check.sh|" \
    ~/.config/systemd/user/sart_checker.service

systemctl --user daemon-reload
systemctl --user enable --now sart_checker.timer
```

## Durum Kontrolu

```bash
systemctl --user status sart_checker.timer
systemctl --user list-timers sart_checker.timer
journalctl --user -u sart_checker.service -n 50
cat log/sart_checker.log
```

## Calisma Mantigi

1. Teknofest sayfalarindan HTML cekilir, `cdn.teknofest.org` uzerindeki PDF linki ayiklanir.
2. PDF indirilip `recent/` klasorune kaydedilir.
3. `known/` klasorundeki referansla SHA-256 karsilastirilir.
4. Fark varsa tek bir masaustu bildirimi gonderilir.
5. `log/sart_checker.log` dosyasina 1 satirlik ozet yazilir.

Script, `recent/` dosyasini `known/` uzerine otomatik kopyalamaz. Manuel inceleme yapilana kadar her calistirmada bildirim gondermeye devam eder.

## Devre Disi Birakma

```bash
systemctl --user stop sart_checker.timer
systemctl --user disable sart_checker.timer
```
