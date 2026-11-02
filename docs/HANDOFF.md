# Devir notu

Bağlamı olmayan yeni bir oturum işe buradan başlar. Sıradaki işler [NEXT_STEPS.md](NEXT_STEPS.md)
dosyasında, tasarım kararları [PLAN.md](PLAN.md) dosyasında, kod yapısı [../README.md](../README.md)
dosyasında. Bu not 30 Ekim – 1 Kasım 2026'daki uzun çalışma oturumlarını (birkaç kez sıkıştırılmış) özetler.

## Proje ve roller

**En güncel silah çalışması — 1 Kasım 2026:** [WEAPON_HANDLING.md](WEAPON_HANDLING.md).
`RangedService` ve yeni saf `Firearm` şarjör/doldurma otoritesi; `WeaponController` güvenilir durum,
HUD, ADS ve tepme; `EquipmentPoseController` gerçek R15 ölçülerinden kol çözümü. Mühimmat metadata'sı
envanter/sandık/loot/tamir yollarında korunur. Eski istemci `loaded` tahmini kaldırıldı. 90 test geçti.
MCP `require` ayrı önbellek verdiğinden gerçek envanter testleri Play'de geçici normal sunucu Script'i
ile yapıldı. IKControl Transform yeni AnimationConstraint avatarında hedefi tutturmadı; bunun yerine
omuz-dirsek-bilek Transform çözümü kullanıldı, destek eli hatası 0,000031 stud'dan az ölçüldü.
Bu tek test avatarının ölçümüdür. Ses, fiziksel mobil FPS ve gecikmeli çok oyunculu test bekliyor.
Yakıt R yerine T; R/B/touch Reload. Geçici test kameraları ve fixture'lar Play'e aitti.

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

Kullanıcı 31 Ekim gecesi (02.30 civarı) "her iş bitince sıradaki eksiği kapat" dedi ve öğlene kadar
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

### 13. Bölüm: kazı (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `499eb61` | `DigService`: araziye vuruş 4 stud'luk sütunun tepesinden bir voksel kazar; 7DTD can ve verimi (`Config.Dig`); kil ve kırık kum eşyaları; sütun yan komşusundan en çok 2 voksel aşağı iner; yasak yerler; kazının gerçek yüzeyi yükseklik ızgarasına döner, `MapService` çukur çevresinde yüksekliği ışınla okur; 12 stud altında kaya katmanı (1 test) |
| `858d355` | Dirt (16 kil, 3 sn): kazılmış sütunu bir voksel doldurur, yalnızca eski yüksekliğine kadar; içinde oyuncu ya da zombi varken reddedilir |

### 14. Bölüm: kapı ve takılan zombiler (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `3a803a8` | Zombinin yol ofseti (`SpreadRadius` 2,5) yol noktasının hücresinde tutulur (kenara 0,25 stud). Yarım hücreden büyük ofset hedefi zombinin kendi hücresine düşürüyordu; zombi oraya varıp sonsuza dek duruyordu. 80 kovalayan zombinin 10'u takılıyordu, düzeltmeden sonra hiçbiri |
| `f84534b` | Ahşap kapı (7DTD: 1000 can, 2 hücre; 5 kereste, 2 sn): kuranın durduğu yüze asılır, etkileşim tuşuyla kendi hücresine doğru açılır; açıkken zombi geçer, kapalıyken duvardır; kapı aralığında oyuncu ya da zombi varken kapanmaz; `BuildGrid.sideToward`, `doorCFrame` (1 test) |
| `114cc42` | Tahta sopa ve taş mızrak (7DTD: 12 hasar, 55 vuruş/dk, 100 dayanıklılık; sopa 5 odun, mızrak 5 taş + 3 lif + 3 odun); toplamada odun, taş, kil ve kumun dörtte biri, lifin tamamı (`Harvest.toolCount`, `Config.Harvest.SharedItems`); zombi torbasından da çıkar (1 test) |
| `e72be4b` | İlkel yay ve taş ok (7DTD: ok 35 − yay 5 = 30 hasar, 45 m/sn × 0,7, 100 m, yay 100 dayanıklılık / atış başına 1; yay 8 odun + 3 lif, ok 1 taş + 1 odun + 1 lif, 1,4 sn); `RangedService` oku sunucuda yerçekimiyle uçurur, her adımı zombi vuruş hacmine ve dünyaya karşı sınar; `ArrowController` aynı yayı çizer; saf `Shared/Ballistics` (1 test) |

### 15. Bölüm: tarım (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `6303735` | Tarım (7DTD 3.2): tarla (250 can, 4 odun + 100 kil, 20 sn; yassı blok, kimseyi engellemez), mısır / patates / yaban mersini tohumu (5 üründen 1, 1 sn; mutfak kaplarında), ekim, 3 aşama × 1,05 oyun günü, olgunda "Harvest" istemi (2 ürün + %50 bir daha + tohum geri), tarla kırılınca ekin gider; debug "Grow crops"; saf `Shared/Farming`, `BuildGrid.plotCFrame` (1 test) |

### 16. Bölüm: jeneratör ve lamba (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `717d039` | Jeneratör (500 can; 50 hurda + 6 mekanik + 8 elektrik parçası, 105 sn) ve elektrikli lamba direği (100 can; 4 hurda + 2 elektrik parçası, 10 sn). Benzin elde "use" ile jeneratöre dökülür (bir seferde 250, depo 1000); jeneratör etkileşim tuşuyla açılır / kapanır. Çalışan jeneratör 48 stud içindeki lambaları 50 W'a kadar yakar (lamba 5 W), kullanılan watt için 7DTD'nin 1,8 benzin / watt / oyun günü oranında yakar, 3 sn'de bir gürültü yapar (tek ses noktası), İz ekler. Benzin, mekanik ve elektrik parçası depo kaplarında; saf `Shared/Power` (1 test); `BuildService.onPlaced`, `blockAt`; `ThreatService.emit` artık oyuncu ya da adlı kaynakla birleştirir |

### 17. Bölüm: grafik ayarları (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `767fdd2` | Saatin altında "Graphics: …" düğmesi; panelde Auto / Low / Medium / High. Ön ayar yalnızca bu istemciyi değiştirir: zombi çizim / ayrıntı / animasyon mesafesi ve ceset süresi (`ZombieRenderController.setQuality`), güneş gölgesi, bloom, güneş ışınları, lamba ışığının erimi. Sis, atmosfer, gökyüzü ve gece tonu hiç değişmez. Auto: dokunmatik ve klavyesiz cihaz Low, öbürleri Roblox grafik kalitesine göre (1–3 Low, 4–7 Medium, 8–10 High, Automatic Medium). Medium eski görünüm. Saf `Shared/Graphics` (1 test) |

### 18. Bölüm: arayüz ve depolama sandığı (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `e3f36c2` | Roblox'un üst çubuktaki sağlık çubuğu kapatıldı (HUD'da zaten var); grafik panelindeki açıklama yazısı büyütüldü |
| `fdef2f5` | Depolama sandığı (PLAN MVP "sandık"; 150 can, 4 kereste, 7 sn; 36 yuva): "Open" istemi sırt çantasını açar, crafting panelinin yerinde sandık paneli çıkar. Sandık yuvasına tıklamak yığını alır; çantadan bir yuva seçip sandık yuvasına tıklamak oraya koyar (dolu ise boş ilk yere); "Take all". Sandık ortaktır, açanlar menzilde ve canlı kaldıkça izleyicidir, her değişiklik hepsine gider; kırılan sandık içindekileri torbaya döker. `Inventory.transfer` (1 test), `InventoryController.showSidePanel`, `setBackpackOpen`, `onBackpackChanged`, `takePicked` |

### 19. Bölüm: evin içine inşaat (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `4ed6ce1` | Kasaba binalarının zemin katına blok, kapı, sandık, lamba konur (kattan en fazla 2 hücre yukarı); oyuncu kapı boşluğunu barikatlar, evi üsse çevirir (7DTD: her POI üs olabilir). Üst katlar kapalı: üst kat yol bulması blokları görmüyor. Blok altındaki yüzeye (döşeme, bordür) en fazla 1,25 stud gömülebilir; boşluk denetimi hücre ortasından aşağı atılan ışının vurduğu yerden başlar (istemci ve sunucu aynı). Binalar `BuildArea` etiketi ve `BuildMin` / `BuildMax` / `BuildTop` özelliklerini taşır; hayalet blok kuralı önceden gösterir. Bina içi zombi spawn'ı bloklu hücreyi atlar. `BuildGrid.sinkRay`, `clearSpan`, `indoorBlocked` (1 test) |

### 20. Bölüm: kamp ateşi ve pişirme (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `8b6e19d` | Kamp ateşi (7DTD 3.2: 5 küçük taş, 1 sn, 100 can): konulan bir crafting istasyonu; ateş, ışık, iki kütük ve "Cook" istemi (crafting panelini açar). Tarifler `Station` (kuyruğa alırken 10 stud içinde o türden blok) ve `Tool` (taşınan, harcanmayan eşya) isteyebilir. Fırında patates (patates, 10 sn), közde mısır (mısır + ızgara, 5 sn), kaynamış su (bulanık su + tencere, 10 sn; çıktı Bottled Water = 7DTD'nin kaynamış su kavanozu). Pişmiş yemek 10 yemek, zamanla 5 can, −5 su (7DTD). Tencere ve ızgara mutfak dolaplarından (yaklaşık 25 dolapta birer). Panel istasyon ve alet şartını yeşil / kırmızı yazar, karşılanmayan tarifi soluk gösterir. `Crafting.canUse` (1 test), `BuildService.near` |

### 21. Bölüm: eşya simgeleri (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `7748aed` | Her eşyanın renkli karesinin üstüne bir emoji (`Shared/ItemIcons`): çanta, alet kemeri, sandık, crafting satırları, toplama akışı. Roblox Unicode 12'ye kadar emoji çiziyor; kütük, kaya, merdiven, yaban mersini kutu çıktığı için yerine ağaç, yeni ay, tırmanan kişi, üzüm. Her eşyanın simgesi olduğunu test denetler. Play'de ekran görüntüsüyle doğrulandı |

### 22. Bölüm: boru tabanca (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `7e1c6ed` | Boru tabanca (7DTD 3.2: 4 metal boru + 2 tutkal + 6 odun, sırt çantasında): yayın sunucu uçuşunu kullanır. Dakikada 126 atış, 6'lık şarjör, 2 sn doldurma, 1,5° sapma, 9 mm 32 − 4 = 28 hasar (kafa ×2), 40 m, 250 m/sn düşüşsüz mermi, her atış "Gunshot" gürültüsü (25, 180 stud). 300 dayanıklılık (bizim), tamir yok. İstemci mermiyi parlak iz ve namlu ışığıyla çizer, şarjörü sayar ve "Reloading..." gösterir. Tutkal: 7 kemik + 1 kaynamış su, kamp ateşi + tencere. Zombi torbası kemik (2–6) ve 9 mm (2–6), depo kapları boru, tutkal ve 9 mm verir. `Ballistics.afterShot`, `spread` (1 test) |
| `fdde123` | Silah elde yay yerine tahta kabza + metal boru namlu olarak görünür |

