#!/bin/bash
# Whispr DMG Paketleme Betiği (Geliştirilmiş Sürüm)

set -e # Herhangi bir hatada dur

BASE_DIR="/Volumes/KaanUluer2TBLexar/Uluer_Solutions/whispr"
APP_NAME="Whispr.app"
DMG_NAME="Whispr.dmg"
TEMP_DIR="/tmp/whispr_build"
TEMP_DMG="/tmp/Whispr_Final.dmg"

echo "🚀 Whispr paketleme işlemi başlıyor (Lütfen bekleyin)..."

# Önceki artıkları temizle
rm -rf "$TEMP_DIR"
rm -f "$TEMP_DMG"
rm -f "$BASE_DIR/$DMG_NAME"

# Hazırlık klasörünü yerel diskte (/tmp) oluştur
mkdir -p "$TEMP_DIR"
echo "📦 Dosyalar kopyalanıyor..."
cp -R "$BASE_DIR/$APP_NAME" "$TEMP_DIR/"

# NOT: create-dmg --app-drop-link parametresi zaten otomatik olarak Applications kısayolunu oluşturur.
# Bu yüzden manuel sembolik link (ln -s) oluşturmuyoruz, bu hataya neden oluyordu.

# DMG oluşturma işlemini yerel diskte yap
echo "🔨 DMG oluşturuluyor..."
create-dmg \
  --volname "Whispr Installer" \
  --window-pos 200 120 \
  --window-size 600 300 \
  --icon-size 100 \
  --icon "$APP_NAME" 175 120 \
  --hide-extension "$APP_NAME" \
  --app-drop-link 425 120 \
  "$TEMP_DMG" \
  "$TEMP_DIR/"

# İşlem bitince DMG'yi harici diske taşı
echo "🚚 DMG dosyası taşınıyor..."
mv "$TEMP_DMG" "$BASE_DIR/$DMG_NAME"

# Temizlik
rm -rf "$TEMP_DIR"

echo "✅ Başarılı! Tertemiz DMG dosyanız hazır: $BASE_DIR/$DMG_NAME"
