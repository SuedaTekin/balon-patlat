import 'package:balon_patlat/cloud/auth_screen.dart';
import 'package:balon_patlat/cloud/profile_screen.dart';
import 'package:balon_patlat/game.dart';
import 'package:balon_patlat/game_screen.dart';
import 'package:balon_patlat/home.dart';
import 'package:balon_patlat/level_intro.dart';
import 'package:balon_patlat/progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await Progress.load();
  });

  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
  }

  testWidgets('tüm sekmeler taşmadan çizilir', (t) async {
    await phone(t);
    await t.pumpWidget(const MaterialApp(home: HomeShell()));
    await t.pump();
    expect(find.text('BALON'), findsOneWidget);

    await t.tap(find.text('Etkinlik'));
    await t.pump();
    expect(find.text('GÜNLÜK ŞANS ÇARKI'), findsOneWidget);
    expect(find.text('GİRİŞ SERİSİ'), findsOneWidget);

    await t.tap(find.text('Görev'));
    await t.pump();
    expect(find.text('Günlük Görevler'), findsOneWidget);

    await t.tap(find.text('Mağaza'));
    await t.pump();
    expect(find.text('KUMBARA'), findsOneWidget);
    expect(find.text('Reklamları Kaldır'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('GÜNÜN FIRSATI'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('GÜNÜN FIRSATI'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Altın Paketleri'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.scrollUntilVisible(
      find.text('Galaksi'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Atıcı Temaları'), findsOneWidget);
    expect(find.text('Galaksi'), findsOneWidget);

    await t.tap(find.text('Takım'));
    await t.pump();
    expect(find.text('Çevrimiçi özellikler kapalı'), findsOneWidget);

    await t.tap(find.text('Sıralama'));
    await t.pump();
    expect(find.text('Çevrimiçi özellikler kapalı'), findsOneWidget);
    await t.tap(find.text('Rekorlarım'));
    await t.pump();
    expect(find.text('Bölüm Rekorların'), findsOneWidget);
  });

  testWidgets('profil ve giriş ekranları taşmadan çizilir', (t) async {
    await phone(t);
    await t.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await t.pump();
    expect(find.text('Çevrimiçi özellikler kapalı'), findsOneWidget);

    await t.pumpWidget(
      MaterialApp(key: UniqueKey(), home: const AuthScreen(welcome: true)),
    );
    await t.pump();
    expect(find.text('Hoş Geldin Paketi!'), findsOneWidget);
    expect(find.text('Google ile Devam Et'), findsOneWidget);
    expect(find.text('VEYA E-POSTA İLE'), findsOneWidget);
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(
      find.text('Misafir Olarak Oyna (Hızlı Başla)'),
      200,
      scrollable: list,
    );
    expect(find.text('Misafir Olarak Oyna (Hızlı Başla)'), findsOneWidget);
    await t.scrollUntilVisible(find.text('GİRİŞ YAP'), -200, scrollable: list);
    await t.tap(find.text('GİRİŞ YAP'));
    await t.pump();
    expect(find.text('Şifremi Unuttum?'), findsOneWidget);
    await t.tap(find.text('Şifremi Unuttum?'));
    await t.pump();
    expect(find.text('KOD GÖNDER'), findsOneWidget);
  });

  testWidgets('bölüm detay ve bilet ekranları taşmadan çizilir', (t) async {
    await phone(t);
    Progress.coins = 5000;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (ctx) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showLevelIntro(ctx, 40),
                    child: const Text('aç'),
                  ),
                ),
              ),
        ),
      ),
    );
    await t.tap(find.text('aç'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('BÖLÜM 40'), findsOneWidget);
    expect(find.text('ÇOK ZOR BÖLÜM'), findsOneWidget);
    await t.tap(find.text('Bomba'));
    await t.pump();
    expect(find.textContaining('Başlangıç maliyeti'), findsOneWidget);

    await t.pumpWidget(MaterialApp(key: UniqueKey(), home: const HomeShell()));
    await t.pump();
    await t.tap(find.text('Etkinlik'));
    await t.pump();
    await t.tap(find.text('Bilet'));
    await t.pump();
    expect(find.text('ALTIN BİLET'), findsOneWidget);
    await t.tap(find.text('Rozet'));
    await t.pump();
    expect(find.text('Başarımlar'), findsOneWidget);
  });

  testWidgets('can bitince oyna penceresi açılır', (t) async {
    await phone(t);
    Progress.lives = 0;
    Progress.lifeTs = DateTime.now().millisecondsSinceEpoch;
    await t.pumpWidget(const MaterialApp(home: HomeShell()));
    await t.pump();
    await t.tap(find.text('Oyna'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('CANIN KALMADI!'), findsOneWidget);
  });

  testWidgets('oyun ekranı taşmadan çizilir', (t) async {
    await phone(t);
    await t.pumpWidget(const MaterialApp(home: GameScreen(level: 1)));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('HAMLE'), findsOneWidget);
    expect(find.text('Gökkuşağı'), findsOneWidget);
  });

  testWidgets('sonsuz mod ekranı ve oyun sonu taşmadan çizilir', (t) async {
    await phone(t);
    await t.pumpWidget(
      const MaterialApp(home: GameScreen(level: 20, endless: true)),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('SONSUZ'), findsOneWidget);
    expect(find.text('SIRA'), findsOneWidget);
    final state = t.state(find.byType(GameScreen)) as dynamic;
    final BubbleGame g = state.game;
    g.score = 12345;
    g.state = GameState.lostDanger;
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('YENİ REKOR!'), findsOneWidget);
    expect(find.text('+61'), findsOneWidget);
    await t.tap(find.text('Tekrar Oyna'));
    await t.pump(const Duration(milliseconds: 50));
    expect(Progress.endlessBest, 12345);
    expect(Progress.endlessGames, 1);
    expect(g.state, GameState.playing);
    await t.pump(const Duration(seconds: 3)); // tanıtım zamanlayıcısı
  });

  testWidgets('kazanma ve kaybetme ekranları taşmadan çizilir', (t) async {
    await phone(t);
    await t.pumpWidget(const MaterialApp(home: GameScreen(level: 3)));
    await t.pump(const Duration(milliseconds: 50));
    final state = t.state(find.byType(GameScreen)) as dynamic;
    final BubbleGame g = state.game;

    g.movesLeft--; // bir atış yapılmış say
    g.state = GameState.lostMoves;
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('HAMLELER BİTTİ!'), findsOneWidget);
    expect(find.text('Çıkarsan 1 Can Kaybedilecek'), findsOneWidget);

    g.state = GameState.lostDanger;
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('KURTAR'), findsOneWidget);

    g.stars = 3;
    g.state = GameState.won;
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('SONRAKİ SEVİYE'), findsOneWidget);
    expect(Progress.unlocked, 4);
    expect(Progress.stat('win'), 1);
    expect(Progress.stat('star3'), 1);
    await t.pump(const Duration(seconds: 2)); // yıldız sesleri zamanlayıcısı
  });
}