### 23. Bölüm: tahta parmaklık (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `b39694a` | Tahta parmaklık (PLAN MVP "tahta parmaklık"; 7DTD'de yalnızca dövme demirden parmaklık var): 3 kereste, 300 can, tamir 3 odun. Hücre görünmez bir kutu (oyuncu ve zombi geçemez), üstünde dekor kafes (4 dikme, 4 üst kiriş, 8 çıta; çarpışmasız, sorgulanmaz). Kutu "Bars" çarpışma grubunda; mermi / ok (`RangedService`), zombi görüşü (`ZombieService`) ve yakın dövüş duvar kontrolü (`ToolService`, `solid`) "Shots" grubuyla ışın atar, bu grup Bars ile çarpışmaz. Zombiler yol bulmada parmaklığı duvar gibi görür ve kırar |

### 24. Bölüm: mobilya kırma (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `7934fed` | Kasaba mobilyası (şömine hariç 30 tür, haritada 442 parça) toplama düğümü oldu: can 7DTD 3.2 blok malzemesinin MaxDamage'ı (zayıf ahşap 100, mobilya 300, takviyeli ahşap 225, metal 300, zayıf metal 100, ince metal 250, taş mobilya 300, küvet 200, saman 50, bitki 1), düşenler eşleşen 7DTD bloğundan: dolap / masa / sandık odun, yatak / kanepe odun + kumaş (kumaş bizim), buzdolabı / ocak / metal raf hurda demir, klozet boru, lavabo hurda demir, küvet taş + hurda, saman ve bitki lif. 7DTD metal ve tesisatın "Harvest" düşüşlerini yalnızca İngiliz anahtarına verir (`salvageHarvest`); anahtar yok, o parçalar yalnızca kırılma düşüşünü verir. Metal için aletlerde çarpan yok, taş çarpanı kullanılır. Kırılan mobilya hücrelerini zombiye ve inşaata açar (`release`), kap mobilyası içindekini (gerekirse önce zar atarak) torbaya döker (`LootService.spillContainer`). Modellerde `FurnitureCell` (bina adı / kat:satır:sütun) kimliği (1 test satırı) |

### 25. Bölüm: atış sesi, eşya atma, cam, boru silahlar, kazık tuzağı, kırık taş, blok düşüşleri, yatak rulosu (31 Ekim)

| Commit | Ne yapıldı |
| --- | --- |
| `293bc96` | Menzilli silahlara `SoundId` (boş = sessiz): `ArrowFired` silah kimliğini de taşır, istemci sesi namluda çalar, 4 sn sonra siler. Ses seçimi kullanıcıda (NEXT_STEPS, Kullanıcı kararı bekleyenler 6) |
| `ceeeda2` | Eşya atma (7DTD: G ya da pencereden sürükleme): G elde tutulan yığını, çanta açıkken seçili yığını atar; çantada mouse ve dokunmatik için "Drop" düğmesi. `InventoryDrop` remote'unu `LootService` karşılar (tip, slot aralığı `takeSlot` ile, saniyede 4 sınırı, canlı karakter), yığını dayanıklılığıyla oyuncunun ayağındaki torbaya koyar (6 stud içindeki torbaya eklenir). Başlık düğmeleri 72 px'e daraldı (dört düğme telefondaki en dar panele sığar), yazıları en çok 18 punto |
| `9868b76` | Boru tüfek, pompalı ve makineli (7DTD 3.2, hepsi 4 boru + 2 tutkal + 6 odun): tüfek 7,62 mm tek mermi, 2,66 sn doldurma, 47 − 3 = 44 hasar, 150 m, 5,7° sapma; pompalı tek fişek, 2,3 sn doldurma, fişek başına 10 saçma (her biri ayrı sapma, 10,1 − 2 = 8,1 hasar), 10 m, 4,8°; makineli dakikada 335 (basılı tutunca), 15'lik şarjör, 3 sn doldurma (XML'de yok, bizim), 47 − 17 = 30 hasar, 90 m, 3°. Nişan alma: sağ tık / gamepad L2 basılı, dokunmatikte Vur düğmesinin üstünde "Aim" anahtarı (yalnızca elde nişan alınabilir silah varken). Kamera 0,15 sn'de FOV 50'ye yaklaşır; sunucu `AimIntent` (bool, saniyede 8) ile sapmayı silahın 7DTD nişan payına indirir (`AimSpread`: tabanca 0,4, tüfek 0,09, pompalı 0,87, makineli 0,22; `Ballistics.spreadDegrees`). Silah bırakılınca, çanta açılınca ya da yeniden doğunca nişan biter. Alet remote sınırı 4 → 6 / sn (makineli 5,6 atar). Cephane: zombi torbası 7,62 (2–4) ve fişek (1–3), depo 7,62 (3–8) ve fişek (2–6), ağırlıklar bizim. 1 test |
| `f7c47eb` | Tahta kazık tuzağı (7DTD trapSpikesWoodDmg0): 20 odun, sırt çantasında 4 sn; 7DTD tam tamiri 10 odun, bizde vuruş başına 4 odun (pay yukarı yuvarlanır), tam tamir 12 odun. Hücre kutusu görünmez ve çarpışmasız (oyuncu ve zombi içinden yürür, `Passable`, yol ızgarasına yapı olarak girmez); üstünde dekor taban + 3 × 3 eğik kazık. `BuildService.checkTraps` 0,2 sn'de bir: gövdesi (yarıçap 0,5) kutuya değen ve ayağı tuzak tabanına 1,5 stud yakın zombi en çok saniyede bir 33 hasar alır (saldıran yok, kovalamaya başlamaz) ve 1,2 sn 0,18 hızla yürür (`ZombieService.slow`, 7DTD movement_factor); tuzak her vuruşta 25 aşınır: 300 can = 7DTD'nin 12 vuruşu (100 canlık üç aşama × 4). Her aşama kazıkların üçte birini gizler (9 / 6 / 3). Oyuncuya vurmaz (bizim). 1 test |
| `dbf01ae` | Silahın alet kemeri yuvası cephaneyi gösterir (7DTD): silahta "şarjördeki / taşınan" (doldururken 0, doldurma bitince dolu; `ToolController` → `InventoryController.setLoaded`), yayda taşınan ok sayısı |
| `8b79d1a` | Kırık taş kademesi (7DTD cobblestoneShapes): taş balta ahşap bloğu 3 vuruşta 10 kırık taşla `CobblestoneBlock`a çevirir: 1500 can, aletlere taş gibi davranır (blok başına `HarvestMaterial`; kazma 26, ahşap sayılsa 5); 7DTD tam tamiri 8 kırık taş, bizde vuruş (100 can) başına 1 taş, 1500 can için 15 taş. Kırık taş: 1 kil + 1 küçük taş, sırt çantasında 0,4 sn (kil malzeme süresi 0,2 sn eklendi). Test çantasına 20 kil ve 20 kırık taş. 1 test |
| `bd684fc` | Oyuncu blokları kırılınca malzeme verir (7DTD): `Harvest` düşüşü oyuncunun alet vuruşlarına toplama formülüyle (`Harvest.payout`) bölünür (çerçeve ve ahşap blok 2 odun, kırık taş 6 kil + 6 taş, parmaklık 2 odun bizim), `Destroy` düşüşü kıran vuruşu yapana (merdiven 1–2 odun, kazık 2–6 odun, kamp ateşi 3 taş). Silahlar her zamanki dörtte biri alır. Zombinin ya da aşınmanın kırdığı blok bir şey vermez (bizim; 7DTD yere düşürür). 1 test |
| `77080f5` | Yatak rulosu (7DTD bedroll, SleepingBag): 10 bitki lifi, sırt çantasında 2 sn; 100 can, aletlere toprak, tamir 20 lif, vuruşlarda 5 lif, kırılınca 1–3 lif; zombi üstünden geçer. Kuran oyuncu ölünce üstünde doğar (`BuildService` `CharacterAdded` → `PivotTo`, kök 3 stud yukarıda); yenisi eskisinin yerini alır, kırılırsa harita doğuşuna döner. Kayıt yok (bloklar gibi). 1 test |
| `ea7e10b` | Kasaba pencere camları (274) kırılır: her cam kendi `Window` modeli, `HarvestNode = "WindowGlass"`; HarvestService bu özelliği taşıyan harita modellerini de düğüm sayar. 7DTD Mglass canı 1: her vuruş kırar, düşüş yok (bizim). Pencere denizliği zombiyi yine durdurur, yol ızgarası değişmez. Mermi camı kırmaz (yalnızca alet vuruşu) |

### 26. Bölüm: kullanıcı testinden sonra eleştiri ve düzeltmeler (1 Kasım)

Kullanıcı Studio'da girdi: sırt çantasını açamadı, odun kıramadı, yalnızca yerden taş topladı ve evlerden
loot aldı. Kök nedenler Play'de gerçek tuş ve tıklamayla ölçüldü:
- Roblox oyuncu listesi Tab'ı yutuyordu.
- Türkçe Q klavyede noktalı "i" tuşu `KeyCode.Quote` olarak geliyor; `I` bağlaması o tuşa basınca çalışmıyordu.
- Toplanan her şey görünür bir düğmesi olmayan sırt çantasına giriyordu.
- Yumruğun geri bildirimi yoktu: 600 canlı ağaçta 2 hasar ve vuruş başına ~0,23 odun, ama ekranda hiçbir
  şey değişmiyordu.
- Yönlendirme yoktu.

| Commit | Ne yapıldı |
| --- | --- |
| `a6ebf3f` | Tab ve I (gamepad Y) sırt çantasını açar, Roblox oyuncu listesi kapalı; Bag düğmesi her cihazda, klavyede köşesinde "Tab". 7DTD başlangıç eşyaları (kaynamış su, chili, bandaj) alet kemerinin 8–0 yuvalarında. Vurulan şeyin kalan canı ekran ortasının altında çubukla (`HitInfo`, `TargetBarController`). Menzil dışı yakın dövüş vuruşunda "Too far away". Klavyede sağ altta kontrol listesi (`HelpController`, H gizler; harf tuşları oyuncunun klavye düzeninde) |
| `3070c81` | Can çubuğunun yer tutucu metinde kalmaması için savunma düzeltmesi (yeniden üretilemedi) |
| `3857b54` | 7DTD 3.2 `challenges.xml` görev zinciri, tutorial olarak: Basics of Survival (6), Homesteading (8), Advanced Survival (5). `ChallengeService` (sunucu sayar; toplama, crafting, yerleştirme, yükseltme, içme, öldürme) ve sağ üstte `ChallengeController`. Kayıt yok |
| `81fb6f0` | Omuz kamerası (`CameraController`): V ile omuz → birinci şahıs → serbest fare. Omuzda fare ortaya kilitli, ortada nişangâh, karakter kameraya döner, kamera sağ omuzda. Sırt çantası, sandık, grafik paneli açıkken ya da Sol Alt basılıyken imleç serbest. Zoom 4–14 |
| `8b21656` | Vuruş parçacıkları (`ImpactController`, `Shared/Surface`): dünyaya isabette yüzey renginde toz ve talaş, zombide kan; ok ve mermi de. `ToolSwing` artık isabet noktası, normal ve rengi taşır. Zombiye isabet eden yumrukta yanlış "Too far away" düzeldi: zombi parçaları ışın almaz, istemci sunucunun vuruş şekliyle (`Melee.pick`, `ZombieRenderController.bodiesNear`) bakar |
| `f9610b6` | Ölüm ekranı (`DeathController`): "You died", yeniden doğma geri sayımı, torba düştüyse açıklama (`PlayerDied`). Torbanın üstünde ekranda "Your bag" ve mesafe (m); torba ekran dışındayken kenarda bekler, 6 stud yaklaşınca ya da süre bitince gider |
| `23c4af2` | Otlu zemin önce biçilir (`DigService`): otlu sütuna ilk vuruş uzun ot tutamı kadar lif (2) verir ve sütunun otunu toprağa çevirir; sonraki vuruşlar toprağı kazar. Önceden yumruk 250 canlı toprağı kazıyor ve lifi bu cana yayıyordu |
| `1832734` | Eşya bilgi paneli (`Shared/ItemInfo`): sırt çantasında imlecin altındaki ya da seçili eşyanın adı, sayıları (hasar, blok hasarı, dayanıklılık, yemek / su / can, blok canı, cephane) ve bir cümlelik açıklaması çantanın üstünde. 56 eşya açıklaması; her eşyanın adı ve açıklaması olduğunu bir test denetler |
| `12911f7` | Crafting satırının üstüne gelince panel tarifin ürününü anlatır (`InventoryController.hoverItem`) |

