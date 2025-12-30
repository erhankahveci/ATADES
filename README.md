# ATADES (Ertu Mobile Uni)

Bu proje üniversite acil durum bildirim sistemidir.

## 🛠 Kurulum ve Ayarlar

Bu projeyi çalıştırmak için kendi API anahtarlarınızı eklemeniz gerekir.

### 1. Çevre Değişkenleri (.env)
Ana dizinde `.env` adında bir dosya oluşturun ve içine Supabase bilgilerinizi girin:

SUPABASE_URL=https://sizin-url.supabase.co
SUPABASE_ANON_KEY=sizin-anon-key

### 2. Google Maps API (Android)
`android/local.properties` dosyasını açın (yoksa oluşturun) ve API anahtarınızı ekleyin:

sdk.dir=/path/to/android/sdk
flutter.sdk=/path/to/flutter/sdk
MAPS_API_KEY=AIzaSyD...SIZIN_GOOGLE_MAPS_KEY...

### 3. Firebase Kurulumu
- Kendi Firebase projenizi oluşturun.
- `google-services.json` dosyasını `android/app/` içine atın.
- `GoogleService-Info.plist` dosyasını `ios/Runner/` içine atın.