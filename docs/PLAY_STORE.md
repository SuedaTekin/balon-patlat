# Balon Patlat — Play Store Yayın Rehberi

## Mağaza metinleri

**Uygulama adı (30):** Balon Patlat: Renk Avı

**Kısa açıklama (80):**
Nişan al, 3 aynı rengi eşleştir, patlat! 300 bölüm, takımlar ve haftalık lig.

**Tam açıklama:**

Renkli balonlarla dolu büyülü bir yolculuğa hazır mısın? 🎈

Balon Patlat; nişan al, at ve aynı renkten en az 3 balonu birleştirip patlat! Tavana bağlı balonları koparıp toplu halde düşür, kombo yap, yıldızları topla.

⭐ 300 BÖLÜM, 30 BÖLGE
Şeker Vadisi'nden Balon Tahtı'na uzanan haritada her bölge yeni bir macera. Bölümler ilerledikçe zorlaşır: daha fazla renk, daha az hamle, aşağı inen sıralar ve patlamayan taş balonlar!

🔥 ZOR VE ÇOK ZOR BÖLÜMLER
Cesaretini sına, ekstra altını kap.

💥 GÜÇLENDİRİCİLER
• Gökkuşağı — değdiği renge dönüşür
• Ateş Topu — yolundaki her şeyi yakar
• Lazer — bütün bir sırayı siler
• +5 Hamle — son anda kurtarır

👥 TAKIMLAR VE ARKADAŞLAR
Takım kur ya da katıl, sohbet et, takım arkadaşlarından can iste ve haftalık takım sandığını birlikte aç. Arkadaşlarını kodla ekle, haritada nerede olduklarını gör.

🏆 HAFTALIK LİG
Her hafta yeni bir yarış! Elmas lige yüksel, genel sıralamada zirveye çık.

🎁 GÜNLÜK ÖDÜLLER
Şans çarkı, 7 günlük giriş serisi, günlük görevler ve ücretsiz hediyeler.

☁️ BULUT KAYIT
İlerlemen otomatik yedeklenir; hesabını güvenceye al, cihaz değiştirsen de kaldığın yerden devam et.

Ücretsiz oyna! Oyun isteğe bağlı uygulama içi satın almalar ve ödüllü reklamlar içerir.

**Kategori:** Oyun → Bulmaca
**Etiketler:** Bubble shooter, Eşleştirme, Gündelik

## Grafikler
- Uygulama ikonu 512×512: `build/icon/play_store_512.png` (`flutter test test/icon_gen_test.dart --dart-define=ICON=1` ile yeniden üretilir)
- Öne çıkan grafik 1024×500: hazırlanacak
- Telefon ekran görüntüleri (en az 2, önerilen 4–8): harita, oyun, zafer, takım, mağaza, sıralama

## Yayın adımları
1. **Play Console hesabı** aç (bir kerelik 25 $): https://play.google.com/console
2. Uygulama oluştur → paket adı `com.balon.balon_patlat`.
3. **İmzalı paket:** PowerShell'de
   ```
   $env:BALON_PLAY_SIGN='1'; flutter build appbundle --release
   ```
   → `build/app/outputs/bundle/release/app-release.aab`.
   Yükleme anahtarı: `android/upload-keystore.jks` + `android/key.properties` (git'e girmez, **yedekle!**). Play App Signing'i açık bırak.
4. **Gizlilik politikası URL'si:** https://suedatekin.github.io/balon-patlat-gizlilik/
5. **Uygulama içi ürünler** (Para kazanma → Ürünler → Uygulama içi ürünler), hepsi tüketilebilir:
   | Kimlik | Ad | Önerilen fiyat |
   |---|---|---|
   | `starter_pack` | Başlangıç Paketi | ₺49,99 |
   | `coins_1000` | 1.000 Altın | ₺29,99 |
   | `coins_6000` | 6.000 Altın | ₺149,99 |
   | `coins_15000` | 15.000 Altın | ₺299,99 |
   | `infinite_6h` | 6 Saat Sonsuz Can | ₺39,99 |
   Ürünler tanımlanınca mağaza otomatik olarak gerçek ödemeye geçer (test modu yazısı kaybolur).
6. **AdMob:** https://admob.google.com → uygulama ekle → *Ödüllü* reklam birimi oluştur. Sonra:
   - `android/app/src/main/AndroidManifest.xml` → `APPLICATION_ID` (ca-app-pub-…~…)
   - `lib/ads.dart` → `rewardedUnitId` (ca-app-pub-…/…)
   Şu an Google'ın TEST kimlikleri var; değiştirmeden yayınlama.
7. **Veri güvenliği formu:**
   - Toplanan: E-posta (isteğe bağlı, hesap yönetimi), Kullanıcı kimlikleri, Uygulama etkileşimleri/oyun ilerlemesi, Kullanıcı içeriği (sohbet mesajları), Reklam kimliği (AdMob), Satın alma geçmişi (Google Play).
   - Aktarım sırasında şifreli: Evet. Kullanıcı silme isteyebilir: Evet (oyun içi Ayarlar → Hesabımı Sil).
8. **İçerik derecelendirmesi:** Şiddet yok; kullanıcılar etkileşime girebilir (takım sohbeti); dijital satın alma var → genelde PEGI 3 / "Herkes".
9. **Hedef kitle:** 13+ seç (sohbet ve reklam nedeniyle "çocuklara yönelik" işaretleme).
10. Önce **Dahili test** kanalına yükle, kendi hesabınla satın alma ve reklamı dene, sonra Üretim'e gönder.

## Yayından önce kalanlar
- [ ] Brevo SMTP bağlanıp e-posta kodlu hesap doğrulama açılacak (Supabase ücretsiz planda şablon değişmiyor)
- [ ] AdMob gerçek kimlikleri
- [ ] Öne çıkan grafik ve ekran görüntüleri