### 27. Bölüm: ikinci kullanıcı testi; ateş, demir, animasyon (1 Kasım)

Kullanıcı ölüm dışında her şeyi denedi. Bulguları: vuruş animasyonu yok ya da kötü, birinci şahıstan
oynanmıyor, fare ortada kilitli ve soldaki debug paneline ulaşılmıyor, zombiye hasar verilemiyor, demir
ve ateş yok, inşa yok. Kök nedenler:
- Zombi parçaları ışın almadığı için kamera ışını zombinin içinden arkadaki zemine gidiyordu; omuz
  kamerasında yakın zombinin 1,6 stud yanından vuruluyordu.
- Roblox birinci şahısta bütün karakteri gizliyordu: el, alet ve vuruş görünmüyordu.
- Avatarın eklemleri `AnimationConstraint`; `C0` salt okunur olduğu için üçüncü şahıs omuz sallaması hiç
  oynamıyordu.
- Crafting paneli 36 tariften dördünü gösteriyordu; kamp ateşi 29. sıradaydı.
- Demir ve ateş gerçekten yoktu. İnşa vardı (Building sekmesi), kullanıcı bulamamıştı.

| Commit | Ne yapıldı |
| --- | --- |
| `08a1031` | Kamera ışını sunucunun zombi vuruş şekliyle de sınanır, nişan zombinin ekseninden geçer. Yalnızca sabit test kamerasıyla ölçüldü |
| `809479f` | Vurulan zombinin canı vuruş çubuğunda |
| `64b7345` | Debug düğmelerinin üstünde imlecin nasıl serbest kalacağı (Tab ya da Alt) |
| `0617fa1` | `ViewmodelController`: birinci şahısta kol ve eldeki eşya kameranın önünde; her eşya türüne dinlenme pozu, vuruşlar (tepeden indirme, saplama, sırayla yumruk), silah tepmesi, yay, yemek, blok itme; yürürken sallanma. `HeldItems` sunucudan `Shared`'a taşındı |
| `be63203` | Crafting sekmeleri: All, Tools, Weapons, Building, Resources, Food (`Config.Crafting.Categories` / `Category`) |
| `eef8033` | `StationService` (yeni): kamp ateşi yakıtı (R, 5 eşya), yakma / söndürme (F; çakmak 1 aşınma ya da 2 lif), yanarken saniyede 1 sn yakıt, bitince söner, `Lit` / `Fuel` özellikleri, İz `Fire` kaynağı. `Shared/Fuel` (yakıt sırası ve tavanı). Odun kömürü (3 odun, 15 sn, kamp ateşinde) ve çakmak (mutfak dolabı loot'u). `Notice` remote'u: sunucu uyarısı sağdaki akışta kırmızı. Tarifler yalnızca yanan istasyonda |
| `2549bc6` | Demirci ocağı bloğu (500 can, bacalı tuğla), yalnızca odun kömürü; dövme demir, metal boru, tencere, ızgara tarifleri; jeneratör 15 dövme demir |
| `b7241b7` | Üçüncü şahıs vuruşları eklem `Transform`'una `RunService.PreSimulation`'da bindirilir (Motor6D ve AnimationConstraint): tepeden balta, mızrak, sırayla yumruk; dirsek ve bel de döner. Birinci şahısta alet pozları sap ve baş yönünden kurulur |
| `68256dc` | Demir cevheri kayası (`IronBoulder`: 600 can, 105 hurda demir + 14 taş; ormandaki kayaların %30'u, taş ocağında 6). Demir balta / kazma / kürek (7DTD kalite 1; 20 dövme demir, kürek 16; 10 odun, 2 kumaş, 2 tutkal; tamir 1 dövme demir). Eldeki modelleri metal başlı. Test çantasına demir kazma, 20 dövme demir, 4 kumaş, 4 tutkal |

Play'de ölçülenler: kamp ateşi yakıtsız uyarı verir, 5 odun 250 sn, çakmak 50 → 49, lif 20 → 18, yakıt
bitince söner; ocakta 5 odun kömürü 500 sn, dövme demir ve tencere üretildi, patates reddedildi;
haritada 53 demir kayası; demir kazma kayayı 15 vuruşta kırdı (hurda 60 → 165, taş 20 → 34, dayanıklılık
500 → 485); demir kazma tarifi kuyruğa alındı (dövme demir 20 → 0, kumaş 4 → 2, tutkal 4 → 2, odun
50 → 40). Konsol temiz. 85 test.

Ölçülemeyen: gerçek fareyle zombiye vuruş. Bu oturumda Play'de karakter kendiliğinden yürüdü:
`UserInputService:GetKeysPressed()` W, D, S'yi sırayla basılı gösterdi (büyük ihtimalle kullanıcı aynı
anda oyundaydı). Karaktere dokunan testler durduruldu.

### 28. Bölüm: kayıt, sistemler ve öz eleştiri turu (2 Kasım)

Kullanıcı önce kaydı onayladı, sonra "sormadan devam et", en son "kendi tercihlerinle devam et, kendi
ürününü her seferinde eleştir" dedi. Commit listesi ve özet DEVAM.md'nin başında; kayıt ayrıntısı
[SAVE.md](SAVE.md). Bu turun ölçümleri:
- Zombiler yalnızca oyuncu çevresinde doğuyor: en yakın zombi 71–85 stud, can 100'de kaldı.
- Arabalar: aramada 2000 zarda %20,3 boş (eski tek zar), hurda 3–8; taş kazma vuruş başına 1 hurda.
  Sonra zar 2'ye çıktı (%9 boş).
- Konteyner kaydı: 183 konteynerin kimliği benzersiz. Bir arabada kalan 5 elektrik parçası kaydedildi,
  alındı ve `LoadPart Containers` ile geri geldi.
- Katı zombiler: çarpışma kapalıyken 0,05 stud, açıkken 1,34 stud (temas); 80 zombiyle 59,5 FPS.
  Zombinin tepesinde duran oyuncu önce 10 sn hasar almadı (can 84). `ReachUpDistance` ile alttaki
  zombi bir gövde boyu yukarı uzanıyor: can 92→37. 1 bloklu sütunun (tahta parmaklık) ortasında duran
  oyuncu güvende kaldı: 15 sn'de 0 vuruş, en yakın zombi 2,90 stud (`ReachUpDistance` 2).
- Ölüm: ham kaynakların yarısı 300 sn'lik çantada (odun 50→25, hurda 60→30, lif 20→10, küçük taş
  20→10, kumaş 4→2, kil 20→10). Kereste, çerçeve, yiyecek ve aletler kaldı; ölüm yazısı ve "Your bag"
  işareti göründü. Yeniden doğuş 4,8 sn; yiyecek 100, su 99,9, dayanıklılık 100, can 100.

- Zırh: kapüşon + demir yelek (26 puan) Normal zombinin 8'lik vuruşunu 5,92'ye indirdi (4 vuruş); her
  vuruş iki parçayı 1 aşındırdı (250→246). Paneldeki kafa yuvasına tıklayınca kapüşon aşınmasıyla
  çantaya döndü ve şapka yeniden göründü. Yelek ölümden sonra kaldı. `ReloadCharacter` birebir aynı
  (artık zırhı da sınıyor). `ArmorTakeOff`'a kötü türler, NaN, 5000 karakter ve 200'lük sel gönderildi:
  hata yok, durum değişmedi. Rig kontrolü: 40 stud yürüyüşte boyun 0,405 rad dönerken kabuklar uzva göre
  0,0000 stud kaydı. Gerçek birinci şahısta (`LockFirstPerson`) kabukların LocalTransparencyModifier'ı 1,
  görüş temiz. Zırh yalnızca zombi vuruşunu keser; açlık/susuzluk ve bulanık su hasarı kesilmez.

Bu turda öğrenilen tuzaklar "Bilinen sorunlar" bölümünde (sahte depo, prompt seçimi, kamera yönü).
`user_mouse_input` ile bir arayüz düğmesine tıklamak için `instance_path` kullan
("LocalPlayer.PlayerGui.Armor.ArmorPanel.Head"): ekran görüntüsü piksel ölçüsü görüntü alanından küçük.

## Mevcut durum

