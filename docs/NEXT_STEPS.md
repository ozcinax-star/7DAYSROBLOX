# Sonraki aşama

Durum 30 Ekim 2026 itibarıyla. Önce [HANDOFF.md](HANDOFF.md) dosyasını oku. Tasarım kararları
[PLAN.md](PLAN.md) dosyasında; çelişki olursa PLAN.md geçerli.

## Neredeyiz

Proje PLAN.md yol haritasının **1. aşamasında (Prototip)**. Bu aşamanın kapısı henüz geçilmedi.

| Prototip hedefi | Durum |
| --- | --- |
| Harita | Gri kutu hedefinin ötesine geçildi: detaylı, kodla kurulan 2048×2048 harita |
| 1 zombi türü | Bitti: Humanoid yok, akış alanı, LOD, ses takibi, dalgalar |
| Stres testi aracı (80/120 zombi, FPS, tick) | Bitti |
| Gündüz-gece döngüsü | **Yapılmadı** (`DayNightService` boş iskelet) |
| Tehdit sisteminin ilk hesabı | **Yapılmadı** (`ThreatService` boş iskelet) |
| Tahta duvar | **Yapılmadı** (`BuildService` boş iskelet) |
| Kamera: omuz ve FPS geçişi | **Yapılmadı** |
| Kapı 1: 80 zombiyle orta seviye telefonda 30 FPS | **Ölçülmedi**; kullanıcı erteledi |
| Kapı 2: 3 kişilik test grubu "bir gece daha" diyor | Henüz yapılamaz |

Bu aşamada **yazılmayacaklar:** loot, crafting, perk, kayıt, monetizasyon. Yalnızca arayüzleri için
yer bırakılır.

## Kullanıcı kararı bekleyenler

Yeni oturum bu soruları işe başlamadan sormalı. Her sorunun ilk seçeneği benim önerim.

1. **Telefon testi ne zaman?**
   - Kural: 30 FPS tutmazsa diğer sistemlere geçilmez.
   - Harita büyüdü: 22,7 bin parça.
   - Öneri: oturumun başında yap.
   - Mümkün değilse: performansa etkisi az olan DayNight ve Threat servisleriyle devam et, ama ölçüm
     gelene kadar haritaya yeni detay ekleme.
2. **Oyuncu zombiye nasıl zarar verecek?**
   - Prototip görevinde silah yok. Ancak "bir gece daha" testi ve PLAN'daki "ilk 3 dakikada zombi
     öldürme" hedefi için gerekli.
   - Öneri: sunucu otoriter basit yakın dövüş (sopa veya balta). Ateşli silah ve silah sesi Gürültüsü
     sonraya kalır.
3. **Zombiler üst katlara çıkabilsin mi?**
   - Şu an çıkamıyorlar, bu yüzden üst kat güvenli sığınak oluyor ve oyun testini bozar.
   - Öneri: 3 kişilik testten önce merdivenleri yol bulmaya bağla (kat başına ızgara ve merdiven
     geçişleri).
   - Alternatif: test sırasında üst katları kapatmak.
4. **Edit modunda harita önizlemesi:** Play başlarken eski önizlemeyi kendiliğinden silen küçük bir
   değişiklik yapılsın mı? Bu son oturumda teklif edildi, yanıt gelmedi.
5. **Git yedeği:** Uzak depo yok. GitHub'da özel bir depo açılıp gönderilsin mi? Dışarıya açık bir adım
   olduğu için onay gerekir.

## Sıradaki işler

Sıra önerimdir; kullanıcı değiştirebilir. Her madde ayrı commit'lenir. Her maddeden sonra kullanıcıya
tam test adımları yazılır.

### 0. Araç zinciri

1. Kullanıcı `rokit install` ve `rojo plugin install` komutlarını kendisi çalıştırır. Otomatik modda
   bunlar engelleniyor.
2. Ardından şunlar ilk kez çalıştırılır:
   - `stylua --check src tests`
   - `selene src`
   - `lune run tests/run`
   - `rojo build -o build.rbxl`
