# Balon Patlat 🎈

Flutter ile yazılmış Android bubble shooter oyunu.

- **300 bölüm / 30 bölge**, bölüm ilerledikçe artan zorluk, taş balonlar, ZOR ve ÇOK ZOR bölümler
- 4 güçlendirici (Gökkuşağı, Ateş Topu, Lazer, +5 Hamle), kombo ve yıldız sistemi
- Can sistemi, günlük şans çarkı, 7 günlük giriş serisi, günlük görevler
- Supabase: misafir + e-posta hesabı, bulut kayıt, haftalık lig, genel ve arkadaş sıralaması, takımlar (sohbet, can isteme, haftalık sandık)
- Google Play Billing (ürün tanımlı değilse test modu), AdMob ödüllü reklamlar
- Sentezlenmiş ses efektleri ve müzik (`tool/gen_audio.py`)

## Geliştirme

```
flutter pub get
flutter analyze
flutter test test/widget_test.dart test/screen_test.dart test/economy_test.dart test/levels_test.dart
flutter build apk --release
```

Zorluk dengesi (yavaş, bot oynar):
```
flutter test test/balance_test.dart --dart-define=LEVELS=20,25,30,50,100
```

## Belgeler
- Sunucu kurulumu: [supabase/KURULUM.md](supabase/KURULUM.md), şema: [supabase/schema.sql](supabase/schema.sql)
- Play Store yayın rehberi: [docs/PLAY_STORE.md](docs/PLAY_STORE.md)
- Gizlilik politikası: [docs/privacy/index.html](docs/privacy/index.html)

İmza anahtarı (`android/key.properties`, `*.jks`) depoya dahil değildir.
