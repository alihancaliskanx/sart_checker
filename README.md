# SART Checker (Şartname Takip Sistemi)

Teknofest yarışma şartnamelerini (PDF) otomatik olarak takip eden, değişiklik olduğunda KDE Plasma bildirimleri ile uyaran Bash script ve Systemd servisi.

## Özellikler

- **Web Scraping:** Belirtilen URL'lerden güncel PDF linklerini otomatik bulur.
- **Akıllı İndirme:** User-Agent spoofing ile bot korumasını aşar.
- **Değişiklik Tespiti:** SHA256 hash kontrolü ile dosya içeriğindeki en ufak değişikliği yakalar.
- **KDE Entegrasyonu:** `notify-send` ile kritik seviyede masaüstü bildirimi gönderir.
- **loglama:** Detaylı loglama (`log/sart_checker.log`) yapar.

## Kurulum

1. **Gereksinimleri Yükleyin:**
   Arch Linux için:

   ```bash
   sudo pacman -S curl grep sed awk libnotify
   ```

2. **Dizinleri Oluşturun & Yetki Verin:**

   ```bash
   chmod +x src/check.sh
   ```

3. **Systemd Servisini Aktif Edin:**
   Servis dosyalarını user dizinine linkleyin:

   ```bash
   mkdir -p ~/.config/systemd/user/
   ln -sf $(pwd)/sart_checker.service ~/.config/systemd/user/
   ln -sf $(pwd)/sart_checker.timer ~/.config/systemd/user/

   systemctl --user daemon-reload
   systemctl --user enable --now sart_checker.timer
   ```

## Kullanım

### İlk Çalıştırma (Referans Dosyaları Oluşturma)

Script ilk çalıştığında `known/` klasörü boş olduğu için uyarı verecektir.

1. Scripti manuel çalıştırın:
   ```bash
   ./src/check.sh
   ```
2. `recent/` klasörüne inen dosyaları kontrol edin.
3. Eğer dosyalar doğruysa, referans olarak `known/` klasörüne kopyalayın:
   ```bash
   cp recent/*.pdf known/
   ```
4. Artık script değişiklikleri bu dosyalara göre kıyaslayacaktır.

### Manuel Kontrol

İstediğiniz zaman scripti elle çalıştırabilirsiniz:

```bash
./src/check.sh
```

### Logları İzleme

```bash
tail -f log/sart_checker.log
```

## Yapılandırma

`src/check.sh` dosyasında `SOURCES` dizisini düzenleyerek yeni yarışmalar ekleyebilirsiniz.
Format: `URL|HEDEF_DOSYA_ADI`