3. Çıkan format ve lint sorunları düzeltilir.

**Bitti sayılır:** Dört komut temiz geçiyor. Testler Lune'da da 18/18. Rojo bağlanınca Studio'daki
kaynak diskle aynı.

### 1. Telefon FPS testi

Bu adımı kullanıcı yapar.

1. Studio'da *File → Publish to Roblox*.
2. Telefondan oyuna gir. Debug paneli `Config.Debug.AllowedUserIds` içindeki hesapta görünür.
3. Spawn 80'e bas, 30 sn bekle, FPS ve sunucu tick değerlerini oku.
4. Aynısını Spawn 120 için yap.
5. Değerleri kasabada ve ormanda ayrı ayrı oku.

**Bitti sayılır:** Kasabada ve ormanda, 80 zombiyle 30 FPS veya üstü.

Tutmazsa şu sırayla müdahale et:
1. Bina süs parçalarını birleştir. Kasalar ve kaplamalar çok parça tutuyor; hedef bina başına yarısı.
2. `StreamingTargetRadius` değerini düşür.
3. Orman yoğunluğunu azalt.
4. İstemci `RenderDistance` değerini kıs.

Her değişiklikten sonra yeniden ölç.

### 2. DayNightService

- **Saat:** `Config.DayNight` değerlerine göre `Lighting.ClockTime` döngüsü: 11 dk, %60 gündüz.
- **Durum:** Gün sayacı, faz (`Day` veya `Night`) ve horde gecesi bilgisi. Horde gecesi varsayılan
  7; lobi gelene kadar Config'den okunur.
- **Yayın:** Faz değişimi sunucudan istemciye gönderilir (RemoteEvent veya ReplicatedStorage
  özellikleri). İstemci Localization'daki `PhaseDay`, `PhaseNight` ve `HordeNight` anahtarlarıyla kısa
  bir bildirim gösterir.
- **Saf modül:** Saat hesabı (t anında faz, gün ve horde gecesi mi) Roblox'tan bağımsız bir modüle
  konur ve Lune testleri yazılır.
- **Debug komutu:** Fazı atlayan doğrulanmış bir komut eklenir (`DebugCommand` içine, örneğin
  `SkipPhase`).

**Bitti sayılır:** Testler geçiyor. Studio'da faz atlayınca ışık ve bildirim değişiyor, gün sayacı
artıyor.

### 3. ThreatService

- **Saf hesap modülü:**
  - Gürültü saniyede %5 söner. İz gün başına 3 puan söner.
  - `Tehdit = İz + Gürültü × 0.35`.
  - 5 kademe; eşikler `0/20/40/60/80`.
  - İlk 3 günde en fazla 3. kademe.
  - Lune testleriyle.
- **Servis:** `ThreatService.emit(kind, position)` Gürültü ekler ve bir ses noktası (`SoundPoint`)
  üretip `ZombieService.hearSound`'a verir.
  - Prototipte tek kaynak koşma (`Sprint`). Sunucu bunu karakterin hızından ve durumundan kendisi
    algılar; istemciye güvenmez.
  - İz, BuildService'in parça sayısından gelir (`PerBuildPart`). Işık ve ateş sonraki aşamada.
- **UI kuralı:** PLAN gereği ekranda kalıcı tehdit sayacı yok. Değerler yalnızca debug panelinde
  görünür.

**Bitti sayılır:**
- Testler geçiyor.
- Koşan oyuncunun ardından zombiler ses noktasına geliyor.
- Debug panelinde Gürültü, İz ve kademe görünüyor.
- İlk 3 günde kademe 3'ü geçmiyor.

### 4. BuildService: tahta duvar

- **Sunucu:**
  - `BuildRequest` remote'u (hücre x/z, yön 0–3).
  - Doğrulama:
    - Tipler, NaN ve sonsuz değerler, tam sayı hücre, harita sınırı.
    - Karakterden en fazla 24 stud uzaklık.
    - Hız sınırı: saniyede 6 istek ve 0,25 sn bekleme.
    - Dünya başına 2000 parça tavanı.
    - Hücre boş olmalı (başka parça, bina veya çarpışmalı obje yok).
  - Yükseklik `MapService.groundAt` ile alınır.
