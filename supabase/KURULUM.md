# Balon Patlat — Supabase Kurulumu

## 1. Proje
- supabase.com → New project → ad `balon-patlat`, bölge **Central EU (Frankfurt)**.

## 2. Şema
- SQL Editor → New query → `supabase/schema.sql` dosyasının **tamamını** yapıştır → **Run**.
- "Success. No rows returned" görmelisin. Dosya tekrar çalıştırılabilir.

## 3. Misafir girişi
- Authentication → Sign In / Providers → **Allow anonymous sign-ins** → AÇ → Save.

## 4. E-posta şablonları (6 haneli kod için)
Authentication → Emails → Templates:

**Change Email Address** şablonunun gövdesini şununla değiştir:
```html
<h2>Balon Patlat — Hesap Doğrulama</h2>
<p>Doğrulama kodun:</p>
<h1 style="letter-spacing:8px">{{ .Token }}</h1>
<p>Bu kodu oyundaki ekrana gir.</p>
```

**Reset Password** şablonunun gövdesini şununla değiştir:
```html
<h2>Balon Patlat — Şifre Sıfırlama</h2>
<p>Sıfırlama kodun:</p>
<h1 style="letter-spacing:8px">{{ .Token }}</h1>
<p>Bu kodu oyundaki ekrana gir. Sen istemediysen bu e-postayı yok say.</p>
```

> Not: Supabase'in ücretsiz e-posta servisi saatte birkaç e-postayla sınırlıdır.
> Yayına çıkmadan önce Authentication → Emails → SMTP Settings kısmından
> kendi SMTP servisini (örn. Resend, Brevo) bağla.

## 5. Uygulama
- Project Settings → API → **Project URL** ve **anon / publishable key**
- `lib/cloud/config.dart` içine yaz (service_role anahtarını ASLA koyma).

## Güvenlik notları
- Tüm tablolarda RLS açık; oyuncu sadece kendi kaydını/profilini değiştirebilir.
- Takım üyeliği, can yardımı ve takım sandığı sadece sunucu fonksiyonlarıyla (RPC) değişir.
- Puanlar istemciden gönderildiği için hileye karşı tam koruma yoktur; yayında
  büyürse puan doğrulaması sunucuya (Edge Function) taşınmalı.