| Alan | Durum |
| --- | --- |
| Harita (`MapService` + `World/*`) | Çalışıyor. 2048×2048; orman ve küçük kasaba, göl, taş ocağı, telsiz tepesi, çiftlik, kereste atölyesi, hurdalık. Arazi, 37 bina, yollar, sokak eşyaları, orman ve toplanabilir alt bitki örtüsü sunucu açılışında kodla kuruluyor. Toplanabilir her nesne `getHarvestables()` listesinde: düğüm adı (`Config.Harvest.Nodes`) ve her açılışta aynı kalan bir id (ileride dünya kaydı için). |
| Binalar | 15 şablon. Mobilyalı odalar, iki katlılarda merdiven, açılmış kapılar, tabelalar. Her model `Template`, `Loot` (`Food`, `Medical`, `Metal`, `Fabric`…), `Floors` ve `Region` özelliklerini taşıyor; loot sistemi bunları kullanacak. |
| Zombiler (`ZombieService`) | Çalışıyor. Humanoid yok. Akış alanıyla yol bulma, görerek kovalama, ses noktasına gitme, gezinme, eve girip çıkma, merdivenle üst kat, bina içinde uyuyan zombi, saldırı öncesi bekleme, sendeleme, dalgalı spawn, sunucu LOD'u (yakın 10 Hz, uzak 2 Hz), anlık görüntü yayını. Horde zombisi görmeden en yakın oyuncuyu kovalar ve koşar. API: `spawn(adet, horde?)`, `endHorde`, `forEach`, `queued`, `remove`, `clear`, `damage` (öldürünce true), `onDied`, `getPosition`, `hearSound`, `getStats`, `getNavGrid`, `reopenArea` (kalkan parçaların altındaki hücreleri arazi değerine döndürüp hâlâ duranları yeniden kapatır). |
| Envanter (`InventoryService` + `Shared/Inventory`) | Çalışıyor. 10 slot alet kemeri + 45 slot sırt çantası. Yeni eşya önce sırt çantasına girer. Her yığın kaynağını taşır; farklı kaynaklar birleşmez. Seçili slottaki eşya sağ elde görünür (stilize model, `Shared/HeldItems`; birinci şahısta `ViewmodelController` aynı modeli kameranın önünde çizer). API: `get`, `changed`, `give`, `room`, `take` (hep ya da hiç), `peekSlot`, `takeSlot`, `putSlot`, `giveBack` (hep ya da hiç iade), `count`, `getHeld`, `wearHeld`, `wearItem` (taşınan ilk kullanılabilir eşyayı aşındırır: çakmak), `onHeldChanged`. Oyuncu 7DTD başlangıç eşyalarıyla (kaynamış su, chili, bandaj) alet kemerinin 8–0 yuvalarında başlar. Atma: G (elde tutulan ya da çantada seçili yığın) veya çantadaki Drop düğmesi; `LootService` yığını ayağa torbayla bırakır. |
| İstemci | `ZombieRenderController` + `Modules/ZombieRig`: 17 parçalı rig, prosedürel yürüyüş, interpolasyon, LOD, ceset; `flinch(id)` hazır. `InventoryController`: alttaki alet kemeri, Tab, I / gamepad Y ya da her cihazda Bag düğmesiyle sırt çantası (Roblox oyuncu listesi kapalı); çantanın üstünde imlecin altındaki eşyanın bilgi paneli; tıkla-seç-bırak taşıma, sağ tık veya Split ile yarım yığın; 1–0 tuşları ve L1/R1 ile slot seçimi. `ToolController`: sol tık / gamepad R2 / mobilde Hit düğmesi; basılı tutunca aletin hızında vurur; nişan imlecin (serbest fare) ya da ekran ortasının altındaki noktaya; sağ omuzda prosedürel sallama; kırık alette uyarı. `PickupFeedController`: sağ kenarda "+N eşya" satırları (aynı eşya aynı satırda toplanır), sığmayanlar kırmızı. `TreeFallController`: devrilen ağacı yerelde oyuncudan uzağa yatırır ve soldurur. `CraftingController`: sırt çantası açıkken sağında crafting paneli (tarif satırları, sahip olunan / gereken, sayı, Craft; altta 4 işlik kuyruk ve geri sayım, tıklayınca iptal). Sırt çantasında Repair düğmesi seçili hasarlı aleti tamire yollar. `DebugOverlayController`: FPS, tick süresi, zombi sayısı, (debug yetkisiyle) tehdit ve otomatik spawn satırları; Spawn 1/80/120, Noise, GodMode, Kill, Give test items, Clear, Skip to next phase ve Auto spawn on/off düğmeleri. Spawn ve Clear otomatik spawn'ı kapatır. |
| Debug | Remote: `DebugCommand`. Yalnızca Studio'da veya `Config.Debug.AllowedUserIds` listesindeki hesaplarla çalışır (`11911303584` test eden hesap). Doğrulanır ve hız sınırlıdır. |
| Gündüz-gece (`DayNightService` + `Shared/DayClock`) | Çalışıyor. Döngü 11 dk, %60 gündüz (06:00–18:30), kalanı uzun gece. Dünya 1. gün 08:00'de başlar. Sunucu yalnızca 1. günün şafağının sunucu saatini ve horde aralığını ReplicatedStorage özelliği olarak yayar; istemci saati her karede kendisi hesaplar. Her 7. gece horde gecesi (`HordeNightDefault`; lobi seçimi gelince 5–10). API: `getState`, `isNight`, `isHordeNight`, `onPhaseChanged(faz, gün, horde)`, `skipPhase` (debug). Zombiler gece 1,1 sn'de, gündüz 1,5 sn'de vurur (7DTD). İstemci: `DayNightController` güneşi, parlaklığı ve ortam ışığını saate göre ayarlar; sağ üstte "Day N  HH:MM" (horde gününde kırmızı) ve horde gecesinde "Horde night" etiketi ile kızıl ton. |
| Tehdit ve nüfus (`ThreatService` + `Shared/Threat`) | Çalışıyor. Gürültü saniyede %5 söner; İz kaynakların toplamına hemen çıkar, düşünce günde 3 puan iner (kaynaklar: lamba, jeneratör, yanan ateş). Tehdit = İz + Gürültü × 0,35; 5 kademe (0/20/40/60/80); ilk 3 günde en fazla 3. Ağaca ve kayaya vuruş 1,5 gürültü ve 35 stud'luk ses, devrilen ağaç 6 / 70 stud; aynı oyuncunun 8 stud ve 4 sn içindeki vuruşları aynı ses noktasını tazeler. Ortam nüfusu: canlı oyuncu başına gündüz 6, gece 10 zombi, kademe çarpanı 1–1,6, en fazla 80; 2 sn'de bir en fazla 3 kuyruğa alınır, her oyuncudan 270 stud'dan uzak boştaki zombiler 4'er silinir (istemci 260'ta çizmeyi bırakır). Horde gecesi: oyuncu başına 20 zombi, gecenin ilk %60'ına yayılan 4 dalga; ortam spawn'ı durur; şafakta kalanlar sıradan zombiye döner. Oyuncu tehdidi görmez; yalnızca debug paneli. API: `emit(tür, konum, oyuncu?)`, `setTraceSource`, `getTier`, `setDirectorEnabled`, `getStats`. |
| Hayatta kalma (`SurvivalService` + `Shared/Vitals`) | Çalışıyor. Can (Humanoid), dayanıklılık, yemek, su; hepsi 100 ve sunucuda. Her 0,5 sn: yemek oyun günü başına 30, su 40 düşer; dayanıklılık saniyede 10 dolar (su bandı: su ≥%50 ×1, ≥%25 ×0,5, altı ×0,25, 0'da hiç), dolan her puan 0,00408 yemek ve 0,00453 su yer; doğal can günde 60 (×su bandı), iyileşen her can 0,06 su. Açlık / susuzluk kademeleri %50 / %25 / %2'de (çıkış %52 / %27 / %4), her biri dayanıklılığın %20 / %40 / %60'ını bloklar ve ikisi toplanır (taban 10). Son kademede 2,2 sn'de 0,25 can (ikisi toplanır, gerçek zaman), doğal iyileşme yok. Vuruş aletin dayanıklılığını ister ve harcar. Koşma: Shift basılı, gamepad L3 veya dokunmatikte Run düğmesi aç/kapa; sunucu WalkSpeed 24 yapar, hareket ederken saniyede 4,5 düşer, 0'da biter, ancak 25'te yeniden başlar; 2 sn'de bir Sprint gürültüsü. Zıplama 20 (sunucu kökün yükselişinden sayar). Elde yiyecek / içecek / ilaç "use" ile kullanılır (1 sn): yemek saniyede 1 girer, can 0,5/sn (bandaj 2/sn). Boş el göl suyuna "use": +10 su, −5 can. Ölünce taşınan her ham kaynağın (odun, küçük taş, lif, hurda demir, kumaş) yarısı 5 dk'lık torbaya düşer, istatistikler doğunca dolu. Oyuncu öznitelikleri: `Stamina`, `StaminaCap`, `Food`, `Water`, `Hunger`, `Thirst`. Debug: `SetFood`, `SetWater`. |
| İnşa (`BuildService` + `Shared/BuildGrid`) | Çalışıyor. 4 stud'luk küp ızgara; sütunları yol bulma ızgarasıyla aynı. Elde Wood Frame, Wood Ladder veya Wood Door varken "use" (sol tık, R2, Hit) bloğu koyar: sunucu baştan nişan yönünde 24 stud ışın atar, vurduğu bloğun yanına ya da yüzeyin hemen üstündeki hücreye koyar (zeminde blok toprağa en fazla bir hücre gömülür, havada durmaz). Ret: dolu hücre, harita parçası (duvar, ağaç, tabela), karakter veya zombi içinde (blok, hücre ortasının altındaki döşemeye ya da bordüre 1,25 stud'a kadar gömülebilir), su, oynanmaz alan, kasaba binasının zemin katından yukarısı (kattan 2 hücre, yani kapı boşluğu yüksekliği), 2000 blok, zemin ya da komşu blok desteği yok. Taş balta bloğa vurunca hasar vermez: hasarlıysa vuruş başına 100 can tamir eder (7DTD'nin tam tamir için 3 odununun payı, yukarı yuvarlanmış), çerçeveyi 3 vuruşta 4 keresteyle ahşap bloğa, ahşap bloğu 3 vuruşta 10 kırık taşla 1500 canlı kırık taş bloğa çevirir (tamiri vuruş başına 1 kırık taş, tam tamir 15; aletlere taş). Vuruş başı payın yukarı yuvarlanması yüzünden tam tamir ahşap blokta 5 odun, kapıda 10 odun eder. Diğer aletler ahşap çarpanıyla hasar verir. Yere bağlantısı kopan bloklar düşer (7DTD yapısal destek, yatay açıklık sınırı yok). Zombiyi engelleyen sütun (zeminden 2 ile 6 stud arası) yol bulmada blok canına göre 2–8 maliyetli hücre olur; kovalayan ya da sese giden zombi önündeki en zayıf bloğa 7 hasar vurur (1,5 / gece 1,1 sn). Merdiven `TrussPart`: oyuncu tırmanır, zombiyi engellemez. Kapı (1000 can) iki hücre tutar (üst hücre boş olmalı), 0,35 stud kalınlığında bir panel: kuranın durduğu yüze asılır, `ProximityPrompt` (Open / Close) ile hücresinin içine 90° döner. Sunucu canlı karakteri, 8 + 4 stud mesafeyi ve saniyede 4 aç/kapa sınırını denetler; aralıkta karakter ya da zombi varken kapatmaz. Açık kapı yol bulmada boş hücre sayılır ve zombi vuruşu onu atlar; kapalı kapı 1000 canlı duvardır, bu yüzden zombi genellikle yanındaki daha zayıf bloğu kırar. Zombi kapı açmaz (7DTD). Kilit yok. Tahta kazık (`Trap`) çarpışmasız, zombiyi yavaşlatıp yaralar ve aşınır (yukarıdaki 25. bölüm). Tahta parmaklık (`Bars`) aynı yolla konur ve kırılır; kutusu "Bars" çarpışma grubunda olduğu için "Shots" grubuyla atılan mermi, ok, zombi görüşü ve yakın dövüş duvar kontrolü içinden geçer (dünya vuruşu, yani tamir / hasar için alet vuruşu, parmaklığa yine çarpar). Bloklar zombi görüşünü keser, loot torbası üstlerine düşer, her blok İz'e 0,04 ekler. Kayıt yok. API: `getCount`, `clear` (debug). |
| Kamera (`CameraController`) | Çalışıyor. V: omuz (varsayılan) → birinci şahıs → serbest fare. Omuzda Roblox shift lock mekanizması (her karede `MouseBehavior.LockCenter` + `RotationType.CameraRelative`), `Humanoid.CameraOffset` (2, 1,5, 0), ortada 6 px nişangâh. UI açıkken ve Sol Alt basılıyken imleç serbest. Fareyle bakış MCP ile ölçülemedi (MCP fare hareketi delta üretmiyor) |
| Görev zinciri (`ChallengeService` + `Shared/Challenges`) | Çalışıyor. 19 görev, tek izlenen görev sayar, Gather hedefleri envanterden okunur. Kayıt yok |
| Vuruş (`ToolService` + `Shared/Melee`) | Çalışıyor. İstemci yalnızca nişan yönünü yollar. Sunucu: birim vektör, hız sınırı (4/sn), aletin 7DTD aralığı (60/APM + 0,1 sn, %12 tolerans), hedefi kendi baş konumundan seçer: menzildeki en yakın zombi (silindir + baktığı yöne eğik kafa küresi), arada duvar varsa vurmaz. Hasar 7DTD: yumruk 5, taş balta 6, taş kürek 9, taş kazma 7, tahta sopa 12, taş mızrak 12; kafaya ×2. Mızrağın yalnızca hafif saldırısı var (güçlü saldırı ve fırlatma yok). Alet yalnızca isabette 1 aşınır; 0'da kullanılamaz. Dünyaya isabet `onWorldHit` dinleyicilerine gider (toplama). Oyunculara vuruş yok (PvP lobi seçeneği gelince). |
| Depolama sandığı (`StorageService` + `StorageController`) | Çalışıyor. Blok `Size` 3,6 × 2,6 × 2,8, zombiyi durdurur, kırılır, taş baltayla 3 odunla tamir edilir. "Open" (0 sn, 8 stud): sunucu canlı karakteri ve 12 stud'u denetler, oyuncuyu izleyici yapar ve 36 yuvayı yollar (`StorageUpdate`). İstemci sırt çantasını açar, sandık panelini crafting panelinin yerine koyar (6 × 6). `StorageAction`: "Take" (sandık yuvası → envanterde sığan yere), "Put" (envanter yuvası → seçilen boş sandık yuvası ya da sığan yer; sığmayan yerinde kalır), "TakeAll", "Close"; oyuncu başına saniyede 12, açık sandık, menzil ve yuva aralığı denetlenir (NaN, 0, taşan sayı reddedilir). Sunucu 0,5 sn'de bir uzaklaşan ya da ölen izleyiciyi kapatır; çantayı kapatmak sandığı kapatır. Kırılan sandık içindekileri yerine bir torba olarak bırakır. Kayıt yok. |
| Grafik ayarları (`GraphicsController` + `Shared/Graphics`) | Çalışıyor. `Config.Graphics.Presets`: Low (zombi 160 stud, ayrıntı 25, animasyon 45, ceset 3 sn, gölge / bloom / ışın kapalı, lamba ışığı ×0,6), Medium (260 / 45 / 70 / 6 sn, hepsi açık, ×1; eski görünüm), High (260 / 60 / 100 / 12 sn, hepsi açık, ×1,2). Zombi çizim mesafesi `ZombieVisual.RenderDistance`'ı (260) geçmez; sunucu despawn'ı ona göre. DepthOfField'e dokunulmaz (kapalı kalır; uzaktaki zombiyi bulanıklaştırırdı). Roblox kalite ayarı değişince Auto yeniden seçer. Seçim oturumluk, kayıt yok. `Terrain.Decoration` script'ten değişmiyor; partikül efekti yok. |
| Jeneratör ve lamba (`PowerService` + `Shared/Power`) | Çalışıyor. İkisi de inşa bloğu (`Size` alanı: hücre tabanında küçük kutu; `BuildGrid.plotCFrame` ile zemine oturur). Jeneratör 3,2 × 2,4 × 2,2, zombiyi durdurur ve kırılır; lamba 0,4 × 3,2 × 0,4 direk, `Passable` (zombi geçer). Kablo yok (PLAN: elektrik ağı sonraya). Jeneratör: tek "Turn on / Turn off" istemi (8 stud, oyuncu başına saniyede 4), nesne metni "Generator  Gas x/1000"; benzinsiz açılmaz. Elde Gas Can varken "use": sunucu baştan 8 stud ışın atar, jeneratöre değerse en çok 250 benzin döker (depoyu taşırmaz, taşınan kadar). Saniyede bir: çalışan jeneratörler (yakıtı > 0) 48 stud içindeki lambaları anahtar sırasıyla, en yakın jeneratörden, 50 W bitene kadar yakar (dünyada en çok 40 lamba); her jeneratör yalnızca yüklü watt için yakar (5 W lamba günde 9 benzin; yüksüz jeneratör yakıt harcamaz ama ses yapar). Benzin bitince jeneratör durur. Yanan lamba: Neon baş + PointLight (20 stud, gölgesiz). Çalışan jeneratör 3 sn'de bir "Generator" gürültüsü (3 puan, 90 stud; tek ses noktası, Noise ≈ 21'de dengelenir); İz: yanan lamba 1,5, çalışan jeneratör 3 (`Power` kaynağı). Jeneratörün üstünde gösterge: çalışırken yeşil Neon, dururken kırmızı. Kırılan jeneratörün lambaları söner. Kayıt yok. |
| Tarım (`FarmService` + `Shared/Farming`) | Çalışıyor. Farm Plot bir inşa bloğu (`Plot = true`): hücresinin dibinde 0,8 stud'luk yassı parça; hücreye yükselen zemin varsa onun üstüne kalkar (`BuildGrid.plotCFrame`). Yol bulmada geçilir, zombi vuruşu onu seçmez, taş baltayla 14 kille tamir edilir. Elde tohum (`Seed` alanı) varken "use": sunucu baştan 24 stud ışın atar, tarlaya değerse ve tarlada ekin yoksa tohumu harcar. Ekin 3 aşamalı; aşama `StageDays` (1,05) × gün süresi (≈ 11,5 dk), olgunluk ≈ 23 dk; sunucu saniyede bir bakar ve modeli yeniden kurar (filiz, büyüyen bitki, ürünlü bitki). Olgun ekinde 0,5 sn basılı "Harvest" istemi (8 stud): sunucu canlı karakteri ve mesafeyi denetler, 2 ürün + %50 bir ürün daha ve 1 tohum verir (sığmayan ayağa düşer), ekin kalkar, tarla kalır. Ürünler yenir: mısır 2 yemek + 3 can, patates ve yaban mersini 2 yemek. Tohum kaynağı: dolap (mısır, patates tohumu), raf (yaban mersini tohumu), buzdolabı (mısır, patates); 5 ürün = 1 tohum. Ekinler `workspace.Crops` içinde, kayıt yok. Debug: `GrowCrops` hepsini olgunlaştırır. API: `ripenAll` (debug). |
| Yay (`RangedService` + `Shared/Ballistics`) | Çalışıyor. Elde yay varken "use" ok atar (germe yok; her atış tam gerili). Sunucu: kendi atış aralığı (1 sn, %12 tolerans), yayın dayanıklılığı, oyuncu başına havada en çok 6 ok; envanterden 1 ok alır (hep ya da hiç), yayı 1 aşındırır. Ok sunucunun baş konumundan çıkar, 88 stud/sn hızla ve 11,2 stud/sn² yerçekimiyle Heartbeat'te uçar; her adım `Melee.hitBody` ile zombilere (kafa ×2) ve ışınla dünyaya (duvar, blok, arazi, su) sınanır, hangisi yakınsa orada durur. 280 stud'da düşer. Yalnızca zombilere hasar verir; vurulan zombi atanı kovalar (yakın dövüşteki gibi). Ok geri alınmaz, bloğa hasar vermez, ses çıkarmaz. İstemci: `ArrowFired` (id, çıkış, hız, yerçekimi, sunucu saati) ile yayı her karede kendisi hesaplar; `ArrowStopped` ile oku durduğu yere saplar, 6 sn sonra siler; zombiye saplanan ok hemen silinir, zombi sendeler. Elde yay varken ok yoksa "No arrows". |
| Boru tabanca (`RangedService`) | Çalışıyor. Yay yolunu kullanır; ek olarak oyuncu ve silah başına şarjör sayacı (6 atıştan sonra bir sonraki atış 2 sn bekler; silah değiştirmek sayacı sıfırlamaz), sunucuda rastgele 1,5° sapma (`Ballistics.spread`), her atışta `ThreatService.emit("Gunshot")`. `ArrowFired` artık cephane kimliğini de taşır; `Tracer` cephanesi istemcide 5 stud'luk neon iz ve 0,06 sn'lik namlu ışığıdır, durduğu yerde silinir. Mermi yalnızca zombiye hasar verir. Silahın `SoundId` alanı doluysa her istemci atış sesini namluda çalar (`ArrowFired` silah kimliğini de taşır; ses 4 sn sonra silinir); şimdilik boş, yani atış sessiz duyulur, zombiler yine duyar. Uzaklıkla hasar düşüşü yok. Boru tüfek, pompalı (fişek başına 10 saçma, her biri ayrı uçuş kaydı) ve makineli de aynı yolu kullanır; nişan alma (`AimIntent`) sapmayı silahın `AimSpread` payına indirir, istemci kamerayı FOV 50'ye yaklaştırır. |
| Toplama (`HarvestService` + `Shared/Harvest`) | Çalışıyor. 7DTD formülü: verimin üçte ikisi nesnenin toplam hasarıyla orantılı olarak vuruşlarda, üçte biri kıran vuruşta; iyi alet yalnızca hızlandırır. Silahlar (tahta sopa, taş mızrak; 7DTD HarvestCount −0,75) odun, taş, kil ve kumun dörtte birini verir (aşağı yuvarlanır: çalıdan odun çıkmaz), lifin tamamını. Hasar = aletin blok hasarı × malzeme çarpanı, tam sayıya kesilir, en az 1. Aynı nesneye vuran herkes aynı hasarı paylaşır. Ağaç: 300/30, 600/70, 900/110, 1200/150 (can/odun, boy ölçeğe göre). Çalı 1–3 odun, ot 2 lif, yerdeki taş 1 taş (E ile de alınır), kaya 400 can / 22 taş. Devrilen ağaç çarpışmayı hemen bırakır, altındaki yol hücreleri açılır, 3,5 sn sonra silinir. Kasaba mobilyası da düğümdür (şömine hariç; `Config.Harvest.Furniture`): kırılınca yol hücreleri açılır, kap içindekini torbaya döker. Pencere camları (`HarvestNode` özelliği) tek vuruşta kırılır. Hiçbir şey yeniden çıkmaz (7DTD). Sığmayan eşya kaybolur ve kırmızı satırla bildirilir (loot torbası gelince yere düşecek). |
| Crafting (`CraftingService` + `Shared/Crafting`) | Çalışıyor. 7DTD sırt çantası crafting'i: 4 işlik kuyruk, yalnızca ilk iş sunucu saatiyle ilerler (çanta kapalıyken de). Süre = Σ adet × malzeme süresi (odun, taş, lif 0,2 sn; diğerleri 1 sn), tarif kendi süresini verirse o. Malzemeler kuyruğa alınırken kaynaklarıyla düşer; iptal kalanı iade eder. Sığmayan ürün kuyrukta "No room" ile bekler. İadesi sığmayan iptal reddedilir ve kırmızı satırla bildirilir (loot torbası gelince yere düşebilir). Tamir: hasarlı taş alet + gereken taş (taş başına 300 dayanıklılık, 0,5 sn) kuyruğa girer; alet boşsa eski slotuna döner. Kuyruk oyuncu çıkınca kaybolur (kayıt yok). Tarifler: taş balta, taş kürek, taş kazma, tahta sopa, taş mızrak, kereste, çerçeve, merdiven, kapı, toprak. İstasyon tarifleri (`Station`, `Tool`): sunucu kuyruğa alırken canlı karakterin 10 stud içinde o türden konmuş blok olduğunu ve aletin envanterde olduğunu denetler; iş sonra oyuncunun kuyruğunda sürer (uzaklaşınca durmaz, alet harcanmaz). |
| Kamp ateşi ve pişirme | Çalışıyor. Kamp ateşi `Size` 3,2 × 0,9 × 3,2 taş blok, zombiler içinden geçer (`Passable`), kırılır, taş baltayla 5 taşla tamir edilir. `CraftingService` konunca ateş (`Fire`), sıcak ışık (16 stud, gölgeli), iki kütük ve "Cook" istemi ekler; istem istemcide sırt çantasını açar. Fırında patates, közde mısır (ızgara), kaynamış su (tencere). Yakıt yok. |
| Loot (`LootService` + `Shared/Loot`) | Çalışıyor. Ölen zombi %20 ihtimalle torba bırakır (7DTD %2–4). Torba: bir ortak seçim (3–10 hurda demir, 2–6 kumaş, 5–15 küçük taş, chili veya köpek maması konservesi, şişe su, bulanık su, ilk yardım bandajı) ve %15 ihtimalle %30–100 dayanıklılıkta taş alet ya da silah. 18 slot, 20 dk ömür (7DTD 1.x), dünyada en fazla 60 torba (en eski silinir). E'yi 1 sn basılı tutunca sığan alınır, kalanı torbada kalır; boşalan torba silinir. Sunucu torbanın varlığını, canlı karakteri, mesafeyi, basılı tutma süresini ve hızı yeniden denetler. `LootService.drop(konum, yığınlar, birleştir)` başka servislerden de kullanılır: sığmayan toplama eşyası ve crafting iadesi oyuncunun ayağına düşer, 6 stud içindeki torbaya eklenir. Torba içeriği yalnızca sunucuda. |
| Bina kapları (`LootService`) | Çalışıyor. `Config.Loot.ContainerFurniture` 11 mobilyayı 6 kap türüne bağlar (buzdolabı, dolap, raf, gardırop, ilaç dolabı, depo); haritada 174 kap. Her mobilyanın önünde (pivot önü, yarı yükseklik, en çok 3 stud) basılı tutulan "Search" istemi; görüş hattı kontrolü istemde kapalı, sunucu baştan noktaya ışınla duvarı kontrol eder. İlk aramada sunucu zar atar (her atış %25–35 boş; binanın `Loot` özelliği kap türünün `Bonus`'una uyarsa bir atış daha), 7 oyun günü sonra yeniden. Kap bütün oyuncular için ortak; boşalınca "(empty)" yazar. Mobilya modellerinin `WorldPivot`'u hücre tabanı, önü −Z. |
| Kazı (`DigService`) | Çalışıyor. Araziye vuruş, vurulan noktanın 4 stud'luk sütununa aletin blok hasarı × malzeme çarpanı kadar hasar verir; verim toplama formülüyle ödenir; tam hasarda sütunun tepesinden bir voksel (4 stud) iner. Otlu sütuna (çim, yapraklı çim) ilk vuruş otu biçer: `Config.Harvest.Nodes.Grass` kadar lif (2) verir ve sütunun üst 2 stud'unu toprağa çevirir; sonraki vuruşlar kazar. Malzeme ilk vuruştaki arazi malzemesidir (`Config.Dig.Materials`): çim 250 can / 22 kil + 2 lif, toprak ve çamur 200 / 22 kil, kum 100 / 11 kırık kum + 2 kil, çakıl 200 / 8 kırık kum + 9 taş, kar 160 / boş, kaya 500 / 55 küçük taş (vurunca Harvest gürültüsü). Asfalt, kaldırım ve su kazılmaz. Arazi: 2 voksel yüzey malzemesi, sonra toprak, 12 stud altı kaya; dibinde (−24) bir voksel ana kaya kalır, yani 0 yüksekliğindeki zemin 4 kat kazılır. Ret: oynanmaz alan, su ve çevresindeki 8 sütun, bina ayak izi + 4 stud, sütunda çarpışan harita parçası (ağaç, kaya, eşya) veya blok, vuruş sütunun tepesinden 6 stud'dan aşağıdaysa (tünel yok), sütun yan komşusundan 8 stud'dan (2 voksel) fazla aşağı inecekse. Sütundaki çarpışmasız harita modeli (ot) zeminle iner. Kazılan sütunun voksel yüksekliği servisin `levels` tablosunda; yükseklik ızgarasına bir kare sonra sütun ve 8 komşusunun ortasından okunan gerçek yüzey yazılır ve `MapService.markRough` ile işaretlenir; `MapService.heightAt` işaretli sütunlarda yüksekliği ışınla okur. Yol bulma hücreleri değişmez: zombi çukura iner ve çıkar. Dirt (`Fill = "Ground"`) elde "use" ile kazılmış sütunu bir voksel doldurur: hedef nişanın değdiği yüzün önündeki sütun, kazılmamışsa en yakın kazılmış yan sütun; yalnızca kazıdan önceki yüksekliğe kadar ve adım kuralına uyarak; sütunda oyuncu ya da zombi varsa reddedilir. API: yok (dinleyici). |
| Perk, kayıt, monetizasyon | Bilerek yazılmadı. |

### Ölçümler

Ölçümler 30–31 Ekim 2026'da PC'de, Studio içinde alındı. Telefonda ölçüm yok.

- **Testler:** 79/79 geçiyor (1 Kasım; aşağıdaki döküm 70 testlik eski hâl, sonra başlangıç eşyası,
  görev zinciri ve eşya bilgisi testleri eklendi) (NavGrid 8, HeightField 3, Buildings 5, ZombieProtocol 3, ZombieLook 3,
  Inventory 7, Melee 5, Harvest 6, Ballistics 2, Farming 1, Power 1, Graphics 1, Crafting 7, Loot 3,
  DayClock 2, Threat 4, BuildGrid 5, Vitals 4).
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
- **Kazı (Play, 31 Ekim):**
  - Taş kürekle çim 7 vuruş / 22 kil + 2 lif, toprak 6 vuruş / 22 kil; kazmayla kaya 20 vuruş /
    55 taş, gürültü 0 → 17,8. Toprak kazısı gürültüsüz.
  - Roblox yumuşak arazisi dar çukurları yuvarlıyor: tek sütun −4 / −8 / −12 kazılınca yüzey ortada
    −2,67 / −6,67 / −8,00 (kapanıyor); 1×2 hendek −12'de −8; 3×3 çukurda halka −8 ve merkez −16
    iken merkez −15,8, halka −7. Bu yüzden adım kuralı (2 voksel) kondu. Karakteri kapanmış çukurun
    içine ışınlamak onu araziden düşürür (−400'e); normal kazıda olmadı.
  - Artı şeklinde çukurdan (merkez −12, yanlar −4) geçen zombinin ayağı yüzeyden en çok 0,5 stud
    aşağıda (düz zeminde 0,15); ışınla yükseklik okumadan önce 1,4–1,85 stud gömülüyordu.
  - Ret: asfalt yol, Market'in 2 stud yanı, göl kıyısı (kum) 4 vuruşta eşya vermedi ve inmedi; 3. kat
    (adım kuralı) ve −16'dan sonrası (ana kaya) reddedildi.
  - Dirt: 2 kazıdan 44 kil, 2 Dirt üretildi; çukurun içinde dururken doldurma reddedildi; 8 stud
    yandan iki doldurmayla −8 → 0 (yüzey 0,00); eski yüksekliğin üstüne ve kazılmamış zemine
    doldurma reddedildi. Üretim panelinde Dirt satırı kaydırınca görünüyor.
- **Kapı (Play, 31 Ekim):**
  - Kapı 4 × 8 × 0,35 panel olarak kuruldu; Open / Close paneli açık konuma döndürüp geri getirdi;
    aralıkta dururken Close reddedildi; kapalı kapıya yürüyen oyuncu panelin önünde durdu.
  - 14 çerçeve + kapıdan 3×3 çit, oyuncu içinde, 1 zombi ve her saniye Noise: kapı açıkken zombi
    28. saniyede kapıdan girdi, hiçbir blok hasar almadı. Kapı kapalıyken zombi kapıya dokunmadı
    (1000 / 1000), doğudaki çerçeveyi kırdı (üstteki de düştü) ve 66. saniyede içeri girdi.
- **Takılan zombiler (Play, 31 Ekim):** açık arazide 80 zombi ve 40 sn Noise sonrası 8 sn içinde
  0,3 stud'dan az kımıldayan kovalayan / sese giden zombi: düzeltmeden önce 10 (biri oyuncudan
  30 stud uzakta, yalnızca bir eksende kayarak), sonra 2 (ikisi de oyuncunun 5,4 stud yakınındaki
  kalabalıkta); oyuncuya ulaşan 63 → 72.
- **Silahlar (Play, 31 Ekim):** tahta sopa küçük ağacı (300 can, 11 hasar) devirdi, 7 odun verdi
  (30'un dörtte biri); taş mızrak tek zombiyi gövdeye 10 vuruşta öldürdü (125 ± %15 can, 12 hasar);
  sopa + mızrak üretimi 8 odun, 5 taş, 3 lif harcadı.
- **Yay (Play, 31 Ekim):** tek zombiye 38, 34, 30, 25 ve 21 stud'dan 5 ok, 5 isabet, zombi öldü
  (30 × 5 ≥ 107–144 can); uçuşta istemcide bir ok çizildi, durunca silindi. Ahşap çerçeveye atılan ok
  çerçevenin yüzünde durdu (x = −52,0). 14 ok yere atılıp bitince atış olmadı; yay 20 atışta
  100 → 80.
- **Boru silahlar ve nişan (Play, 31 Ekim):** tüfek: ilk atış, 0,4 sn sonraki atış reddedildi, 3,1. sn'de
  yeniden atış; ikinci mermi zombiye isabet etti. Pompalı: her atışta 10 saçma (`AmmoShotgunShell`),
  en büyük sapma 4,65°; 10 stud'daki canlı zombiye 10/10 ve 6/10 isabet, zombi öldü (sonraki turlarda
  ölçülen "0 isabet" 6 sn yerde kalan cesede nişandı). Makineli: 0,18 sn aralık, 15. mermiden sonra
  2,75 sn doldurma; kalçadan 19 atışta en büyük sapma 2,97° (ortalama 1,80), nişanla 0,64° (0,39).
  Sol tık basılı tutunca kendi kendine 0,18 sn aralıkla ateşledi. Sağ tık basılı: FOV 70 → 50,
  bırakınca 70; nişanlıyken silahsız slota geçince 70'e döndü; silahsız elde sağ tık FOV'u değiştirmedi.
  Dokunmatik "Aim" düğmesi oluşuyor, dokunmatik olmayan Studio'da gizli (dokunmatikte denenmedi).
  Konsol temiz.
- **Yatak rulosu (Play, 31 Ekim):** varsayılan doğuştan 60 stud öteye kondu (18; 0,17; 122). Oyuncu
  40 stud uzaklaştırılıp öldürülünce 4,2 sn sonra (18; 3,45; 122)'de doğdu. Rulo taş kürekle 3 vuruşta
  kırıldı (lif 10 → 16: 5 + 1). Yeniden ölünce harita doğuşunda (−38; 4,1; 127) doğdu. Konsol temiz.
- **Tuzak maliyeti (31 Ekim):** `checkTraps`'in işi (20 tuzak × 120 zombi `bodiesNear` + kutu kontrolü)
  sunucu komut bağlamında tek kontrolde 0,062 ms, 0,2 sn aralıkla saniyede 0,31 ms.
- **Duman testi (Play, 31 Ekim):** 80 zombi + yönetici açık: tik ort./en çok 0,09 / 1,79 ms. Taş balta
  üretimi 1 → 2. Çam 32 balta vuruşunda devrildi, 48 → 118 odun. Tezgâh (100 can) 5 vuruşta kırıldı,
  +1 odun. Raf araması (E basılı 1,6 sn) 1 yaban mersini tohumu verdi, raf "(empty)" oldu. Konsol
  temiz (yalnızca Studio Assistant'ın "execute_luau changed camera type" notu).
- **Görünmeyen istemler (31 Ekim, çözülmedi):** uzun bir MCP test oturumunda bir noktadan sonra hiçbir
  `ProximityPrompt` görünmedi (`PromptShown` hiç gelmedi, E tuşu çalışıyordu: I çantayı açtı). Yeni Play
  oturumunda aynı adımlar (tüfekle sağ tık nişanı, balta, ölümsüzlük, 80 zombi + yönetici, ağaç ve
  mobilya vuruşu, ışınlanma) istemleri bozmadı. Studio Assistant'ın kamera türünü "Fixed"e çevirmesiyle
  ilgili olabilir; oyunda görülürse adımlar not edilmeli.
- **Sağ tıkla kamera dönüşü:** MCP fare sürüklemesi nişansızken de kamerayı döndürmüyor, bu yüzden nişan
  alırken kameranın dönüp dönmediği ölçülemedi. `ToolInput` bağlamında `Sink` yok (varsayılan kapalı);
  elle kontrol edilmeli.
- **Blok düşüşü (Play, 31 Ekim):** çerçeve taş kürekle (ahşaba 11 hasar) 10 vuruşta kırıldı, odun
  50 → 51 (5. vuruş) → 52 (kıran vuruş); kamp ateşi 10 vuruşta kırıldı, taş 20 → 23. Konsol temiz.
- **Kırık taş (Play, 31 Ekim):** 2 kırık taş üretimi 2 kil + 2 taş harcadı. Çerçeve 3 balta vuruşunda
  ahşap blok (kereste 20 → 16), 3 vuruş daha kırık taş blok oldu (1500 can, Cobblestone malzeme, taş
  22 → 12). Taş kazma bir vuruşta 26 hasar verdi (ahşap sayılsa 5); balta tamiri 1474 → 1500, 1 taş.
  İlk denemede 9 stud'dan vurulan blok değişmedi: taş balta menzili 6,72 stud. Konsol temiz.
- **Cephane göstergesi (Play, 31 Ekim):** tabanca yuvası 6/30, yay 20, pompalı 1/20; iki tıkta 4/28,
  basılı tutunca 0/24, 2,2 sn sonra 6/24. Ekran görüntüsünde yazı yuvanın sağ üstünde okunuyor.
- **Tahta kazık (Play, 31 Ekim):** iki tuzak zombi ile oyuncu arasına konuldu (kutu çarpışmasız).
  Kovalayan zombi tuzaktan önce 4–6,6 stud/sn, tuzağın içinde 0,3–1,5 stud/sn yürüdü; tuzak canı
  0,77 / 1,78 / 2,83 / 3,85 / 4,88. saniyelerde 300 → 275 → 250 → 225 → 200 → 175 oldu, beşinci
  vuruşta zombi öldü (ZombieCount 0). 175 canda 6 kazık görünüyordu. Taş baltayla bir vuruş 175 → 275
  can, 50 → 46 odun, 9 kazık. İlk denemede hücrenin tam kenarından (z farkı 1,8) geçen zombiye vurmadı;
  kontrol o yüzden zombinin gövde yarıçapını da sayıyor. Konsol temiz.
- **Tarım (Play, 31 Ekim):** tarla düz zeminde 4 × 0,8 × 4 olarak y = 0,4'te kuruldu; mısır tohumu
  ekildi (tohum 2 → 1, filiz); "Grow crops" ile olgunlaştı (3,2 stud sap, 3 ürün, Harvest / Corn
  istemi); hasat 3 mısır + 1 tohum verdi, ekin kalktı, tarla kaldı. Yeniden ekilen tarla sopayla
  26 vuruşta kırıldı ve ekini de gitti.
- **Jeneratör (Play, 31 Ekim):** jeneratör düz zeminde (-50, 1,2, 126) kuruldu, 3 lamba 8–9 stud
  ötede. Benzinsiz açma reddedildi; iki "use" 0 → 250 → 500 benzin. Açınca 3 lamba yandı (Neon +
  ışık), gösterge yeşil; 52 stud ötedeki 4. lamba sönük kaldı. Noise 12 → 15,6'ya tırmandı (12 sn),
  İz 7,66 (3 × 1,5 + 3 + 4 blok × 0,04). Benzin yaklaşık 40 sn'de 500 → 497 (15 W: 0,04 / sn).
  Kapatınca lambalar söndü; yeniden açılıp sopayla 55 vuruşta kırılan jeneratörün lambaları söndü.
  İnşa önizlemesi jeneratörde 3,2 × 2,4 × 2,2, lambada 0,4 × 3,2 × 0,4 boyutunda (iç payı düşülmüş).
  Haritada 48 depo mobilyası var (24'ü metal binalarda, iki zar); tarif sayıları buna göre.
- **Grafik (Play, 31 Ekim):** bu PC'de (Roblox kalitesi 10) Auto High seçti. Fareyle Low: gölge,
  bloom, ışın kapandı; atmosfer (0,30) ve gece tonu aynı kaldı; lamba ışığı 12 stud. 80 zombiden
  ~200 stud uzaklaşınca Low'da 21 zombi çizildi (en uzak 156), Medium'da 59 (en uzak 255).
  Not: MCP `execute_luau` kamerayı Fixed'e çeviriyor; mesafe ölçümünden önce kamera Custom yapıldı.
- **Sandık (Play, 31 Ekim):** sandık (-50, 1,3, 134) kuruldu. İstemle açılınca çanta açıldı, sandık
  paneli 340 × 380 olarak crafting panelinin yerine geçti. Fareyle çantadaki 50 odun sandığın 8.
  yuvasına, taş balta 1. yuvasına kondu; 8. yuvaya tıklayınca 50 odun çantaya döndü; "Take all"
  sandığı boşalttı. Uzaktan yollanan 999, NaN ve 37 yuvalı istekler yok sayıldı. Oyuncu zombilere
  ölünce sandık sunucuda kapandı. 50 odun ve 300 benzinle dolu sandık sopayla 14 vuruşta kırıldı;
  yerinde çıkan torbadan 50 odun ve 300 benzin geri alındı. Roblox üst çubuk sağlık çubuğu kapalı.
  Test notu: Roblox yalnızca ekrandaki istemi gösterir; MCP kamerayı sabitlediği için istem testinde
  kamera nesneye çevrilmeli. Aynı tuşlu istemlerden yalnızca biri (en yakın / ekrandaki) görünür.
- **Evin içine inşaat (Play, 31 Ekim):** iki katlı House14'ün (316–348, 316–352) ön kapı boşluğuna
  (330, 350) bir çerçeve kondu, hücresi (82, 0, 87); bloğun altı döşemeye 1 stud gömülü. Üstüne
  ikincisi kondu (82, 1, 87); üçüncüsü (8–12 arası) reddedildi ve hayalet blok orada kırmızıydı,
  dışarıda yeşil. Arka kapı (334, 318) de kapatıldı. İçeride oyuncuya 80 zombi ve gürültü: 10. sn'de
  arka kapı bloğu 2/100 canda, 20. sn'de tüm barikatlar kırılmıştı (ön kapının üstündeki blok
  desteği gidince düştü). Üst kat zeminine (y 13) konan blok reddedildi. Konsol temiz. 37 binanın
  hepsi 0 yüksekliğinde (döşeme üstü 1,0); `BuildTop` hepsinde 5.
- **Kamp ateşi (Play, 31 Ekim):** kamp ateşsiz kuyruğa alınan fırında patates reddedildi. Kamp ateşi
  kuruldu (Fire, PointLight, iki Log, ProximityPrompt). 10,5 stud'dan istek reddedildi, 5,7 stud'dan
  2 patates + 1 su + 1 mısır kuyruğa girdi (10 / 10 / 5 sn); 36 sn sonra 2 fırında patates, 1 şişe su
  (bulanık su 3 → 2), 1 közde mısır; tencere ve ızgara envanterde kaldı. "Cook" istemi kapalı
  çantayı açtı; panel yakında yeşil "at a Campfire", 30 stud uzakta tarifi soluk gösterdi. Konsol
  temiz. Not: bu oturumda Studio ekran görüntüsü (Edit ve Play) beyaz geldi; ateşin görüntüsü
  gözle doğrulanmadı.
- **Boru tabanca (Play, 31 Ekim):** 0,5 sn arayla 10 atış isteği: 6 atış (30 → 24 mermi), sonraki 3
  istek doldurmada yok sayıldı, 10. atış geçti (23); dayanıklılık 300 → 293; istemcide 7 mermi izi.
  15 stud'daki zombiye 12 istek (doldurma dahil): 3 isabet, zombi öldü; Gürültü 60,8'e, tehdit
  kademesi 2'ye çıktı. Elde `Grip` + `Barrel` modeli. Konsol temiz.
- **Tahta parmaklık (Play, 31 Ekim):** oyuncu 8 parmaklıkla çevrili hücrede. "Shots" grubuyla atılan
  sunucu ışını parmaklığın içinden geçti, normal ışın parmaklığa çarptı. Zombi yolu kesilince parmaklığa
  vurdu (vuruş başına 7; bir parmaklık kırıldı, zombi içeri girdi. Süre ölçülmedi; Config hesabı
  300 / 7 ≈ 43 vuruş, gündüz 1,5 sn ile ≈ 64 sn, gece 1,1 sn ile ≈ 47 sn). Parmaklığın
  dışındaki zombiye tabancayla 3 isabet (mermi parmaklığın 4 stud'luk kutusunu geçti), mızrakla 4,9
  stud'dan 7 vuruşta öldü; parmaklığın canı yalnızca zombi vuruşlarıyla düştü. Ölümsüzlük kapalı,
  oyuncu parmaklığın iç yüzüne yaslı: zombi 36 sn parmaklığa vurdu, oyuncunun canı 100'de kaldı
  (zombi kafası ile oyuncu arası en az 5,1 stud yatay; vuruş menzili 3,6). Konsol temiz.
- **Mobilya kırma (Play, 31 Ekim):** haritada 444 mobilya (2 şömine kırılmaz). Market'teki buzdolabı
  taş kazmayla 12 vuruşta (14 sn) kırıldı: 3 hurda demir, içindekiler zemine (y 1,59) düşen 1 torbada;
  kazma 250 → 238. Buzdolabının hücresine çerçeve kondu (kural harita parçası olan hücreyi reddeder; mobilya gidince hücre boşaldı).
  House01'deki kanepe taş baltayla 14 vuruşta: +3 odun, +2 kumaş, torba yok. Konsol temiz.
- **Eşya atma (Play, 31 Ekim):** G ile eldeki 50 odun ayağa (y 1,6) bir torbaya düştü, slot boşaldı. Yedi
  hatalı `InventoryDrop` isteği ("x", NaN, sonsuz, 0, 999, 1,5, −3) hiçbir şeyi değiştirmedi. Çantadaki
  taş kazma aynı torbaya eklendi; torba E ile alınınca 50 odun ve dayanıklılığı 250 olan kazma geri geldi,
  torba silindi. Fareyle yuva seçip Drop: yuva boşaldı, torba düştü, düğme yeniden soluk. Ekran
  görüntüsünde dört başlık düğmesi aynı boyutta. Atış sesi kancası geçici bir motor sesiyle denendi:
  2 atışta namluda 2 ses (yüklendi, 2,59 sn), 5 sn içinde temizlendi; sonra kimlik yine boş. Konsol temiz.
- **Cam (Play, 31 Ekim):** haritada 274 cam modeli. Zemin kattaki bir cam (alt kenarı y 4, 4 × 5 stud)
  boş elle ilk vuruşta kırıldı; karakter yürüyüp zıplayarak kırık pencereden geçti. Konsol temiz.
- **Konsol:** Sunucu ve istemcide 0 uyarı, 0 hata.

## Teknik notlar

### Ekipman görsel yenilemesi (31 Ekim 2026, Codex)

Kullanıcı önce aletler ve silahları istedi. 13 elde taşınan eşya için ortak görsel fabrika yenilendi:
`HeldItems` → `EquipmentModels` → `EquipmentMeshes` / `EquipmentAssets`. Mesh/doku kimlikleri diskte
manifest olarak tutulur; kaynak doğruluğu yine disktir. Prosedürel profiller ve lif bağları, hatalı
üretilen başlıkların yerine kullanılır. Yeni remote veya hasar kuralı yok. Debug çantasında demir
balta ve demir kürek de var. Model listesi, yöntem, ölçümler ve tam kullanıcı testi
[EQUIPMENT_ART.md](EQUIPMENT_ART.md) içinde. 85 test geçti; 13 eşyanın karakter ve birinci şahıs
kimlikleri Play'de eşleşti; makineliyle 3 atış sunucudan doğrulandı. Mobil ölçülmedi.

Bu Codex ortamında sandbox içindeki geçici HTTP sunucusuna Studio erişemedi. Güvenilir alternatif:
`execute_luau` koduna diskten okunan kaynakları uzun Luau string'i olarak geçir; derledikten sonra
yalnızca değişen ModuleScript Source'larını güncelle. Harness'in `fetch("tests.luau")` ifadesini
bellekte test kaynağıyla değiştirerek `H.test(false)` çalıştırılabilir. Yeni HTTP sunucusu gerekmez.
Studio arka plandayken beyaz görüntü, computer-use ile Studio öne alınınca düzeldi.

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
   return H.sync() .. "\n" .. H.test(false)   -- beklenen: "70 passed, 0 failed"
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

- **Beyaz Studio görüntüsü (1 Kasım 2026):** Uzun bir MCP oturumundan sonra `screen_capture` hem Play
  hem Edit modunda bembeyaz döndü; Lighting değerleri normaldi. Kodla ilgisi yok: Studio'yu yeniden
  başlat.
- **Bayat script:** Place'te başka bir worktree'den kalma
  `StarterPlayerScripts.Client.Controllers.TurretController` var ve `[Net] unknown remote: TurretFired`
  hatası veriyor. Harness senkronu fazla script'leri silmiyor. Place'i paylaşan diğer oturumlara
  dokunmamak için silinmedi; kullanıcı kararı.
- **Ses kaynağı:** Mağaza aramasında yükleyici süzgeci yok. Pro Sound Effects adlarıyla ara
  (`... (SFX)`) ve `creatorName == "ProSoundEffects"` olanları al. Yükleyiciyi
  `GetProductInfoAsync` ile, sesin kendisini `PlaybackLoudness` zarfıyla doğrula ([SOUND.md](SOUND.md)).
- **Studio'da kayıt sahte depoda** (`Config.Persistence.StudioUsesLiveStore = false`): Play durunca
  silinir, yani gerçek yeniden başlatma Studio'da ölçülemez. Yükleme yolunu `DebugCommand("SaveReport")`
  ve ardından `DebugCommand("LoadPart", "<parça>")` ile sına.
- **E hangi istemi tetikler:** Yan yana iki konteynerde E, istemcinin seçtiği istemi tetikler (yere
  atılan çanta da araya girer). Testte `ProximityPromptService.PromptTriggered` ile hangi modelin
  arandığını kaydet; tek başına duran konteyner seç; eşyayı sunucuda karakteri uzağa taşıyıp at.
- **Hareket tuşları kameraya göredir:** Karakteri `PivotTo` ile çevirmek birinci şahıs kamerasını
  çevirmez. Kameranın bakışını oku; zombi arkadaysa S ile yürü.
- **Python ile dosya yazarken:** `open(p, 'w')` Windows'ta CRLF yazar; git commit'te LF'ye çevirir
  (uyarı verir, içerik doğru).

- **Telefonda FPS hiç ölçülmedi.** Aşama 1'in kapısı (kullanıcı erteledi). Bina parça sayısı hedefin
  üstünde; zombi başına parça sayısı 23 (15 gövde, 7 yüz ayrıntısı, 1 görünmez çarpıştırıcı).
- **Araç zinciri hiç çalıştırılmadı.** README'deki `stylua --check`, `selene src` ve `lune run tests/run`
  komutları bu makinede hiç koşmadı. İlk çalıştırmada format ve lint düzeltmeleri çıkabilir.
  `tests/run.luau`'nun gerçek Lune'da da geçtiği doğrulanmalı.
- **MCP sınırları:**
  - Script'ten `StreamingTargetRadius` ayarlanamıyor; yalnızca `default.project.json` içinde.
  - MCP üzerinden `Lighting.Technology` okunamıyor (yetki hatası).
- **Python konsolu cp1254 kodlamasında.** Türkçe veya Unicode yazdıran betiklerde
  `PYTHONIOENCODING=utf-8` kullan.
- **Tab tuşu:** Roblox oyuncu listesi Tab'ı oyundan önce alıyor; `InventoryController` listeyi kapatıyor
  (`SetCoreGuiEnabled(PlayerList, false)`), o zaman IAS Tab'ı alır.
- **Türkçe Q klavye:** noktalı "i" tuşu `KeyCode.Quote` olarak gelir (`GetStringForKeyCode`: I="I",
  Quote="İ"). `KeyCode.I` noktasız ı tuşudur. Kontrol listesi harfleri `GetStringForKeyCode` ile yazar.
- **Ekran görüntüsü BillboardGui çizmez.** Kafaya eklenen düz kırmızı BillboardGui bile görüntüde yoktu.
  Dünyadaki işaretleri ScreenGui ile çiz (ölüm torbası işareti böyle) ya da görüntüyle doğrulayamazsın.
- **Studio arka planda yavaşlar.** Studio penceresi öndeyken 60 FPS; arkadayken ~15 FPS ölçüldü (render
  CPU 3,5 ms, GPU 19,5 ms, kare 67 ms: kalan süre bekleme). FPS ölçümünü Studio öndeyken yap.
- **MCP fare hareketi delta üretmez.** Kilitli fareyle bakış (omuz kamerası) ölçülemez. Kamerayı
  test için `BindToRenderStep("TestCam", Enum.RenderPriority.Last.Value, ...)` ile sabitle,
  `WorldToViewportPoint` ile hedefi bul, `user_mouse_input` `mouseButtonClick` ile tıkla; sonra unbind.
  `execute_luau` kamera tipini sıfırlar.
- **Hızlı efekt doğrulama:** parçacık ve talaşlar 0,5 sn yaşar, ekran görüntüsü yetişmez. Testte
  `ParticleEmitter.TimeScale = 0` ve talaşları sabitlenmiş kopyalarla dondur.
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
- **Arazi değişikliği bir kare sonra görünür.** `WriteVoxels` sonrası aynı karede ışın eski yüzeye
  çarpar; `task.wait()` sonra yeni yüzey gelir (ölçüldü). Dar çukurlar yuvarlanır (Ölçümler, kazı).
- **`return assert(x, "...")` iki değer döndürür.** Tablo kurucusunun son elemanında mesaj da
  tabloya girer. Parantez kullan: `return (assert(x, "..."))`.
- **Ot ve çalı çarpışmasız ama sorgulanabilir.** Varsayılan `RaycastParams` (`RespectCanCollide =
  false`) bunlara değer. Yerleştirme gibi yeni raycast'lerde bunu hesaba kat.
- **Alt bitki örtüsü parça sayısını %64 artırdı** (14.492 parça). Telefonda ölçülmedi.
- **Arayüzü görüntüyle doğrula.** Alet kemeri slotları 2. adımdan beri 0×0'dı; yalnızca etiketleri
  görünüyordu ve `instance_path` ile tıklama yine çalıştığı için fark edilmedi. `UIListLayout`
  çocuğa boyut vermez; `UIGridLayout` hücreler alanı tam doldurursa yuvarlamayla son hücreyi alt
  satıra atar (crafting kuyruğunda görüldü, listeye çevrildi).
- **Fare tekeri slot değiştirmiyor.** Karar (kamera adımı): tekerlek zoom'da kalır, slot 1–0 ile.
- **Avatar eklemleri AnimationConstraint.** Studio'daki avatarlarda omuz, dirsek ve bel `Motor6D` değil
  `AnimationConstraint`; `C0` salt okunur ve `Attachment0.CFrame` değiştirmek pozu değiştirmiyor. Kodla poz
  `joint.Transform` üstüne `RunService.PreSimulation`'da bindirilir; Animator'ın atladığı karede iki kez
  döndürmemek için yazılan değer saklanır (`ToolController.layer`).
- **Bash heredoc'u bazen bozuluyor.** Bazı içerikler "unexpected EOF" ya da "Permission denied
  /c/Users/…" veriyor ve yama hiç uygulanmıyor. Uzun Python yamalarını Write ile scratchpad'e dosya
  olarak yaz, `python dosya.py` ile çalıştır; her değişimin tam bir kez eşleştiğini `assert` ile denetle.
- **`screen_capture` Play'de çalışıyor.** `camera_position` verildiğinde görüntü istenen noktadan
  değil oyun kamerasına yakın bir yerden geldi; bir kez denendi, kesin değil.
- **Play'de kendiliğinden yürüme.** MCP testinde karakter hareket ediyorsa önce
  `UserInputService:GetKeysPressed()` oku: kullanıcı aynı anda oyunda olabilir ya da bir `keyDown`
  bırakılmamış olabilir.
- **Git yedeği yok.** Uzak depo tanımlı değil. GitHub'a göndermek dışarıya açık bir adım olduğu için
  kullanıcıya sorulmalı.
