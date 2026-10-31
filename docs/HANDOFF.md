# Devir notu

Bağlamı olmayan yeni bir oturum işe buradan başlar. Sıradaki işler [NEXT_STEPS.md](NEXT_STEPS.md)
dosyasında, tasarım kararları [PLAN.md](PLAN.md) dosyasında, kod yapısı [../README.md](../README.md)
dosyasında. Bu not 30–31 Ekim 2026'daki iki uzun çalışma oturumunu (birkaç kez sıkıştırılmış) özetler.

## Proje ve roller

- Roblox için co-op zombi survival oyunu. Çekirdek fikir: oyuncu geliştikçe dünya daha tehlikeli olur.
- **Kullanıcı:** proje sahibi; oyunu test eder, son kararı verir.
- **Claude:** kodu yazar ve Studio MCP ile doğrular.
- **Bağlayıcı belge:** `docs/PLAN.md`. Kod ile plan çelişirse plan geçerlidir.
- **Dil:** Kullanıcıyla Türkçe konuş ("bunları türkçe yaz bana"). Kod, değişken adları, yorumlar ve
  UI metinleri İngilizce kalır.

## Kalıcı kurallar

Bu kurallar kullanıcının ilk görev tanımından gelir; aksi söylenene kadar geçerlidir.

- **Araçlar:** Rojo (dosya tabanlı geliştirme), Git, Luau `--!strict`, StyLua ve Selene. Paket
  gerekirse Wally.
- **Metin:** UI metinleri yalnızca `Shared/Localization` tablosundan gelir; kodda sabit metin olmaz.
- **Sayılar:** Tüm denge sayıları `Shared/Config` içindedir; kodda sihirli sayı olmaz.
- **Sunucu otoriter:** Hasar, tehdit ve inşa sunucuda hesaplanır. Her RemoteEvent tip, menzil ve hız
  sınırıyla doğrulanır.
- **Servis yapısı:** ThreatService, ZombieService, BuildService ve DayNightService
  ServerScriptService altında; ortak tipler ve Config ReplicatedStorage/Shared altında.
- **Commit:** Her mantıksal adım ayrı commit edilir. Mesaj şu satırla biter:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- **Test adımları:** Test gereken her adımda kullanıcıya ne yapacağını tam olarak yaz: Play mi Run mı,
  nereye gidecek, neye bakacak.
- **Belirsiz kararlar:** Önce PLAN.md'ye bak. Orada yoksa tahmin etme, kullanıcıya sor.
- **Creator Store varlıkları:** Ücretsiz bir varlık kullanılırsa içindeki tüm script'ler silinir;
  yalnızca mesh, doku ve ses alınır.
- **Telefon kapısı:**
  - Kural: 80 zombiyle orta seviye bir telefonda 30 FPS tutmazsa diğer sistemlere geçilmez.
  - Kullanıcı bu testi erteledi ("Bugün telefon testi yapılmayacak"); test hâlâ yapılmadı.