- **Parça canı ve zombi saldırısı:**
  - Parçanın canı 250.
  - Yol tıkalıysa zombi en yakın en zayıf parçaya saldırır (`AttackStructure`).
  - Parça yıkılınca yol bulma ızgarası güncellenir. Izgarada `StructureCellCost` zaten var.
- **İstemci:**
  - İnşa modu geçişi; ızgaraya oturan hayalet önizleme; mobil düğme.
  - PLAN kuralı: parçanın İz etkisi yalnızca bu önizlemede görünür.
- **Threat bağlantısı:** İz parça sayısından güncellenir.

**Bitti sayılır:**
- Duvar konuyor ve yıkılıyor.
- Zombiler kısa yoldan dolanıyor, uzun dolambaçta duvarı kırıyor.
- Uzaktan, NaN değerle ve spam ile yapılan istekler reddediliyor.
- Izgara hesabı için birim testleri var.

### 5. Kamera

- Omuz kamerası varsayılan: `Config.Camera` ofsetleri, zoom 4–14.
- FPS kamerasına geçiş Input Action System ile yapılır; mobilde düğme olur.
- Metinler Localization'dan gelir.

**Bitti sayılır:** PC'de ve mobil emülatörde geçiş çalışıyor. Zoom sınırı duvar arkasını
göstermiyor.

### 6. Oyuncu saldırısı ve üst kat yol bulması

Kararlar 2 ve 3'e göre yapılır.

- **Yakın dövüş:**
  - İstemci yalnızca "vurmak istiyorum" niyetini gönderir.
  - Sunucu menzil, açı ve bekleme süresini kontrol edip `ZombieService.damage` çağırır.
- **Üst kat yol bulması:** Kat başına yol bulma katmanı ve merdiven hücrelerinden katlar arası geçiş.

### 7. Prototip oyun testi

Bu adımı kullanıcı yapar.

- 3 kişiyle bir gece ve bir horde oynanır.
- Studio'da *Test → Local Server, 3 oyuncu* ile ya da yayınlanmış oyunda davetle yapılır.

**Bitti sayılır:** PLAN Kapı 2 sağlanıyor: test grubu "bir gece daha" diyor.

## Sonra: 2. aşama (Çekirdek döngü)

Bu aşama ancak 1. aşamanın kapısı geçilince başlar. İçerik PLAN.md'deki kapsam tablosundan:

- **Loot:** `LootService`. Binaların `Loot` özelliği hazır (`Food`, `Medical`, `Metal`, `Fabric`…).
  Envanterdeki her eşya kaynağını taşır (`Types.ItemSource`).
- **Crafting** ve **taş inşa kademesi.**
- **3 zombi türü:** Normal, Hızlı, Ses-duyarlı.
- **Horde gecesi:** oyuncu başına 20 zombi, eş zamanlı tavan 120, dalgalar. Dalga altyapısı
  ZombieService'te var.
- **Tehdit ipuçları:** inlemeler, ufukta toplanan sürü, karga sürüsü, telsiz anonsları.
- **Karşı önlemler:** susturucu, perde, ses yalıtımı, yem.
- **Kapı:** Test oyuncuları tehdidi bilerek yönetiyor (jeneratörü kapatıyor, perde çekiyor).

## Harita cilası

Düşük öncelikli; telefon ölçümü izin verirse yapılır.

- Bina parça sayısını 10 binin altına indirmek: kasa, kaplama ve süpürgelikleri birleştirmek.
- Yol çizgileri, bordürler, bahçe çitleri.
- Kasaba dışındaki binaların görsel kontrolü: Cabin, Shack, Barn, SawmillShed, FarmHouse. Ekran
  görüntüsü yalnızca kasabadan alındı.
- Kapıların açılıp kapanması ve kırılması (`DoorBreak` Gürültüsü). Bu 2. aşamaya bağlı.
