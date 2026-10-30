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

## Mevcut durum

| Alan | Durum |
| --- | --- |
| Harita (`MapService` + `World/*`) | Çalışıyor. 2048×2048; orman ve küçük kasaba, göl, taş ocağı, telsiz tepesi, çiftlik, kereste atölyesi, hurdalık. Arazi, 37 bina, yollar, sokak eşyaları, orman ve toplanabilir alt bitki örtüsü sunucu açılışında kodla kuruluyor. Toplanabilir her nesne `getHarvestables()` listesinde: düğüm adı (`Config.Harvest.Nodes`) ve her açılışta aynı kalan bir id (ileride dünya kaydı için). |
| Binalar | 15 şablon. Mobilyalı odalar, iki katlılarda merdiven, açılmış kapılar, tabelalar. Her model `Template`, `Loot` (`Food`, `Medical`, `Metal`, `Fabric`…), `Floors` ve `Region` özelliklerini taşıyor; loot sistemi bunları kullanacak. |
| Zombiler (`ZombieService`) | Çalışıyor. Humanoid yok. Akış alanıyla yol bulma, görerek kovalama, ses noktasına gitme, gezinme, eve girip çıkma, merdivenle üst kat, bina içinde uyuyan zombi, saldırı öncesi bekleme, sendeleme, dalgalı spawn, sunucu LOD'u (yakın 10 Hz, uzak 2 Hz), anlık görüntü yayını. API: `spawn`, `remove`, `clear`, `damage` (öldürünce true), `onDied`, `getPosition`, `hearSound`, `getStats`, `getNavGrid`, `reopenArea` (kalkan parçaların altındaki hücreleri arazi değerine döndürüp hâlâ duranları yeniden kapatır). |
| Envanter (`InventoryService` + `Shared/Inventory`) | Çalışıyor. 10 slot alet kemeri + 45 slot sırt çantası. Yeni eşya önce sırt çantasına girer. Her yığın kaynağını taşır; farklı kaynaklar birleşmez. Seçili slottaki eşya sağ elde görünür (stilize model; sallama pozu yok). API: `get`, `changed`, `give`, `room`, `take` (hep ya da hiç), `count`, `getHeld`, `wearHeld`, `onHeldChanged`. Oyuncu boş elle başlar (`StartingItems` boş). |
| İstemci | `ZombieRenderController` + `Modules/ZombieRig`: 17 parçalı rig, prosedürel yürüyüş, interpolasyon, LOD, ceset; `flinch(id)` hazır. `InventoryController`: alttaki alet kemeri, I / gamepad Y ile sırt çantası, mobilde Bag düğmesi; tıkla-seç-bırak taşıma, sağ tık veya Split ile yarım yığın; 1–0 tuşları ve L1/R1 ile slot seçimi. `ToolController`: sol tık / gamepad R2 / mobilde Hit düğmesi; basılı tutunca aletin hızında vurur; nişan imlecin (serbest fare) ya da ekran ortasının altındaki noktaya; sağ omuzda prosedürel sallama; kırık alette uyarı. `PickupFeedController`: sağ kenarda "+N eşya" satırları (aynı eşya aynı satırda toplanır), sığmayanlar kırmızı. `TreeFallController`: devrilen ağacı yerelde oyuncudan uzağa yatırır ve soldurur. `DebugOverlayController`: FPS, tick süresi, zombi sayısı; Spawn 1/80/120, Noise, GodMode, Kill, Give test items ve Clear düğmeleri. |
| Debug | Remote: `DebugCommand`. Yalnızca Studio'da veya `Config.Debug.AllowedUserIds` listesindeki hesaplarla çalışır (`11911303584` test eden hesap). Doğrulanır ve hız sınırlıdır. |
| `DayNightService` | **Boş iskelet.** |
| `ThreatService` | **Boş iskelet.** Config değerleri ve `Types.SoundPoint` hazır. |
| `BuildService` | **Boş iskelet.** `Config.Build` ve `Types.BuildPieceKind` hazır. |
| Kamera (omuz/FPS) | **Yok.** Localization anahtarları (`CameraShoulder`, `CameraFirstPerson`) ve `Config.Camera` hazır. |
| Vuruş (`ToolService` + `Shared/Melee`) | Çalışıyor. İstemci yalnızca nişan yönünü yollar. Sunucu: birim vektör, hız sınırı (4/sn), aletin 7DTD aralığı (60/APM + 0,1 sn, %12 tolerans), hedefi kendi baş konumundan seçer: menzildeki en yakın zombi (silindir + baktığı yöne eğik kafa küresi), arada duvar varsa vurmaz. Hasar 7DTD: yumruk 5, taş balta 6, taş kürek 9, taş kazma 7; kafaya ×2. Alet yalnızca isabette 1 aşınır; 0'da kullanılamaz. Dünyaya isabet `onWorldHit` dinleyicilerine gider (toplama). Oyunculara vuruş yok (PvP lobi seçeneği gelince). |
| Toplama (`HarvestService` + `Shared/Harvest`) | Çalışıyor. 7DTD formülü: verimin üçte ikisi nesnenin toplam hasarıyla orantılı olarak vuruşlarda, üçte biri kıran vuruşta; iyi alet yalnızca hızlandırır. Hasar = aletin blok hasarı × malzeme çarpanı, tam sayıya kesilir, en az 1. Aynı nesneye vuran herkes aynı hasarı paylaşır. Ağaç: 300/30, 600/70, 900/110, 1200/150 (can/odun, boy ölçeğe göre). Çalı 1–3 odun, ot 2 lif, yerdeki taş 1 taş (E ile de alınır), kaya 400 can / 22 taş. Devrilen ağaç çarpışmayı hemen bırakır, altındaki yol hücreleri açılır, 3,5 sn sonra silinir. Hiçbir şey yeniden çıkmaz (7DTD). Sığmayan eşya kaybolur ve kırmızı satırla bildirilir (loot torbası gelince yere düşecek). |
| Crafting, loot, kazı | **Sıradaki iş** (NEXT_STEPS 4–6). `ToolService.onWorldHit` kazı için, `ZombieService.onDied` loot için, `InventoryService.give/take/wearHeld` hepsi için hazır. |
| Perk, kayıt, monetizasyon | Bilerek yazılmadı. |

### Ölçümler

Ölçümler 30–31 Ekim 2026'da PC'de, Studio içinde alındı. Telefonda ölçüm yok.

- **Testler:** 37/37 geçiyor (NavGrid 8, HeightField 3, Buildings 5, ZombieProtocol 3, ZombieLook 3,
  Inventory 6, Melee 5, Harvest 4).
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
   return H.sync() .. "\n" .. H.test(false)   -- beklenen: "37 passed, 0 failed"
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

- `screen_capture` Play modunda beyaz çıkıyor; 31 Ekim'de Edit modunda çalıştı.
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
- **Roblox'un varsayılan can yenilenmesi** saniyede %1 (7DTD'de dakikada 1 can). Hayatta kalma
  istatistikleri adımında değişecek.
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
- **Fare tekeri slot değiştirmiyor.** Tekerlek kamera zoom'unda; kamera adımında karar verilecek.
- **Git yedeği yok.** Uzak depo tanımlı değil. GitHub'a göndermek dışarıya açık bir adım olduğu için
  kullanıcıya sorulmalı.