- **Studio:** Kullanıcı testler için Roblox Studio MCP kullanılmasını istedi ("Roblox Studio MCP kulan").
- **Kalite beklentisi:** Kullanıcı yüzeysel çözüm istemiyor ("adım adım düşünerek daha kapsamlı ve
  kaliteli"). Görsel işleri ekran görüntüsüyle, yerleşimi ölçümle doğrula; "olmalı" deme.

## Zaman çizelgesi

Tüm işler 30 Ekim 2026'da yapıldı; dal `master`, uzak depo (remote) yok.

### 1. Bölüm: prototip iskeleti ve zombiler

| Commit | Ne yapıldı |
| --- | --- |
| `eb9f8cb` | Proje iskeleti: Rojo projesi, Config, Localization, Types, boş servisler, lint ayarları, README |
| `51d7e1d` | Akış alanı (flow field) için NavGrid, zombi anlık görüntü protokolü, Lune testleri |
| `0320c08` | Düzen verisinden kurulan gri kutu harita |
| `37082d0` | Humanoid kullanmayan ZombieService, sunucu LOD'u, istemcide zombi çizimi |
| `32de89c` | Stres testi: debug paneli ve komutları (80/120 zombi, FPS, sunucu tick süresi) |
| `204fb20` | Test eden hesabın canlı sunucuda debug komutu kullanabilmesi (`Config.Debug.AllowedUserIds`) |
| `37946d8` | Harita ve zombiler algılanan zemine yerleşiyor; anlamsız kareler yerine tanınır objeler |

Kullanıcı geri bildirimleri:

- **"Zombiler ve karakter dünyanın altında spawn oluyor, birde mape anlamı belirsiz kareler koymuşsun."**
  - Neden: Place'teki hazır arazinin yüzeyi y=10'daydı.
  - Çözüm: zemin algılama eklendi, kareler tanınır objelerle değiştirildi.
- **"Zombiler geliyor, Studio'da lag yok. Bugün telefon testi yapılmayacak. Şimdi Map düzenlemeye geç.
  Plandakini aynen yansıtmaya çalış. Büyük ve detaylı bir map istiyorum."**
  - Kullanıcının seçimleri: 2048×2048 harita; girilebilir binalar, bazıları iki katlı; arazi kodla,
    oyun açılınca kurulur.

### 2. Bölüm: büyük harita ve binalar

| Commit | Ne yapıldı |
| --- | --- |
| `3d7b636` | Saf (Roblox API'si kullanmayan) modüller: harita düzeni (`WorldLayout`), gürültü, yükseklik alanı |
| `cfb5b81` | Arazi kurucu, bina kiti, objeler (PropKit), ASCII kat planı şablonları |
| `a130f3d` | Tüm harita sunucu açılışında kuruluyor; zombiler yeni haritaya uyarlandı |
| `c1b3984` | README'de dünya modülleri |
| `8159e10` | Arazi yükseklik alanının 2 stud üstünde kalıyordu (voxel doluluk formülü) |
| `a6f9e9b` | Kat planı okuyucu (`FloorPlan`), mobilya kurucuları, iç mekân stilleri |
| `4c3d48f` | Mobilyalı iç mekânlar: duvar kaplaması, kasalar, kapı kanatları, merdiven, tavan ve lambalar, çatılar, tabelalar; erişilebilirlik testleri |
| `3a8217e` | Bina altına zemin döşemesi (çimen tabandan çıkmasın), yürünebilir yükseklik (`groundAt`), kapı önlerinde lamba yok |
| `ea301cf` | README'de bina kuralları |

Kullanıcı geri bildirimleri:

- **"Kasabadaki yapıların bir kısmı hâlâ yer altına giriyor, binalar sadece dış cephe olarak
  tasarlanmış. … daha kapsamlı ve adım adım düşünerek daha kaliteli tasarla."**
  - Kök nedenler ve çözümleri:
    - Arazi 2 stud yüksekti (`8159e10`).
    - Çim süsü tabandan çıkıyordu; artık bina altına zemin döşeniyor.
    - Bazı ön cepheler kaldırımın üstündeydi; binalar kaydırıldı.
    - Lambalar kapı önünü kapatıyordu.
  - İç mekânlar sıfırdan tasarlandı.
  - Play modunda yapılan ölçümde 37 binada sorun çıkmadı.
- **"Mapi neden Studio ekranında göremiyorum?"**
  - Harita oyun başlayınca kodla kuruluyor; Edit modunda boş görünmesi normal.
  - Görmenin yolları: Run (F8), Play (F5) ya da aşağıdaki Edit önizlemesi.
  - Ben bir öneride bulundum: Play başlarken eski önizlemeyi kendiliğinden silen bir değişiklik. Kullanıcı
    henüz yanıt vermedi.

### 3. Bölüm: zombi davranışı ve görünümü (31 Ekim)

Kullanıcının isteği (özet): horde dışı zombiler The Walking Dead gibi yavaş ve sarsılarak yürüsün;
evlere girip çıksın, düşük ihtimalle evde spawn olsun; kollarını öne uzatarak saldırsın; yüzleri zayıf
ve çürümüş olsun; ten çoğunlukla beyaz, Afrika kökenli nüfus oranında siyah/esmer olsun; ölünce loot
bıraksın. Ardından ağaç kesme, yerden taş, kırılabilir kaya (kasabada yok), kazılabilir zemin ve 7DTD'ye
yakın crafting (taş balta, kazma, kürek) gelsin.

Kullanıcının seçimleri: üst kat yol bulması "şimdi"; Odun + Kereste; 7DTD gibi bitki lifi; zombi loot
torbası yaklaşık %20. Bu kararlar ve telefon kapısının ertelenmesi PLAN.md'nin Kararlar tablosunda.

| Commit | Ne yapıldı |
| --- | --- |
| `c2f4b14` | Yavaş yürüyüş, eve girip çıkma (bina başına kapı akış alanları), bina içinde uyuyan zombi, saldırı öncesi bekleme, yükseklik kontrolü, vurulunca sendeleme; `damage`, `onDied`, `getPosition` |
| `64346f7` | 17 parçalı zombi rig'i (`ZombieRig`), id'den türeyen görünüm (`ZombieLook`), prosedürel topallama, ölünce yığılma, mesafeye göre detay |
| `a776e7c` | Üst katlar için ikinci yol bulma katmanı ve merdiven geçişleri; kovalama, ses, ev ziyareti ve spawn'lar iki katı da kullanıyor |
| `79274bd` | Koyu ten çürümeyle griye dönmüyor; gözler donuk, yara eğik yırtık |
| `d593fdf` | Saldıran zombi en yakın oyuncuya dönüyor; debug panelinde "Kill nearest zombie" (`ZombieService.nearest` + `damage`) |

### 4. Bölüm: 7DTD ana referans ve envanter (31 Ekim)

Kullanıcı kapsam kuralını değiştirdi: ana referans 7 Days to Die; planın özgün kararları farkı belirler
(PLAN, Kapsam). İki araştırma ajanı 7DTD'nin oyun XML'lerinden (1.0, 2.6, 3.2) tarif, yığın ve alet
sayılarını çıkardı; sonuçlar `docs/REFERENCE_7DTD.md` dosyasında (başında bizim uyarlamalarımızın
tablosu var).

| Commit | Ne yapıldı |
| --- | --- |
| `c6c62e3` | PLAN ve NEXT_STEPS: 7DTD ana referans |
| `ec74896` | Saf `Shared/Inventory` (kaynak taşıyan yığınlar, aletler yığılmaz ve aşınır), `Config.Items` ve `Config.Inventory` (7DTD: 10 + 45 slot, ham kaynak yığını 6000), 5 test |
| `383297a` | `InventoryService` (sunucu sahibi, kare başına bir kopya, doğrulanmış ve hız sınırlı taşıma/seçme), elde görünen alet (`Modules/HeldItems`), debug `GiveKit` |
| `859c573` | Alet kemeri ve sırt çantası arayüzü (`InventoryController`), debug panelinde "Give test items" |
| `7234e9e` | `Inventory.add` kesirli, NaN ve sonsuz sayıları reddediyor (toplama adımı kesirli verim üretecek) |
| `6be883f` | Vuruş: `ToolService` + `Shared/Melee` + `ToolController`; zombi canı 125 ±%15; debug "Spawn 1"; Tab kaldırıldı |
| `1b0fb72` | Zombi 1,5 sn'de 8 vuruyor (7DTD) |
| `a163ce0` | `REFERENCE_7DTD.md` ve vuruş adımının belgeleri |

### 5. Bölüm: toplama (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `bf7164e` | Saf `Shared/Harvest` (7DTD verim formülü), `Config.Harvest` (düğümler, ağaç boyları), aletlere malzeme çarpanları, 4 test |
| `4b47110` | Haritada ot, yerdeki taş, çalı (`Map/Undergrowth`) ve taş ocağı kayaları (`Map/Quarry`); ağaç, çalı ve kayalar `MapService.getHarvestables()` listesinde; yapraklar artık raycast almıyor |
| `1102479` | `MapService.getMap/getHeightGrid` tek değer döndürüyor (assert'in mesajı tabloya karışıyordu) |
| `aaa870f` | `HarvestService`: vuruşla toplama, ortak hasar, ağaç devirme, yol bulma hücrelerini açma (`ZombieService.reopenArea`), yerdeki taşa E ile alma; dünya vuruşu artık ot ve çalıya da değiyor |
| `94e90be` | Alınan eşya bildirimi (`PickupFeedController`) ve devrilme animasyonu (`TreeFallController`) |

### 6. Bölüm: crafting (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `5cf6af2` | `Config.Recipes` (taş balta / kürek 7DTD, taş kazma ve kereste bizim), `Config.Crafting` (sıra, 4 slot, malzeme süreleri), taş aletlere taşla tamir; saf `Shared/Crafting`, 5 test |
| `f3e58ab` | Alet kemeri slotları 0×0'dı (2. adımdan beri; liste düzeni çocuğa boyut vermiyor); artık boyutlanıyor |
| `410cc9b` | `CraftingService`: 4 işlik kuyruk, malzeme kuyruğa alınırken düşer, iptal iade eder, sığmayan ürün kuyrukta bekler, iadesi sığmayan iptal reddedilir; tamir aynı kuyrukta, alet eski slotuna döner. `Inventory.putSlot/addAll`, 1 test |
| `459404d` | Crafting paneli (sırt çantasının sağında) ve sırt çantasında Repair düğmesi |
| `a86be35` | Oyuncu çıktıktan sonra gelen crafting isteği kuyruk kaydı açmıyor |

### 7. Bölüm: zombi loot'u (31 Ekim)

Kullanıcı 31 Ekim akşamı "her iş bitince sıradaki eksiği kapat" dedi ve ertesi gün öğlene kadar
yazmayacağını söyledi. Referans PLAN ve 7DTD; çelişkide mantıklı olan seçilip kaydedilir.

| Commit | Ne yapıldı |
| --- | --- |
| `74caafe` | Hurda demir ve kumaş eşyaları, `Config.Loot`, saf `Shared/Loot` (enjekte edilen rastgele kaynak), 2 test |
| `8c39766` | `LootService`: zombi ölünce ~%20 torba, 1 sn basılı tutarak arama, ömür 20 dk, en fazla 60 torba |
| `531edd1` | Envantere sığmayan toplama eşyası ve crafting iadesi oyuncunun ayağına torba olarak düşüyor |

### 8. Bölüm: gündüz-gece (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `b97f319` | Saf `Shared/DayClock`, `DayNightService` (sunucu saatini ReplicatedStorage özelliğiyle yayar), `DayNightController` (ışık, saat etiketi, horde gecesinde kızıl ton), gece saldırı aralığı 1,1 sn, debug "Skip to next phase", 2 test |

### 9. Bölüm: tehdit, ortam nüfusu, horde gecesi (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `9ce4af5` | Horde zombisi: dışarıda doğar, görmeden en yakın canlı oyuncuyu kovalar, mesafeyle bırakmaz, 11 stud/sn koşar; `endHorde`, `forEach`, `queued`; sınırı bekleyen kuyruk dalga sayacını korur |
| `9944473` | Saf `Shared/Threat` (gürültü sönmesi, İz, kademe ve ilk gün sınırı, ortam hedefi, horde dalgaları), `ThreatService` (ölçerler, ortam nüfusu, horde dalgaları), ağaç ve kaya vuruşu ses yapar, 4 test |
| `adcf548` | Debug panelinde tehdit ve otomatik spawn satırları; Spawn ve Clear yöneticiyi durdurur, "Auto spawn on/off" düğmesi |

### 10. Bölüm: inşa (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `c95e07a` | Ahşap çerçeve, ahşap blok ve merdiven (7DTD sayıları), tarifleri, saf `Shared/BuildGrid` (hücre, hedef hücre, zombiyi engelleme, yol maliyeti, destek kaybı), `Inventory.consume`, 3 test |
| `7574e5f` | `BuildService` (sunucuda yerleştirme doğrulaması, taş baltayla yükseltme ve tamir, hasar, çökme, İz); zombiler en zayıf duvardan yol bulur ve önündeki bloğu kırar; itme ve spawn bloğun içine zombi koymaz |
| `123b9d8` | Eldeki blok "use" ile konur; `BuildController` yarı saydam önizleme (yeşil / kırmızı) |

### 11. Bölüm: hayatta kalma (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `c46dd6a` | Boş `Health` script'i (`src/character`, StarterCharacterScripts): Roblox'un saniyede %1 can yenilenmesi kapandı |
| `3b49494` | `ToolService.onUse(itemId, cb)` eşya başına kullanım; `onFistUse` (göl suyu), `setStaminaGate` (her vuruş) |
| `1d61b94` | Saf `Shared/Vitals` (7DTD sayıları, 4 test), `SurvivalService`, HUD + koşma (`SurvivalController`), konserve / su / bandaj, gölden içme, ölüm torbası |
| `b74fe9c` | Koşan oyuncu 2 sn'de bir Sprint gürültüsü çıkarır |

### 12. Bölüm: bina kapları (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `91a33a8` | 174 mobilya aranabilir kap (`Loot.rollContainer`, 1 test); ilk aramada dolar, 7 oyun günü sonra yeniden; duvar arkasından arama reddedilir; ölüm torbaları torba tavanından muaf |

## Mevcut durum

| Alan | Durum |
| --- | --- |
| Harita (`MapService` + `World/*`) | Çalışıyor. 2048×2048; orman ve küçük kasaba, göl, taş ocağı, telsiz tepesi, çiftlik, kereste atölyesi, hurdalık. Arazi, 37 bina, yollar, sokak eşyaları, orman ve toplanabilir alt bitki örtüsü sunucu açılışında kodla kuruluyor. Toplanabilir her nesne `getHarvestables()` listesinde: düğüm adı (`Config.Harvest.Nodes`) ve her açılışta aynı kalan bir id (ileride dünya kaydı için). |
| Binalar | 15 şablon. Mobilyalı odalar, iki katlılarda merdiven, açılmış kapılar, tabelalar. Her model `Template`, `Loot` (`Food`, `Medical`, `Metal`, `Fabric`…), `Floors` ve `Region` özelliklerini taşıyor; loot sistemi bunları kullanacak. |
| Zombiler (`ZombieService`) | Çalışıyor. Humanoid yok. Akış alanıyla yol bulma, görerek kovalama, ses noktasına gitme, gezinme, eve girip çıkma, merdivenle üst kat, bina içinde uyuyan zombi, saldırı öncesi bekleme, sendeleme, dalgalı spawn, sunucu LOD'u (yakın 10 Hz, uzak 2 Hz), anlık görüntü yayını. Horde zombisi görmeden en yakın oyuncuyu kovalar ve koşar. API: `spawn(adet, horde?)`, `endHorde`, `forEach`, `queued`, `remove`, `clear`, `damage` (öldürünce true), `onDied`, `getPosition`, `hearSound`, `getStats`, `getNavGrid`, `reopenArea` (kalkan parçaların altındaki hücreleri arazi değerine döndürüp hâlâ duranları yeniden kapatır). |
| Envanter (`InventoryService` + `Shared/Inventory`) | Çalışıyor. 10 slot alet kemeri + 45 slot sırt çantası. Yeni eşya önce sırt çantasına girer. Her yığın kaynağını taşır; farklı kaynaklar birleşmez. Seçili slottaki eşya sağ elde görünür (stilize model; sallama pozu yok). API: `get`, `changed`, `give`, `room`, `take` (hep ya da hiç), `peekSlot`, `takeSlot`, `putSlot`, `giveBack` (hep ya da hiç iade), `count`, `getHeld`, `wearHeld`, `onHeldChanged`. Oyuncu boş elle başlar (`StartingItems` boş). |
| İstemci | `ZombieRenderController` + `Modules/ZombieRig`: 17 parçalı rig, prosedürel yürüyüş, interpolasyon, LOD, ceset; `flinch(id)` hazır. `InventoryController`: alttaki alet kemeri, I / gamepad Y ile sırt çantası, mobilde Bag düğmesi; tıkla-seç-bırak taşıma, sağ tık veya Split ile yarım yığın; 1–0 tuşları ve L1/R1 ile slot seçimi. `ToolController`: sol tık / gamepad R2 / mobilde Hit düğmesi; basılı tutunca aletin hızında vurur; nişan imlecin (serbest fare) ya da ekran ortasının altındaki noktaya; sağ omuzda prosedürel sallama; kırık alette uyarı. `PickupFeedController`: sağ kenarda "+N eşya" satırları (aynı eşya aynı satırda toplanır), sığmayanlar kırmızı. `TreeFallController`: devrilen ağacı yerelde oyuncudan uzağa yatırır ve soldurur. `CraftingController`: sırt çantası açıkken sağında crafting paneli (tarif satırları, sahip olunan / gereken, sayı, Craft; altta 4 işlik kuyruk ve geri sayım, tıklayınca iptal). Sırt çantasında Repair düğmesi seçili hasarlı aleti tamire yollar. `DebugOverlayController`: FPS, tick süresi, zombi sayısı, (debug yetkisiyle) tehdit ve otomatik spawn satırları; Spawn 1/80/120, Noise, GodMode, Kill, Give test items, Clear, Skip to next phase ve Auto spawn on/off düğmeleri. Spawn ve Clear otomatik spawn'ı kapatır. |
| Debug | Remote: `DebugCommand`. Yalnızca Studio'da veya `Config.Debug.AllowedUserIds` listesindeki hesaplarla çalışır (`11911303584` test eden hesap). Doğrulanır ve hız sınırlıdır. |
| Gündüz-gece (`DayNightService` + `Shared/DayClock`) | Çalışıyor. Döngü 11 dk, %60 gündüz (06:00–18:30), kalanı uzun gece. Dünya 1. gün 08:00'de başlar. Sunucu yalnızca 1. günün şafağının sunucu saatini ve horde aralığını ReplicatedStorage özelliği olarak yayar; istemci saati her karede kendisi hesaplar. Her 7. gece horde gecesi (`HordeNightDefault`; lobi seçimi gelince 5–10). API: `getState`, `isNight`, `isHordeNight`, `onPhaseChanged(faz, gün, horde)`, `skipPhase` (debug). Zombiler gece 1,1 sn'de, gündüz 1,5 sn'de vurur (7DTD). İstemci: `DayNightController` güneşi, parlaklığı ve ortam ışığını saate göre ayarlar; sağ üstte "Day N  HH:MM" (horde gününde kırmızı) ve horde gecesinde "Horde night" etiketi ile kızıl ton. |
| Tehdit ve nüfus (`ThreatService` + `Shared/Threat`) | Çalışıyor. Gürültü saniyede %5 söner; İz kaynakların toplamına hemen çıkar, düşünce günde 3 puan iner (kaynak henüz yok; `setTraceSource` inşa adımını bekliyor). Tehdit = İz + Gürültü × 0,35; 5 kademe (0/20/40/60/80); ilk 3 günde en fazla 3. Ağaca ve kayaya vuruş 1,5 gürültü ve 35 stud'luk ses, devrilen ağaç 6 / 70 stud; aynı oyuncunun 8 stud ve 4 sn içindeki vuruşları aynı ses noktasını tazeler. Ortam nüfusu: canlı oyuncu başına gündüz 6, gece 10 zombi, kademe çarpanı 1–1,6, en fazla 80; 2 sn'de bir en fazla 3 kuyruğa alınır, her oyuncudan 270 stud'dan uzak boştaki zombiler 4'er silinir (istemci 260'ta çizmeyi bırakır). Horde gecesi: oyuncu başına 20 zombi, gecenin ilk %60'ına yayılan 4 dalga; ortam spawn'ı durur; şafakta kalanlar sıradan zombiye döner. Oyuncu tehdidi görmez; yalnızca debug paneli. API: `emit(tür, konum, oyuncu?)`, `setTraceSource`, `getTier`, `setDirectorEnabled`, `getStats`. |
| Hayatta kalma (`SurvivalService` + `Shared/Vitals`) | Çalışıyor. Can (Humanoid), dayanıklılık, yemek, su; hepsi 100 ve sunucuda. Her 0,5 sn: yemek oyun günü başına 30, su 40 düşer; dayanıklılık saniyede 10 dolar (su bandı: su ≥%50 ×1, ≥%25 ×0,5, altı ×0,25, 0'da hiç), dolan her puan 0,00408 yemek ve 0,00453 su yer; doğal can günde 60 (×su bandı), iyileşen her can 0,06 su. Açlık / susuzluk kademeleri %50 / %25 / %2'de (çıkış %52 / %27 / %4), her biri dayanıklılığın %20 / %40 / %60'ını bloklar ve ikisi toplanır (taban 10). Son kademede 2,2 sn'de 0,25 can (ikisi toplanır, gerçek zaman), doğal iyileşme yok. Vuruş aletin dayanıklılığını ister ve harcar. Koşma: Shift basılı, gamepad L3 veya dokunmatikte Run düğmesi aç/kapa; sunucu WalkSpeed 24 yapar, hareket ederken saniyede 4,5 düşer, 0'da biter, ancak 25'te yeniden başlar; 2 sn'de bir Sprint gürültüsü. Zıplama 20 (sunucu kökün yükselişinden sayar). Elde yiyecek / içecek / ilaç "use" ile kullanılır (1 sn): yemek saniyede 1 girer, can 0,5/sn (bandaj 2/sn). Boş el göl suyuna "use": +10 su, −5 can. Ölünce taşınan her ham kaynağın (odun, küçük taş, lif, hurda demir, kumaş) yarısı 5 dk'lık torbaya düşer, istatistikler doğunca dolu. Oyuncu öznitelikleri: `Stamina`, `StaminaCap`, `Food`, `Water`, `Hunger`, `Thirst`. Debug: `SetFood`, `SetWater`. |
| İnşa (`BuildService` + `Shared/BuildGrid`) | Çalışıyor. 4 stud'luk küp ızgara; sütunları yol bulma ızgarasıyla aynı. Elde Wood Frame veya Wood Ladder varken "use" (sol tık, R2, Hit) bloğu koyar: sunucu baştan nişan yönünde 24 stud ışın atar, vurduğu bloğun yanına ya da yüzeyin hemen üstündeki hücreye koyar (zeminde blok toprağa en fazla bir hücre gömülür, havada durmaz). Ret: dolu hücre, harita parçası (duvar, ağaç, tabela), karakter veya zombi içinde, su, oynanmaz alan, kasaba binası tabanı, 2000 blok, zemin ya da komşu blok desteği yok. Taş balta bloğa vurunca hasar vermez: hasarlıysa vuruş başına 100 can tamir eder (7DTD'nin tam tamir için 3 odununun payı, yukarı yuvarlanmış), çerçeveyi 3 vuruşta 4 keresteyle ahşap bloğa çevirir. Diğer aletler ahşap çarpanıyla hasar verir. Yere bağlantısı kopan bloklar düşer (7DTD yapısal destek, yatay açıklık sınırı yok). Zombiyi engelleyen sütun (zeminden 2 ile 6 stud arası) yol bulmada blok canına göre 2–8 maliyetli hücre olur; kovalayan ya da sese giden zombi önündeki en zayıf bloğa 7 hasar vurur (1,5 / gece 1,1 sn). Merdiven `TrussPart`: oyuncu tırmanır, zombiyi engellemez. Bloklar zombi görüşünü keser, loot torbası üstlerine düşer, her blok İz'e 0,04 ekler. Kayıt yok. API: `getCount`, `clear` (debug). |
| Kamera (omuz/FPS) | **Yok.** Localization anahtarları (`CameraShoulder`, `CameraFirstPerson`) ve `Config.Camera` hazır. |
| Vuruş (`ToolService` + `Shared/Melee`) | Çalışıyor. İstemci yalnızca nişan yönünü yollar. Sunucu: birim vektör, hız sınırı (4/sn), aletin 7DTD aralığı (60/APM + 0,1 sn, %12 tolerans), hedefi kendi baş konumundan seçer: menzildeki en yakın zombi (silindir + baktığı yöne eğik kafa küresi), arada duvar varsa vurmaz. Hasar 7DTD: yumruk 5, taş balta 6, taş kürek 9, taş kazma 7; kafaya ×2. Alet yalnızca isabette 1 aşınır; 0'da kullanılamaz. Dünyaya isabet `onWorldHit` dinleyicilerine gider (toplama). Oyunculara vuruş yok (PvP lobi seçeneği gelince). |
| Toplama (`HarvestService` + `Shared/Harvest`) | Çalışıyor. 7DTD formülü: verimin üçte ikisi nesnenin toplam hasarıyla orantılı olarak vuruşlarda, üçte biri kıran vuruşta; iyi alet yalnızca hızlandırır. Hasar = aletin blok hasarı × malzeme çarpanı, tam sayıya kesilir, en az 1. Aynı nesneye vuran herkes aynı hasarı paylaşır. Ağaç: 300/30, 600/70, 900/110, 1200/150 (can/odun, boy ölçeğe göre). Çalı 1–3 odun, ot 2 lif, yerdeki taş 1 taş (E ile de alınır), kaya 400 can / 22 taş. Devrilen ağaç çarpışmayı hemen bırakır, altındaki yol hücreleri açılır, 3,5 sn sonra silinir. Hiçbir şey yeniden çıkmaz (7DTD). Sığmayan eşya kaybolur ve kırmızı satırla bildirilir (loot torbası gelince yere düşecek). |
| Crafting (`CraftingService` + `Shared/Crafting`) | Çalışıyor. 7DTD sırt çantası crafting'i: 4 işlik kuyruk, yalnızca ilk iş sunucu saatiyle ilerler (çanta kapalıyken de). Süre = Σ adet × malzeme süresi (odun, taş, lif 0,2 sn; diğerleri 1 sn), tarif kendi süresini verirse o. Malzemeler kuyruğa alınırken kaynaklarıyla düşer; iptal kalanı iade eder. Sığmayan ürün kuyrukta "No room" ile bekler. İadesi sığmayan iptal reddedilir ve kırmızı satırla bildirilir (loot torbası gelince yere düşebilir). Tamir: hasarlı taş alet + gereken taş (taş başına 300 dayanıklılık, 0,5 sn) kuyruğa girer; alet boşsa eski slotuna döner. Kuyruk oyuncu çıkınca kaybolur (kayıt yok). Tarifler: taş balta, taş kürek, taş kazma, kereste. |
| Loot (`LootService` + `Shared/Loot`) | Çalışıyor. Ölen zombi %20 ihtimalle torba bırakır (7DTD %2–4). Torba: bir ortak seçim (3–10 hurda demir, 2–6 kumaş, 5–15 küçük taş, chili veya köpek maması konservesi, şişe su, bulanık su, ilk yardım bandajı) ve %15 ihtimalle %30–100 dayanıklılıkta taş alet. 18 slot, 20 dk ömür (7DTD 1.x), dünyada en fazla 60 torba (en eski silinir). E'yi 1 sn basılı tutunca sığan alınır, kalanı torbada kalır; boşalan torba silinir. Sunucu torbanın varlığını, canlı karakteri, mesafeyi, basılı tutma süresini ve hızı yeniden denetler. `LootService.drop(konum, yığınlar, birleştir)` başka servislerden de kullanılır: sığmayan toplama eşyası ve crafting iadesi oyuncunun ayağına düşer, 6 stud içindeki torbaya eklenir. Torba içeriği yalnızca sunucuda. |
| Bina kapları (`LootService`) | Çalışıyor. `Config.Loot.ContainerFurniture` 11 mobilyayı 6 kap türüne bağlar (buzdolabı, dolap, raf, gardırop, ilaç dolabı, depo); haritada 174 kap. Her mobilyanın önünde (pivot önü, yarı yükseklik, en çok 3 stud) basılı tutulan "Search" istemi; görüş hattı kontrolü istemde kapalı, sunucu baştan noktaya ışınla duvarı kontrol eder. İlk aramada sunucu zar atar (her atış %25–35 boş; binanın `Loot` özelliği kap türünün `Bonus`'una uyarsa bir atış daha), 7 oyun günü sonra yeniden. Kap bütün oyuncular için ortak; boşalınca "(empty)" yazar. Mobilya modellerinin `WorldPivot`'u hücre tabanı, önü −Z. |
| Kazı | **Sırada** (NEXT_STEPS). `ToolService.onWorldHit` kazı için, `ZombieService.onDied` loot için, `InventoryService.give/take/wearHeld` hepsi için hazır. |
| Perk, kayıt, monetizasyon | Bilerek yazılmadı. |

### Ölçümler

Ölçümler 30–31 Ekim 2026'da PC'de, Studio içinde alındı. Telefonda ölçüm yok.

- **Testler:** 59/59 geçiyor (NavGrid 8, HeightField 3, Buildings 5, ZombieProtocol 3, ZombieLook 3,
  Inventory 6, Melee 5, Harvest 4, Crafting 6, Loot 3, DayClock 2, Threat 4, BuildGrid 3, Vitals 4).
  Testler yalnızca Studio düzeneğiyle çalıştırıldı; Lune ile hiç çalıştırılmadı.
- **Zombi performansı:** 80 zombiyle tick ortalaması 0,04–0,17 ms, en kötü tick genelde 1,3–1,8 ms
  (bir kez 3,9 ms). Zombi başına 17 parça.
- **Eve girme:** Kasabada 80 zombinin 22–24'ü (%28–30) herhangi bir anda bina içinde.
- **Üst kat:** Oyuncu House04'ün üst katında ve gürültü yaparken 60 sn'de 46 zombi yanına ulaştı;
  ForceField kalkınca 0,32 sn'de 13 vuruş geldi. Oyuncu dışarı çıkınca üst kattaki 35 zombiden 34'ü
  40 sn'de indi. TownHall'un düz çatısındayken merdivende takılan zombi yok.
- **Saldırı yönü:** Oyuncunun yanındaki 11 zombinin 9'u ona 0–3° dönük; kalan ikisi hâlâ yürüyordu.
- **Ölüm:** Kill sonrası ceset 1,5 sn içinde yığılıyor (baş zeminden 0,8 stud yukarıda), yaklaşık
  6,8 sn sonra kayboluyor. `onDied` dinleyicisi henüz yok; loot adımında doğrulanacak.
- **Harita kurulumu:** Play'de 2,6 sn, Edit önizlemesinde 4,0–4,4 sn (alt bitki örtüsüyle 4,7 sn).
- **Parça sayısı:**
  - Haritanın tamamı 37.275 parça: alt bitki örtüsü öncesi 22.748, ot / yerdeki taş / çalı 14.492,
    taş ocağı 35. Toplanabilir nesne 9.099: 4.352 ot, 1.137 yerdeki taş, 704 çalı, 182 kaya, 2.724
    ağaç (her boydan ~%25). Play'de PC istemcisi 60 FPS.
  - Binalar 11.395 parça: 8.115 süs (çarpışmasız), 3.280 çarpışmalı. Kendi koyduğum yaklaşık 10.000
    hedefinin üstünde.
  - Haritada 114 sokak lambası var.
- **Yol bulma:** 923 zemin hücresi denetlendi, sorun çıkmadı.
- **Bina zemin taraması:** Taban içi her 2 stud'da, dışı 1–12 stud mesafede halka hâlinde tarandı. 37 binanın hiçbirinde arazi
  tabandan çıkmıyor, duvar dibine yükselen yamaç ve alt kısımda boşluk yok, taban altında çimen yok.
- **Envanter (Play, 31 Ekim):** GiveKit eşyaları sırt çantasının ilk 6 slotuna koydu. Fareyle
  baltayı 1. slota taşıma, sağ tıkla 50 odunu 25/25 bölme çalıştı. Elde balta bir tane göründü; boş
  slot seçilince kalktı. Hatalı istekler (NaN, sonsuz, metin, tablo, aralık dışı, kesirli, yığından
  büyük sayı) reddedildi. 100 taşıma isteğinin 20'si geçti (hız sınırı 20/sn).
- **Vuruş (Play, 31 Ekim):**
  - Toolbelt slotuna tıklamak slotu seçti, vuruş yapmadı. Dünyaya tık 1 vuruş; 3 sn basılı tutmak
    yumrukla 5 vuruş daha.
  - Tek zombi: 3 gövde + 13 kafa vuruşuyla (15 + 130 hasar) öldü. Kalabalıkta bir zombi 3 gövde +
    10 kafa (115), baltayla bir başkası 10 kafa + 2 gövde (132) ile öldü. Hepsi 125 ±%15 ile tutarlı.
  - Balta: 39 isabet → dayanıklılık 250'den 211'e; havaya 12 vuruş aşındırmadı.
  - Duvar arkasındaki tek zombiye 4 vuruşun 0'ı geçti; duvar kalkınca 4'ü de geçti.
  - Hatalı nişanlar (NaN, sonsuz, sıfır, 50 uzunluk, metin, tablo, CFrame, nil, sayı) reddedildi.
    3 sn'de 51 istekten 5'i kabul edildi.
  - Zombi saldırısı: her 1,53 sn'de 8 hasar.
- **Toplama (Play, 31 Ekim):**
  - Ota yumruk: 2 bitki lifi, ot kayboldu. Yerdeki taşa yumruk: 1 küçük taş. E tuşu: prompt göründü,
    taş alındı (+1). Çalıya yumruk: 1 odun.
  - Büyük ağaç (900 / 110): 10 yumruk 2 odun verdi; sonra taş baltayla 40 vuruşta devrildi, toplam
    2 + 108 = 110 odun; son vuruş 2 + 36 toplu pay = 38.
  - Kaya: yumrukla 40 vuruş 2 taş; kazmayla 14 vuruşta kırıldı, toplam 22 taş, son vuruş 1 + 7.
  - Devrilme: tepe oyuncunun tam tersine düştü (yön çarpımı 1,00), 2,5 sn'de 84°, sonra 1 sn'de
    soldu ve silindi.
  - Gerçek fare tıklaması (istemcinin nişan yolu): ota tık +2 lif; baltayla meşe gövdesine 2 tık
    +2 / +2 odun; kamera ışını yapraklardan geçen küçük bir çamda 2 tık +1 / +2 odun (yapraklar
    nişanı tutmuyor).
  - Yol bulma (Edit, gerçek `markNavigation`): spawn yakınındaki 5 ağacın 5'inde de gövde hücresi
    açıldı. Ayakta duran kaya ve göl hücreleri kapalı kaldı. Harita kenarındaki eğimli bir hücre
    arazi yüzünden kapalı kaldı (doğru).
- **Crafting (Play, 31 Ekim):**
  - Taş balta 1,23 sn'de geldi (beklenen 1,2). Balta + 5 kereste kuyruğa alınınca 50 odun 38'e,
    taş ve lif 20'den 18'e düştü. 1 kereste çıktıktan sonra iptal 8 odun iade etti.
  - Envanter tamamen doluyken taş balta kuyrukta "No room" ile bekledi; bir slot boşalınca 0,05 sn
    içinde geldi.
  - Tamir: 6 vuruşla 244'e inen balta 1 taşla 0,5 sn'de 250'ye döndü, kaynağı korundu. Kemerin 3.
    slotundaki balta tamirden sonra yine 3. slota döndü.
  - Doluyken tamir işini iptal etmek reddedildi ("No room for 1 Stone Axe" satırı), iş kuyrukta
    kaldı; bir slot açılınca iptal aleti o slota ve taşı iade etti.
  - Gerçek fare tıklamaları: + / + / Craft ile 3 taş kürek (15 taş, 9 lif, 9 odun düştü, 3 kürek
    geldi); kereste sayısına tıklamak en fazla yapılabilecek 17'yi seçti; kuyruktaki işe tıklamak
    iptal etti (3 kereste yapılmıştı, 28 odun iade). Taş yokken Repair düğmesi soluk, taş gelince
    açık; tıklayınca balta kuyruğa girip 250 ile döndü.
  - Kuyruktaki geri sayım akıyor (ör. "Lumber x3 0.8s", 1,5 sn sonra sıradaki iş "1.3s").
  - Hatalı istekler (NaN, sonsuz, 0, -1, 1,5, 501, 1e9, metin, tablo, bilinmeyen tarif, boş kuyrukta
    iptal, aralık dışı slot, alet olmayan slot) hiçbir güncelleme üretmedi, envanter değişmedi.
    Tek karede 40 istekten 6'sı geçti (hız sınırı 6/sn).
  - Ekran görüntüsünde sırt çantası (594 px) ve panel (340 px) 2198 px genişlikte yan yana sığıyor;
    4 tarif kaydırmadan görünüyor.
- **Loot (Play, 31 Ekim):**
  - 80 zombi + gürültü, 40 öldürme: 10 torba (%25; 10.000 zarlık testte oran %20 ±1,5). Torbalar
    zeminden 0,59 stud yukarıda (çuval merkezi; doğru).
  - E'yi 1,4 sn basılı tutmak: +2 kumaş, torba silindi. Kısa basış arama yapmadı.
  - Envanter doluyken arama: "No room for 7 Scrap Iron", eşya torbada kaldı.
  - Envanter doluyken ota vuruş: 2 lif ayağa torba olarak düştü. 190 taş baltalık işin iptali: 380
    odun envantere, 380 taş ve 380 lif aynı torbaya eklendi. Yer açınca arama 382 lif + 380 taş
    verdi, torba silindi.
  - Ölçülmeyenler: 20 dakikalık ömür, 60 torba sınırı, torbanın görünüşü (3B ekran görüntüsü bu
    oturumda Edit'te de beyaz çıktı).
- **Gündüz-gece (Play, 31 Ekim):**
  - Saat 08:05'ten başlayıp akıyor; "Skip to next phase" geceye (18:30) ve sonraki şafağa atlıyor.
  - 7. günün gecesine atlayınca saat kırmızı, "Horde night" etiketi ve kızıl ton göründü; şafakta
    kalktı.
  - Zombi vuruş aralığı gece 1,1–1,2 sn, gündüz 1,52–1,55 sn.
- **Tehdit ve horde (Play, 31 Ekim):**
  - Ortam nüfusu tek oyuncuda gündüz 6/6, gece 10/10'a çıktı.
  - 7. gecenin başında 5 horde zombisi geldi (kalan 15). 90 stud uzaklaşınca 8,7–12,2 stud/sn
    koştular (11 ±%15); aynı anda kovalayan sıradan zombi 4,6. İkinci dalga 53 sn civarında geldi
    (kalan 10). Şafakta kalan 0 oldu ve eski horde zombileri 4–5 stud/sn'ye indi.
  - Horde gecesinde ortam hedefi 0; şafakta 20 zombi hedefin (6) üstünde kaldığı için yeni spawn yok.
  - Ağaca 4 yumruk gürültüyü 0'dan 4,9'a çıkardı. Ağaçtaki vuruş sesinin zombiyi çektiği ayrıca
    ölçülemedi: yakındaki zombiler oyuncuyu önce gördü. Ses yolu debug Noise ile aynı.
  - Spawn 80 sonrası "Auto spawn on" ve 450 stud ışınlanma: sayı 2 sn'de 4 düşerek 80 → 56 → 36 → 0,
    sonra oyuncunun yanında 6'ya çıkıp orada kaldı. Tick en kötü 1,65 ms.
- **İnşa (Play, 31 Ekim):**
  - Yerdeki çerçeve hücreye oturdu, toprağa 1,1 stud gömüldü (100 can). Spawn noktasının yanında iki
    hücre reddedildi (orada harita parçası var).
  - Oyuncunun etrafına 2 katlı 16 çerçeve: 80 zombi + Noise ile 15. sn'de kırmaya başladılar, 25–30.
    sn'de delip girdiler. Duvar sağlamken içeride zombi yok (ilk denemede itme zombileri bloğa
    sokuyordu; düzeltildi).
  - Taş balta: 3 vuruşta çerçeve ahşap bloğa döndü (500 can), kereste 20 → 16. Kürekle 3 vuruş
    467'ye indirdi, baltanın 1 vuruşu 500'e çıkardı, odun 50 → 49.
  - Çökme: yerdeki blok, üstündeki blok ve ona yandan bağlı havadaki blok; alttaki kürekle 10 vuruşta
    kırılınca diğer ikisi de kalktı.
  - Merdiven: 2 katlı merdivene yürüyünce karakter Climbing durumuna geçti, kök 3,1'den 10,1'e çıktı.
  - Crafting: 3 çerçeve + 1 merdiven 4 kereste ve 1 odun harcadı. Konsol temiz.
  - Ölçülmeyenler: önizlemenin görünüşü (Play'de 3B ekran görüntüsü yok), 2000 blok sınırı, telefonda
    yerleştirme.
  - Kule tepesi: oyuncu 2 blokluk sütunun üstündeyken zombiler sütunu ~20 sn'de kırdı, oyuncu düştü.
- **Hayatta kalma (Play, 31 Ekim):**
  - Roblox `Health` script'i yerine boşu geldi: can 50'ye çekilince 4 sn sonra 50 kaldı.
  - Koşma: WalkSpeed 24, hız 24,1 stud/sn; 6 sn'de dayanıklılık 100 → 74,7; bırakınca 16 ve
    saniyede 10 doldu. 4 zıplama + aradaki dolum 100 → 55,7. Yumruk 10,5 düşürdü. 0'a inince koşu
    durdu, 12,8'de hâlâ yürüyordu (25'te başlar). 5 sn koşu gürültüyü 0,8'den 5,8'e çıkardı.
  - Yemek 20 / su 40: tavan 40 (açlık 2, susuzluk 1). Yemek 1: 11 sn'de tam 1,25 can gitti.
  - Chili: 16 sn'de yemek 0 → 14,2, can 96,75 → 100. Şişe su +20, bulanık su +10 ve −5 can.
  - Göl kıyısı (−435, 2, 328): iki içim +10 / −5 can, arada 0,4 sn'deki deneme reddedildi; kuru
    zemine yumruk dayanıklılık harcadı.
  - Ölüm: odun 50 → 25, küçük taş 20 → 10, lif 20 → 10 torbaya (ölüm noktasından 2,5 stud);
    aletler, kereste, çerçeveler ve yiyecek kaldı. Doğunca can 100, yemek / su dolu.
  - HUD ekran görüntüsüyle doğrulandı: sol altta 4 çubuk, bloklanan dayanıklılık koyu, kademede
    etiket turuncu / kırmızı.
  - İçme ipucu: kamera Scriptable + `MouseBehavior.LockCenter` ile suya bakınca 20 karenin 19'unda,
    ufka bakınca hiç görünmedi.
  - Ölçülmeyenler: telefonda HUD (üst orta) ve Run düğmesi.
- **Bina kapları (Play, 31 Ekim):**
  - 174 kap, hepsinde istem. Market buzdolabı: duvarın 6,5 stud arkasından arama reddedildi, odadan
    kabul edildi.
  - 12 farklı kap (dolap, buzdolabı, raf, depo, ilaç dolabı): 3 konserve, 3 su, 3 kumaş, 2 bandaj,
    10 taş; hepsi "(empty)" oldu.
  - 14 faz atlayıp 8. güne geçince aranmış 5 kaptan 5 eşya daha geldi.
  - Test tuzağı: yakında birden çok istem varken `InputHoldBegin` yalnızca o an gösterilen istemde
    çalışır (tuş başına tek istem). Testte diğer istemleri istemcide `Enabled = false` yap.
- **Konsol:** Sunucu ve istemcide 0 uyarı, 0 hata.

## Teknik notlar

Kod yapısı README'de anlatılıyor. Aşağıdakiler koddan kolayca çıkarılamayan, ölçülerek öğrenilmiş
bilgiler.

- **Harita yalnızca çalışırken var.** `MapService.init()` her şeyi `workspace.Map` altına ve
  Terrain'e kurar. Bu sırada `Players.CharacterAutoLoads = false` yapar, harita bitince `true` yapar.
  Place dosyasında harita yoktur.
- **Roblox arazi formülü (ölçüldü):** En üstteki dolu voxel'in tabanı `b`, doluluğu `o` ise yüzey
  `b + 2 + 4·o` olur. `TerrainBuilder` bu 2 stud'u `SOLID_SURFACE_OFFSET` ile düzeltir.
- **Çimen tabandan çıkar.** Arazi süsü (çim) Grass malzemesinde zeminden yukarı uzar. Bina tabanının
  altına asla çimen gelmemeli: `MapService.layAprons` şablonun `apron` değerini (`Pavement` veya
  `Ground`) döşer.
- **Kasaba düz.** Kasaba 0 yüksekliğinde. Binaların altındaki alanlar (`pad`) kendi yarıçapları içinde
  düz. Bina tabanı `baseY` üzerine oturur.
- **`heightAt` ve `groundAt` farklıdır:**
  - `MapService.heightAt`: arazi yüksekliği.
  - `MapService.groundAt`: yürünebilir yükseklik, bina zeminleri dahil. Zombi ve spawn yüksekliği için
    bunu kullan.
- **Bina ölçüleri:** Izgara 4 stud. Duvarlar hücre merkez çizgisinde durur. Zeminin üstü
  `baseY + 1.0` (`FloorTop`), kat yüksekliği 12 (`FloorHeight`).
- **Merdivenler:** Görünmez bir rampa (WedgePart) üzerine kurulu. Raycast ile ölçüldü: alt uç 2,25,
  üst uç 13,25. Rampanın yerel +Z'si yükseliş yönüdür.
- **Yol bulma iki katmanlı.** Zemin katmanında zemin yüksekliğini 2 stud aşan çarpışmalı her parça
  hücresini kapatır; süs parçaları çarpışmasızdır. Üst kat katmanı kapalı başlar: `BuildingKit` kat
  planından üst kat hücrelerini ve kapı aralıklarını verir, bunlar açılır, sonra üst yürüme
  yüksekliğini kesen parçalar (duvar, mobilya, merdiven boşluğu korkuluğu) kapatılır.
  - Kapı aralıkları (`D`) `isFloorCell`'e girmez; üst katta ayrıca açılmazlarsa odalar kopar. Bu hata
    bir kez yaşandı.
  - Şablonlar en fazla iki katlı; `ZombieService` bunu `assert` ile kontrol eder.
  - Merdiven uçlarından biri kapalıysa açılışta `warn` yazılır ve o merdiven kullanılmaz.
- **Kapı önleri:** `BuildingKit.build` bir Model ve her dış kapının önündeki noktaları döndürür.
  `MapService` lambaları bu noktalardan en az 6 stud uzak tutar.
- **Şablon değiştirince:** `python tools/studio/plancheck.py src/server/World/BuildingTemplates.luau`
  komutu tüm ulaşılamayan hücreleri ve kapı sorunlarını tek seferde listeler. Ardından testleri
  çalıştır.

## Studio MCP ile senkron ve test

### Rojo

- Kaynak doğruluğu diskteki dosyalardır.
- Rojo bağlıysa (`rojo serve` ve Studio'daki Rojo eklentisi) yalnızca diski düzenle. MCP ile Studio'da
  script düzenlersen Rojo üzerine yazar.
- Bu makinede Rokit, Rojo, StyLua, Selene ve Lune kurulu değil (30 Ekim'de kontrol edildi). `rokit install` otomatik modda engellenmişti;
  kullanıcının kendisi çalıştırmalı.

### Rojo yokken senkron

Bu yöntem `tools/studio/` altındaki araçlarla çalışır.

1. Paketi hazırla ve sun:
   ```sh
   python tools/studio/bundle.py . <scratch>/sync
   cd <scratch>/sync && python -m http.server 8765 --bind 127.0.0.1   # arka planda çalıştır
   ```
2. Studio **Edit** modunda olmalı; Play açıksa önce durdur. Sonra `execute_luau` (Edit) ile şunu çalıştır:
   ```lua
   local Http = game:GetService("HttpService")
   local was = Http.HttpEnabled
   Http.HttpEnabled = true
   local src = Http:GetAsync("http://127.0.0.1:8765/Harness.luau", true)
   Http.HttpEnabled = was
   local H = loadstring(src)()
   return H.sync() .. "\n" .. H.test(false)   -- beklenen: "59 passed, 0 failed"
   ```
   Düzenek place'e hiçbir şey bırakmaz.
3. Her kod değişikliğinden sonra adım 1'deki bundle komutunu tekrar çalıştır, sonra `H.sync()`.
4. İş bitince HTTP sunucusunu durdur.
5. Studio'daki kopyanın diskle aynı olduğunu doğrulamak için script `Source` uzunluklarını diskteki
   dosyaların CRLF'siz boyutlarıyla karşılaştır.

### Play testi

- Başlat: `start_stop_play(true)`.
- `execute_luau` ile `Server` veri modelinde `workspace.Map` hazır olana kadar bekle.
- Konsolu `get_console_output` ile ya da her veri modelinde (`Server`, `Client`)
  `LogService:GetLogHistory()` ile oku. Oyun kodu hiçbir şey yazdırmaz; boş çıktı "uyarı ve hata yok"
  demektir. Bu, kasıtlı bir `warn` ile denendi: iki yöntem de yakaladı.
- Bitince `start_stop_play(false)` ile durdur.
- `execute_luau` ayrı bir VM'de çalışır: `require(ZombieService)` başlatılmamış yeni bir kopya verir.
  Zombi spawn etmek için `Client` veri modelinden
  `game.ReplicatedStorage.Remotes.DebugCommand:FireServer("Spawn", 80)` kullan (`"Noise"`,
  `"GodMode"`, `"Kill"`, `"GiveKit"`, `"Clear"` da var; `"Spawn", 1` tek zombi verir).
  İstemci zombi modelinin adı `Zombie{id}`; sunucunun verdiği id ile aynı.
- İstemcide `SetAttribute` sunucuya geçmez; sunucuya değer aktarmak için kodu metin olarak yaz.
- Vuruş ölçmek için istemcide `Remotes.ToolSwing.OnClientEvent` dinlenir (saldıran, alet, zombi id'si
  veya 0, kafa). Kalabalıkta isabetler dağılır; tek zombiyle ölç. İstemcide zombiler `workspace.ClientZombies` altında, `Pelvis`
  parçasıyla ölçülebilir.
- Toplama ölçmek için istemcide `Remotes.InventoryGain.OnClientEvent` dinlenir (eşya, eklenen, sığmayan).
- **MCP kamerayı Fixed'e alıyor:** her `execute_luau` çağrısından sonra kamera Fixed olur, karakteri
  takip etmez. Dünyadaki bir noktaya gerçek tıklama için aynı çağrıda `CameraType = Scriptable` yap,
  `camera.CFrame`'i karakterin arkasına koy, `WorldToViewportPoint` ile ekran noktasını al, sonra
  `user_mouse_input` ile tıkla (Fixed kamera konumu korur). Fare serbest olduğu için nişan imleçten geçer.
- Arayüz düğmeleri `user_mouse_input` ile `instance_path` verilerek tıklanabilir (ör.
  `LocalPlayer.PlayerGui.Inventory.Backpack.Slots.Slot11`); tuşlar `user_keyboard_input` ile.
- Slot düğmelerindeki `Name` etiketi `.Name` özelliğinin gölgesinde kalır: test betiğinde
  `slot:FindFirstChild("Name")` kullan.
- `GodMode` bir ForceField takar; `Humanoid:TakeDamage` o sırada hiç çalışmaz. Saldırıyı ölçmek için
  ForceField'ı kaldır.

### Ekran görüntüsü

- `screen_capture` Play modunda 3B sahneyi beyaz çekiyor ama arayüz görünüyor (31 Ekim crafting
  paneli böyle çekildi). 3B görüntü için Edit modu gerekiyor; 31 Ekim gecesi Edit'te de beyaz çıktı
  (Studio penceresi arka plandayken 3B çizilmiyor olabilir).
- **Elde alet önizlemesi:** Edit modunda `Players:CreateHumanoidModelFromDescription` ile R15 rig
  kurulur, `H.load(...Modules.HeldItems).build(id, rig.RightHand, grip)` ile alet takılır.
- **Zombi önizlemesi:** Edit modunda `H.load(<StarterPlayer altındaki ZombieRig>)` ile
  `Rig.build(id)`, `Rig.newPose(id)` ve `Rig.pose(...)` çağrılıp birkaç rig `workspace` altına bir
  klasöre konur, yüksekte (y≈1000) bir zemin parçasıyla çekilir, sonra klasör silinir.
- Görüntü için haritayı Edit modunda kur:
  ```lua
  H.load(game.ServerScriptService.Server.Services.MapService).init()
  ```
- İlk görüntü bazen yine beyaz çıkar; tekrar dene.
- Studio arka plandayken istemci FPS'i 15'e düşer. Bu bizim kodumuzdan kaynaklanmaz.
- İşe yarayan kamera noktaları (`camera_position` → `look_at_position`):

  | Görüntü | Kamera | Bakılan nokta |
  | --- | --- | --- |
  | Sokak | `[300,22,178]` | `[250,6,205]` |
  | Küçük ev (HouseSmall) içi | `[256.5,8,211]` | `[270,3,199]` |
  | İki katlı ev (House04) üst kat | `[326,20,229]` | `[321,12,210]` |
  | Market içi | `[238,9,159]` | `[210,3,136]` |

- **Görüntüden sonra mutlaka temizle.** Temizlenmezse Play'de harita iki kere oluşur:
  ```lua
  workspace.Map:Destroy(); workspace.Terrain:Clear(); game.Players.CharacterAutoLoads = true
  ```

### Oturum sonu kontrolü

- Studio Edit modunda.
- Workspace'te yalnızca `Camera` ve `Terrain` var.
- ServerStorage boş.
- HTTP sunucusu durdurulmuş.
- Her şey commit edilmiş.

## Bilinen sorunlar ve tuzaklar

- **Telefonda FPS hiç ölçülmedi.** Aşama 1'in kapısı (kullanıcı erteledi). Bina parça sayısı hedefin
  üstünde; zombi başına parça sayısı 17'ye çıktı.
- **Araç zinciri hiç çalıştırılmadı.** README'deki `stylua --check`, `selene src` ve `lune run tests/run`
  komutları bu makinede hiç koşmadı. İlk çalıştırmada format ve lint düzeltmeleri çıkabilir.
  `tests/run.luau`'nun gerçek Lune'da da geçtiği doğrulanmalı.
- **MCP sınırları:**
  - Script'ten `StreamingTargetRadius` ayarlanamıyor; yalnızca `default.project.json` içinde.
  - MCP üzerinden `Lighting.Technology` okunamıyor (yetki hatası).
- **Python konsolu cp1254 kodlamasında.** Türkçe veya Unicode yazdıran betiklerde
  `PYTHONIOENCODING=utf-8` kullan.
- **Tab tuşu:** Roblox oyuncu listesi Tab'ı oyundan önce alıyor (Play'de denendi); sırt çantası `I`.
- **Zombiler oyuncunun içine giriyor.** 80 zombilik kalabalıkta saldıran zombilerin bir kısmı oyuncunun
  gövdesine 0,1–1 stud kadar giriyor (sunucu konumları ölçüldü). Vuruşta "önde olma" şartı var, ama
  görsel ve oynanış sorunu; NEXT_STEPS'te.
- **Roblox'un varsayılan can yenilenmesi kapalı.** `src/character/Health.server.luau` boş bir
  `Health` script'i; silinirse Roblox kendi saniyede %1'lik script'ini geri koyar.
- **Play testinde karakter ölebilir.** Ortam nüfusu açılışta 6 zombi getirir; uzun ölçümden önce
  debug `Clear` (yöneticiyi de durdurur) ve `GodMode`. Ölümden sonra eski `Character` referansı
  boşa gider; betikte karakteri yeniden al. `PlayerScripts` içinde `PlayerModule` yok;
  `WaitForChild("PlayerModule")` sonsuza kadar bekler. `Humanoid:Move` doğrudan çalışıyor.
- **Komut çubuğundan servis durumu okunamaz.** `execute_luau` içinde `require` modülün yeni bir
  kopyasını verir (ör. `getHarvestables()` boş döner). Sunucu davranışını istemciden remote ile ölç;
  iç durumu Edit modunda kendi yükleyicinle kur: `H.load` gibi bir önbellekle `ZombieService`'i yükle,
  önbellekten aynı `MapService`'i al, `init()`, sonra `ZombieService.init()/start()`. `start()`
  Heartbeat bağlar; ortamda `game:GetService("RunService")` için Heartbeat'i boş bir saplamayla
  değiştir (5. Bölüm yol bulma ölçümü böyle yapıldı).
- **`return assert(x, "...")` iki değer döndürür.** Tablo kurucusunun son elemanında mesaj da
  tabloya girer. Parantez kullan: `return (assert(x, "..."))`.
- **Ot ve çalı çarpışmasız ama sorgulanabilir.** Varsayılan `RaycastParams` (`RespectCanCollide =
  false`) bunlara değer. Yerleştirme gibi yeni raycast'lerde bunu hesaba kat.
- **Alt bitki örtüsü parça sayısını %64 artırdı** (14.492 parça). Telefonda ölçülmedi.
- **Arayüzü görüntüyle doğrula.** Alet kemeri slotları 2. adımdan beri 0×0'dı; yalnızca etiketleri
  görünüyordu ve `instance_path` ile tıklama yine çalıştığı için fark edilmedi. `UIListLayout`
  çocuğa boyut vermez; `UIGridLayout` hücreler alanı tam doldurursa yuvarlamayla son hücreyi alt
  satıra atar (crafting kuyruğunda görüldü, listeye çevrildi).
- **Fare tekeri slot değiştirmiyor.** Tekerlek kamera zoom'unda; kamera adımında karar verilecek.
- **Git yedeği yok.** Uzak depo tanımlı değil. GitHub'a göndermek dışarıya açık bir adım olduğu için
  kullanıcıya sorulmalı.
