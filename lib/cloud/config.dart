/// Supabase proje bilgileri (Project Settings → API).
/// anon/publishable anahtar uygulamaya gömülmek içindir; güvenliği
/// veritabanındaki RLS kuralları sağlar. service_role anahtarını ASLA buraya koyma.
const supabaseUrl = 'https://ssdrpfofahvpzcdddlig.supabase.co';
const supabaseAnonKey = 'sb_publishable_bSL5wJWtUnnE_fdrKmQ0dg_zhGsn_oT';

/// Gizlilik politikası (GitHub Pages).
const privacyUrl = 'https://suedatekin.github.io/balon-patlat-gizlilik/';

/// Google ile giriş: Google Cloud Console'daki **Web uygulaması** OAuth
/// istemci kimliği (….apps.googleusercontent.com). Boşken Google düğmesi
/// "henüz ayarlanmadı" der. Gizli anahtar (client secret) buraya KONMAZ.
const googleWebClientId =
    '112515500219-ueaggouadljhtf49u444mvc9uuj16cin.apps.googleusercontent.com';
