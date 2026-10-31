# 7 Days to Die referansı

Bu dosya PLAN.md'deki kapsam kuralının istediği referanstır: ana referans 7 Days to Die (7DTD); sayılar
7DTD'den alınır, uyarlamalar Config'de ve PLAN'ın Kararlar tablosunda yazılır.

- **Kaynak:** 31 Ekim 2026'da iki araştırma ajanı derledi. Sayıların çoğu oyunun kendi config
  dosyalarından (github.com/tassoneroberto/7dtd-assets: 1.0, 1.4, 2.1, 2.6, 3.2), kuralların bir kısmı
  1.1'in derlenmiş kodundan, metinler 7daystodie.wiki.gg'den. 3.3 ve 3.4 için dosya yok.
- **Etiketler:** `[XML]` en güçlü kanıt, `[CODE V1.1]` sonraki sürümlerde aynı varsayıldı, `[WIKI]`
  çoğu zaman eski, `[DERIVED]` hesap, `unconfirmed` kaynak yok. Her bölümün sonunda kaynak bağlantıları
  var.
- **Dil:** Aşağıdaki iki bölüm araştırmanın İngilizce metnidir; değiştirilmeden alındı.

## Bizim uyarlamalarımız

7DTD'den bilerek ayrıldığımız yerler. Her biri ya PLAN'ın özgün kararından ya kullanıcı isteğinden gelir.

| Konu | 7DTD | Bizde | Neden |
| --- | --- | --- | --- |
| Başlangıç | 2 su, chili konservesi, ilk yardım bandajı, meşale | Boş el | PLAN: oyuncu ağaca vurarak başlar |
| Taş kazma | Yok; ilk kazma demir (demirci ocağı ister) | Var: 7 / 26 / 70 vuruş/dk / 2,4 m, 250 dayanıklılık; tarif 4 taş / 3 lif / 3 odun (2 sn), taşla tamir | Kullanıcı isteği |
| Kereste | Yok | 2 odundan 0,4 sn'de yapılır, inşada kullanılacak | Kullanıcı isteği |
| Envanter doluyken craft | Sırt çantası için kaynak yok; iş istasyonunda çıktı slotları doluysa crafting durur (wiki Forge) | Ürün kuyrukta "No room" ile bekler; yer açılınca gelir | İş istasyonu davranışına en yakın; hiçbir şey kaybolmaz |
| Crafting iptali | Kullanılmamış malzeme envantere döner (wiki); envanter doluysa ne olduğu kaynakta yok | İadenin tamamı sığmazsa iptal reddedilir | Yere düşen eşya kabı henüz yok; loot torbası gelince yere düşebilir |
| Tamir edilen alet | Nereye döndüğü kaynakta yok | Boşsa eski slotuna | Kemerdeki alet yerinde kalsın |
| Crafting kuyruğu kaydı | Saklanır | Oyuncu çıkınca kaybolur | Kayıt sistemi yok (kalıcılık adımı) |
| Zombi loot torbası | %2–4 (2.0+: %4) | ~%20 | Kullanıcı kararı |
| Sırt çantası tuşu | Tab veya I | Yalnızca I (gamepad Y, mobilde Bag) | Roblox oyuncu listesi Tab'ı alıyor (Play'de denendi) |
| Fare tekeri | Alet kemerinde gezinir | Kamera zoom'unda | Kamera adımında karar |
| Taşıma yükü | 27 slottan sonra her slot %2,6 yavaşlatır | Henüz yok | Sonra |
| Kalite (1–6) | Var | Yok; her alet 1. kalite | Sonra |
| Metre → stud | — | 1 m = 2,8 stud (Config.Melee.StudsPerMeter) | Roblox karakteri ~5 stud, 7DTD oyuncusu 1,8 m |
| Kafa vuruşu | Gerçek çarpışma kutuları | Sunucuda zombi başına silindir + öne eğik kafa küresi | Sunucuda zombi parçası yok |
| Ağaç boyu | Ağacın türü ve boyu (4–48 m) malzemeyi seçer | Ağaçlarımız 4–6,5 m; boy ölçeğe göre: ≤0,925 küçük, ≤1,05 orta, ≤1,175 büyük, üstü tam boy (`Config.Harvest.TreeSizes`) | Stilize ağaçlar küçük; can ve verim yine 7DTD'nin |
| Devrilen ağaç | Fizik nesnesi, yolundaki zombilere hasar | İstemcide animasyon (2,5 sn + 1 sn solma); zombiye hasar henüz yok | Sunucuda fizik yok; ezme sonra (NEXT_STEPS) |
| Envanter dolu | Eşya oyuncunun ayağına düşer | Ayağa loot torbası düşer (6 stud içindeki torbaya eklenir) | Tek tek eşya yerine torba: parça sayısı |
| Torba içeriği | Mermi, hurda, yiyecek, ilaç, kitap, alet… | Hurda demir / kumaş / küçük taş ve %15 aşınmış taş alet | Diğer eşyalar henüz yok |
| Torba arama | 18 slotluk pencere, eşya tek tek | Basılı tutunca sığan her şey alınır | Pencere sandık arayüzüyle gelecek |
| Gün uzunluğu | Varsayılan 60 dk, gündüz 18 saat; blood moon 22:00–04:00 | 11 dk, %60 gündüz (06:00–18:30); horde bütün gece | PLAN oturum ritmi |
| Gece hızı | Varsayılan ayarda zombiler gece koşar (`ZombieMoveNight=3`) | Horde dışı zombiler gece de yürür | PLAN: The Walking Dead yürüyüşü |
| Blood moon | Büyüklük gamestage'e göre, oyuncu başına aynı anda sınırlı sayı (`BloodMoonEnemyCount`), 22:00–04:00; zombiler sprint | Oyuncu başına toplam 20, 4 dalga; 11 stud/sn ("jog") | PLAN: horde boyutu ve 120 tavanı; yürüyen oyuncu açık arazide kaçabilsin |
| Biyom spawn'ı | Chunk başına biyom ve gamestage'e göre | Oyuncu başına gündüz 6, gece 10, kademeyle ×1,6'ya kadar | PLAN: tehdit kademesi spawn hızını artırır; sunucu bütçesi 80 |
| Isı haritası | Eylemler chunk ısısını artırır, 100'de screamer | Gürültü ölçeri ve ses noktası; screamer yok | PLAN tehdit sistemi |
| Bloğa vuruş ve yükseltme | Sol tık hasar, sağ tık (taş balta) tamir / yükseltme | Taş balta her zaman tamir / yükseltme yapar; diğer aletler hasar verir | Tek "use" düğmesi (mobil) |
| Tamir maliyeti | Bloğun RepairItems'ı (ahşap 3 odun), hasara orantılı | Vuruş başına 100 can, payı yukarı yuvarlanır (çerçeve tam tamir 3, ahşap blok 5 odun) | Kesirli eşya yok |
| Yapısal destek | Malzeme başına yapışkanlık / kütle; ahşap 8 blok yatay | Yalnızca yere bağlantı | Basit tutuldu |
| Blok bina içinde | POI'lerin içine de konur | Kasaba binası tabanına konmaz | Üst kat yol bulma katmanı yapıyı bilmiyor |
| Hayatta kalma zaman tabanı | Yemek / su / can saat başına (varsayılan 60 dk gün = 1 gün) | Oyun günü başına aynı sayılar (11 dk); dayanıklılık ve açlık hasarı gerçek saniye | PLAN Kararlar |
| Yeniden doğuş | Varsayılan ceza XP borcu; istatistikler dolu | İstatistikler dolu; ham kaynakların yarısı 5 dk'lık torbada | PLAN ölüm cezası |
| Koşma hızı | m/s yok (MotorAcceleration çarpanları) | 16 yürüme, 24 koşma stud/sn | Roblox varsayılanı + yarım kat |
| Tükenmiş koşu | Kaynakta yok | 0'da biter, 25'te yeniden başlar | Titreme olmasın |
| Kademe blokajı tabanı | Kaynakta yok (iki stat da son kademedeyse %120) | Dayanıklılık tavanı en az 10 | Oyuncu hiç vuramaz olmasın |
| Göl suyu | El "Drink": +10 su, −5 can, %12 dizanteri | +10 su, −5 can; dizanteri yok | Dizanteri sonra |
| Zombi torbasında içecek | Meyve suyu, çay, kahve, bira; düz su yok | Şişe su ve bulanık su | O içecekler yok |
| Bandaj | Düz bandaj 0 can (yalnızca kanama); ilk yardım bandajı 30 can / 15 sn | Yalnızca ilk yardım bandajı, torbadan | Kanama yok |
| Sopa ve mızrak | Güçlü saldırı, mızrak fırlatma, kalite 1–6, sinsi saldırı ×2 | Yalnızca hafif saldırı, kalite yok; toplama payı aynı (%25, lif tam) | PLAN Kararlar: yakın dövüş silahları |
| Jeneratör ve lamba | Kablo, röle, motor (50–300 W), tezgâhta 15 dövme demir + 15 mekanik + 21 elektrik parçası, ampul 3–10 W | Kablosuz 48 stud, sabit 50 W, 50 hurda + 6 + 8, lamba direği 5 W; benzin depo kaplarında | PLAN Kararlar: jeneratör ve lamba |
| Tarım | Tarla 4 odun + 10 çürük et + 25 nitrat + 100 kil; tohum geri dönüşü ve bonus perkle; yabani ekin; pişirme | Tarla 4 odun + 100 kil; tohum hep geri, bonus %50; yabani ekin ve pişirme yok | PLAN Kararlar: tarım |
| Yay ve ok | Ok tarifinde tüy; germe, yayılma, 20 m'den sonra hasar düşüşü; oklar toplanır | Tüy yerine lif; germe / yayılma / düşüş yok; ok kaybolur | PLAN Kararlar: yay ve ok |
| Ahşap kapı | 10 odun, 2 sn, 1000 can; kilitlenir | 5 kereste (aynı odun), kilit yok | PLAN Kararlar: kapı |
| Kazı | Her arazi bloğu (1 m) kazılır, tünel açılır; asfalt 1500 can; ana kaya 3 katman; Dirt her yere konur | 4 stud'luk sütun tepesi, tünel yok, en çok 2 voksel adım, asfalt kazılmaz, Dirt yalnızca kazılan yeri doldurur | PLAN Kararlar: kazı |
| Bina kapları | POI kapları (dolap, buzdolabı, soğutucu, ilaç dolabı, çöp…), çoğunlukla çöp ve bozuk yemek; LootRespawnDays sunucu ayarı | 6 kap türü, sade eşya tabloları, yemek daha bol, 7 günde yeniden | PLAN Kararlar: bina kapları |
| Ot ve yerdeki taş | Biyoma göre her yerde blok | 26 stud'luk orman hücrelerinde şansla; kasabada ot var, taş ve kaya yok | Parça sayısı; PLAN: kasabada kaya yok |

---

# Bölüm A: envanter, başlangıç, crafting, zombi loot'u, kaplar

## 7 Days to Die: inventory, starting kit, crafting, zombie loot, world containers

Reference for the Roblox design. Compiled 2026-10-31.

### 0. Versions and how the numbers were checked

#### Release timeline (from the wiki's Version history page)

| Version | Name | Released |
|---|---|---|
| 1.0 | (stable release; experimental 2024-06-24) | 2024-07-25 |
| 1.1 / 1.2 / 1.3 | | 2024-10-01 / 2024-12-10 / 2025-02-12 |
| 1.4 | not on the wiki list; present in the game files repo | (early 2025) |
| 2.0 | Storm's Brewing | 2025-06-30 |
| 2.1 to 2.4 | | 2025-07-14 to 2025-09-09 |
| 2.5 | Survival Revival | 2025-12-08 |
| 2.6 | | 2026-04-01 |
| 3.0 | Dead Hot Summer | 2026-06-29 |
| 3.1 / 3.2 | Henpocalypse / – | 2026-07-27 / 2026-08-26 |
| 3.3 | (backpack overhaul) | 2026-10-05 |
| 3.4 | current | 2026-10-26 |

Source: https://7daystodie.wiki.gg/wiki/Version_history

#### Primary data: the game's own XML files

Most numbers below come straight from the vanilla `Config/*.xml` files in the GitHub mirror
**https://github.com/tassoneroberto/7dtd-assets** (folders `v1.0`, `v1.4`, `v2.1`, `v2.6`, `v3.2`, `alpha21.2`, `alpha16.4`–`alpha20.7`).

- The repo's `v1.0` folder was committed on 2024-06-24, so it is the **1.0 experimental** build.
  I diffed it against `v1.4`. Almost every value in this report is the same in both: recipes, stack
  sizes, carry capacity, encumbrance, loot-bag drop chances, bag size and lifetime, starting items and
  the Basics challenges. The **"1.x" column therefore means 1.0 to 1.4**.
- **The one exception is zombie loot-bag contents.** They were reworked between 1.0 experimental and
  1.4, and the 1.4 contents are already the ones used in 2.x and 3.x (see 4.2). Which 1.x patch made
  the change is unconfirmed, because only the v1.0 and v1.4 files were available.
- "2.x" means the `v2.6` files unless a row says `v2.1`.
- The newest XML available is **v3.2**. Anything about **3.3/3.4** comes from patch notes and is not
  checked against XML.
- File links follow this pattern: `https://github.com/tassoneroberto/7dtd-assets/blob/main/<version>/Config/<file>.xml`
  (for example `.../v1.4/Config/recipes.xml`).

Labels used below:
- **XML**: read directly from the config file.
- **derived**: calculated from XML values with a formula that is stated next to it.
- **wiki**: from 7daystodie.wiki.gg. The Fandom wiki returned HTTP 402, so it was not used.
- **unconfirmed**: no source found.

---

### 1. Inventory

#### 1.1 Backpack slots

Sources: XML `entityclasses.xml` (player `CarryCapacity`, `BagSize`), `progression.xml` (Pack Mule),
`item_modifiers.xml` (pocket mods), `XUi/windows.xml` (backpack grid). Wiki Inventory page:
https://7daystodie.wiki.gg/wiki/Inventory · Pack Mule page: https://7daystodie.wiki.gg/wiki/Pack_Mule

| | 1.x | 2.x | 3.0–3.2 | 3.3+ (patch notes only) |
|---|---|---|---|---|
| Grid (UI slots) | 9 × 5 = **45** (`BagSize` 45) | 45 | 45 | **8 × 6 = 48** |
| Unencumbered slots at start (`CarryCapacity`) | **27** (first 3 rows) | 27 | 27 × sandbox "Encumbrance Slots" multiplier (`.carryCapacityBase`) | **32** (4 free rows, 2 encumbered rows) |
| Maximum total slots | 45 | 45 | 45 | **96** with a Large backpack (8 × 12) |

Ways to raise carry capacity (XML, 1.x–3.2):

| Source | Bonus |
|---|---|
| **Pack Mule** perk (Strength; perk level N needs Strength N) | Cumulative **+3 / +6 / +10 / +14 / +18** at levels 1–5. 27 + 18 = 45, so at level 5 the whole grid is free. **From 2.x** it also gives −10% to −50% crafting time on `packMuleCrafting` recipes, plus a 5–25% chance to ignore a hit. |
| **Armor pocket mods** (installed on armor pieces) | Storage Pocket **+1**, Double **+2**, Triple **+3**, Quad **+4** per mod |
| Lumberjack, Scavenger and Nomad outfits (body armor) | +1 / +2 / +3 / +4 / +5 / **+10** at quality 1–6 |
| Night Stalker Vol. 4 (perk book) | +27 at night |
| Fireman's Almanac complete (perk book) | +45 in two specific biomes (biome ids 8 and 9) |
| Chicken Nuggets food (3.x) | removes encumbrance for 360 s (shows "+27") |

**V3.3 backpacks** (patch notes: https://patched.gg/games/7-days-to-die/v330-stable).
There are Small, Medium and Large backpacks with 6 quality levels and a new Backpack equipment
slot. Added slots start encumbered; Pack Mule and pocket mods make them free.

The per-quality numbers below are **from experimental data (gaming-st.com) and unconfirmed for stable**:
https://gaming-st.com/pc-games/7-days-to-die-v3-3-bigger-backpack-slots/

| Quality | Small | Medium | Large |
|---|---|---|---|
| 1 | +2 | +18 | +34 |
| 6 | +16 | +32 | +48 (= 96 total) |

Experimental recipes, made at a Workbench and unlocked by a new "Pack Rat" magazine:
- Small: 1 Sewing Kit, 5 Cloth
- Medium: 7 Sewing Kits, 25 Leather, 5 Forged Iron
- Large: 13 Sewing Kits, 50 Leather, 20 Scrap Polymers, 5 Forged Steel

#### 1.2 Toolbelt

| Item | Value | Source |
|---|---|---|
| Slots | **10** (1 row × 10). A second row exists only in creative mode. | XML `XUi/windows.xml` `windowToolbelt` (v1.0, v3.2); wiki https://7daystodie.wiki.gg/wiki/Toolbelt |
| Keys | **1–9, 0** select a slot (rebindable). The mouse wheel cycles slots. | wiki Toolbelt, wiki Controls https://7daystodie.wiki.gg/wiki/Controls |
| Drop held item | **G** | wiki Controls |
| Inventory/toolbelt overflow | The wiki says new items go to the toolbelt when the backpack is full. | wiki Inventory |

#### 1.3 Encumbrance

Source: XML `buffs.xml` buff `buffEncumberedInv`, the same in 1.x, 2.x and 3.2.

- **Trigger:** the number of used backpack slots is greater than `CarryCapacity`. The XML comment
  says: "This is not tied to the POSITION of the slot you use but the total number of slots used."
  Toolbelt slots do not count.
- **Penalty:** **Mobility −2.6% per slot over capacity** (`_encumberedslots × 0.026`, applied as
  `perc_subtract`). Mobility is the movement-speed multiplier. Jump strength and stamina are not
  affected (the jump line is commented out).
- With 27 capacity and 45 slots, at most 18 slots can be over, which gives **−46.8% movement**.
- The HUD buff is named "Encumbered" and shows the number of over-capacity slots. The UI text says:
  "Moving becomes harder when you are carrying too many items…"
- In 3.x the sandbox option "Encumbrance Slots" ranges from Disabled (no encumbrance) to Full.

#### 1.4 Stack sizes

Source: XML `items.xml` / `blocks.xml` `Stacknumber`, resolved through `Extends`.
Values are the same in 1.x, 2.x and 3.2 except where a column differs.

| Item (display name) | Internal name | 1.x | 2.x | 3.2 |
|---|---|---|---|---|
| Wood | resourceWood | 6000 | 6000 | 6000 |
| Small Stone | resourceRockSmall | 6000 | 6000 | 6000 |
| Plant Fibers | resourceYuccaFibers | 6000 | 6000 | 6000 |
| Clay Soil | resourceClayLump | 6000 | 6000 | 6000 |
| Crushed Sand | resourceCrushedSand | 6000 | 6000 | 6000 |
| Iron (scrap iron; shown as "Iron" in 1.x) | resourceScrapIron | 6000 | 6000 | 6000 |
| Forged Iron | resourceForgedIron | 500 | 500 | 500 |
| Cloth Fragment | resourceCloth | 250 | 250 | 250 |
| Cotton | resourceCropCottonPlant | 500 | 500 | 500 |
| Feather | resourceFeather | 250 | 250 | 250 |
| Bone | resourceBone | 1200 | 1200 | 1200 |
| Rotting Flesh | foodRottingFlesh | 125 | 125 | 125 |
| Animal Fat | resourceAnimalFat | 500 | 500 | 500 |
| Leather | resourceLeather | 250 | 250 | 250 |
| Coal / Nitrate Powder / Broken Glass / Snowball | resource… | 6000 | 6000 | 6000 |
| Cobblestone Rocks | resourceCobblestones | 1000 | 1000 | 1000 |
| Nails | resourceNail | 1000 | 1000 | 1000 |
| Duct Tape / Glue / Paper / Spring | | 500 | 500 | 500 |
| Short Iron Pipe | resourceMetalPipe | 500 | 500 | 500 |
| Mechanical Parts / Electrical Parts / Scrap Polymers | | 1000 | 1000 | 1000 |
| Repair Kit | resourceRepairKit | 25 | 25 | 25 |
| Oil / Lockpick | | 50 | 50 | 50 |
| Canned food (Chili, Beef, Dog Food, all `foodCan*`) | foodCanChili … | 10 | 10 | 10 |
| Raw Meat | foodRawMeat | 125 | 125 | 125 |
| Charred / Grilled Meat, Bacon and Eggs (cooked meals) | | 10 | 10 | 10 |
| Egg, Blueberries, Corn, Potato (raw crops) | | 125 | 125 | 125 |
| **Water** ("bottled"/boiled water jar) | drinkJarBoiledWater | 10 | 10 | 10 |
| Murky Water | drinkJarRiverWater | **125** | **10** (v2.6; still 125 in v2.1) | 10 |
| Coffee / Pure Mineral Water | | 10 | 10 | 10 |
| Bandage | medicalBandage | 10 | 10 | 10 |
| First Aid Bandage | medicalFirstAidBandage | 5 | 5 | 5 |
| Aloe Cream | medicalAloeCream | 15 | 15 | 15 |
| Splint | medicalSplint | 5 | 5 | 5 |
| Herbal Antibiotics / Painkillers | | 10 | 10 | 10 |
| Stone Arrow / Iron Arrow | ammoArrowStone / ammoArrowIron | 150 | 150 | 150 |
| Torch | meleeToolTorch | 50 | 50 | 50 |
| Bedroll | bedrollBlockVariantHelper | 10 | 10 | 10 |
| Campfire / Forge / Workbench / Land Claim Block | | 1 | 1 | 1 |
| Cooking Pot | toolCookingPot | 3 | 3 | **1** |
| Wood Door | oldWoodDoor | 500 | 500 | 500 |
| Building Block (wood frame) | frameShapes | 500 (wiki) | | |
| Skill magazines (e.g. "Tools Digest") | *SkillMagazine | 20 | 20 | 20 |
| Notes / perk books | | 50 | | |

Notes:
- **Building blocks, wood spikes and the wood storage crate** have no `Stacknumber` in XML.
  The wiki gives the wood frame a stack of 500 (https://7daystodie.wiki.gg/wiki/Wood_Frame).
  The engine default for blocks is therefore probably 500, but that is **unconfirmed** for spikes and crates.
- **Tools, weapons and armor do not stack (stack size 1).** None of them define `Stacknumber`, and
  `XML.txt` says items with `Attributes`/`Parts` are "Stacknumber = 1 and does not need to be defined".
  The wiki Stone Axe page gives stack size 1: https://7daystodie.wiki.gg/wiki/Stone_Axe

#### 1.5 Item quality (tiers 1–6)

Source: XML `qualityinfo.xml` (identical 1.0 → 3.2), tool `effect_group`s in `items.xml`,
`progression.xml`, `loot.xml` (`qualBaseTemplate`).

| Tier | Colour (hex) | Name in the XML comment | Probable in-game label (unconfirmed mapping) |
|---|---|---|---|
| 0 | 808080 grey | Broken | Broken |
| 1 | 9C8867 brown | Junk | Faulty |
| 2 | CF7F29 orange | Common | Poor |
| 3 | A2A41B yellow | Uncommon | Good |
| 4 | 42C234 green | Rare | Fine |
| 5 | 315DCE blue | Epic | Great |
| 6 | A42ACC purple | Legendary | Flawless |

The localization keys are `lblQualityDamaged` = "Faulty", `Poor` = "Poor", `Average` = "Good",
`Great` = "Fine", `Flawless` = "Great" and `Legendary` = "Flawless". The tier numbers are not
stored next to these keys, so the label column is inferred from the key order.

What quality changes on early tools (XML, same in 1.x–3.2):

| Effect | Q1 → Q6 |
|---|---|
| Max durability (`DegradationMax`) | Linear between two values. Stone Axe 250 → 500; Iron Pickaxe 500 → 1000; Wooden Club 100 → 200. |
| Entity damage | +0% at Q1, then **+10% … +50%** across Q2–Q6 |
| Block damage | Axes and picks +15% … +75%; other tools +10% … +50% (Q2–Q6) |
| Mod slots | T0 (stone/wood/bone) tools: 1, 1, 1, 2, 2, 3. T1 (iron) tools: 2, 2, 2, 3, 3, 4. |
| Bow | Entity damage +7% … +35% |

How quality is set:
- **Crafted items:** the highest tier you can craft depends on the crafting-skill level. For example,
  Stone Axe Q1–Q6 needs Harvesting Tools level 1 / 2 / 4 / 6 / 8 / 10. You pick the quality before
  crafting.
- **Looted items:** quality depends on loot stage. The base template comment says "QL4 starts at 50,
  QL5 at 80, QL6 at 110".

#### 1.6 Durability and degradation

Sources: XML `items.xml`; wiki Durability https://7daystodie.wiki.gg/wiki/Durability; wiki Repairing
Items https://7daystodie.wiki.gg/wiki/Repairing_Items

- Each swing or shot costs **1 durability** (`DegradationPerUse` 1). Armor loses durability when you take damage.
- At 0 the item stops working ("ceases to function"). It **is not destroyed**: the stone axe, iron
  tools and others have `DegradationBreaksAfter = false`.
- Repairing restores the item to max durability "with no loss in Quality" (wiki). The repair goes
  into the crafting queue.
- 3.x sandbox options (v3.2 `Localization.csv`):
  - **Item Degradation:** "How fast weapons and tools lose durability."
  - **Repair Degradation:** "Determines how much an item degrades when repaired." The value and
    default are unconfirmed.
  - **Death Degradation:** None, Durability (current durability, repairable), Max Durability (lowers
    the repair cap) or Both. **Death Degradation Amount** sets the percentage lost.

Max durability by quality (XML; derived linear steps):

| Tool | Q1 | Q2 | Q3 | Q4 | Q5 | Q6 |
|---|---|---|---|---|---|---|
| Stone Axe, Stone Shovel, Bone Knife | 250 | 300 | 350 | 400 | 450 | 500 |
| Stone Spear, Wooden Club, Primitive Bow | 100 | 120 | 140 | 160 | 180 | 200 |
| Iron Pickaxe, Iron Shovel, Iron Fireaxe | 500 | 600 | 700 | 800 | 900 | 1000 |
| Torch | no durability | | | | | |

#### 1.7 Repair

Source: XML `RepairTools` on each tool, plus `RepairAmount` and `RepairTime` on the repair item.

| Tool(s) | Repair item | RepairAmount per unit | RepairTime per unit | Units for a full repair (**derived**) |
|---|---|---|---|---|
| **Stone Axe**, Stone Shovel, Stone Spear, Stone Sledgehammer | **Small Stone** | 300 | 0.5 s | Axe/Shovel: Q1–Q2 at most 1; Q3–Q6 up to 2. Spear: 1. |
| Wooden Club, Primitive Bow | Wood | 100 | – | Q1: 1; Q2–Q6: up to 2 |
| Bone Knife | Bone | 270 | – | Q1: 1; Q2–Q6: up to 2 |
| Leather Knuckles | Cloth Fragment | 50 | – | – |
| Pipe Baton, Pipe Pistol, Pipe Shotgun, Pipe Rifle, Pipe Machine Gun | Short Iron Pipe | 800 | 1 s | – |
| **Everything else** (iron/steel tools, guns, armor; 52 item definitions in 1.4) | **Repair Kit** | 32000 | 3 s | **1 kit**, always a full repair |

- The "derived" column assumes units = ceil(missing durability ÷ RepairAmount). For example, a Q6
  stone axe at 0 durability needs ceil(500/300) = 2 small stones. The wiki Stone Axe page says
  "requires 1 Small Stone", which is only true for Q1–Q2.
- Since **Alpha 18**, repair kits are used for "all non-primitive tools, weapons, and armor instead
  of the raw resource" (wiki Repair Kit: https://7daystodie.wiki.gg/wiki/Repair_Kit).
- **Repair Kit recipe:** 1 Forged Iron + 1 Duct Tape, 11 s, made in the backpack or at a Workbench.
- The perks The Fixer, Tool Smithing and Gun Smithing speed up repairs (wiki).

#### 1.8 Inventory UI conventions

Sources: wiki Looting Menu https://7daystodie.wiki.gg/wiki/Looting_Menu; wiki Controls; wiki
Inventory; wiki Crafting https://7daystodie.wiki.gg/wiki/Crafting; XML `XUi/windows.xml` and
`Localization.txt`.

| Action | How |
|---|---|
| Take a full stack | Hold left click and drag |
| Drop or swap a held stack | Left click |
| **Split (take half)** | **Hold right click and drag** |
| Place one item at a time | Right click while holding a stack |
| Arbitrary split amount | Not in vanilla (only half or one at a time) |
| Quick move | **Shift + left click**. Moves backpack → open container, or → toolbelt if no container is open; also moves toolbelt/container → backpack. |
| Sort | "Sort Container" button. It skips locked slots. |
| Stash buttons on containers | "Move all items to loot container"; "Fill stacks" (moves items that can top up existing stacks); "Smart stash" (moves items that already have a stack there); "Fill and Smart" (first click fills, second click also makes new stacks) |
| Loot all | **R** while a container is open |
| **Lock slots** | 1.x: a combobox locks the **first N slots (0–45)** against sort/stash. **2.2+**: a "Lock Mode Toggle" button locks individual slots (v2.6 XML; headline of the 2.2 patch notes). |
| Drop an item | Drag it out of the window into the world, or press **G** for the held toolbelt item |
| Inspect | Left click an item |
| Crafting count | Choose a number; **Shift + click** sets it to the maximum you can craft |
| On death (default) | Everything drops into a lootable backpack (server option "Drop on Death") |

---

### 2. Player start

#### 2.1 What a new character spawns with

Source: XML `entityclasses.xml`, `playerMale`, `ItemsOnEnterGame.GameModeSurvival`. The line is
identical in v1.0, v1.4, v2.6 and v3.2:

```
drinkJarBoiledWater=2, foodCanChili, medicalFirstAidBandage, meleeToolTorch, noteDuke01
```

| Item | Count |
|---|---|
| Water (jar of boiled water) | 2 |
| Can of Chili | 1 |
| First Aid Bandage | 1 |
| Torch | 1 |
| Note from The Duke of Navezgane (lore note; "Thanks for the gear, but you still owe us…") | 1 |

- There are no tools, weapons or armor in the spawn list.
- The `GameModeSurvivalSP` and `GameModeSurvivalMP` keys hold the same list without the note and
  with 1 water. They look like legacy keys; `GameModeSurvival` is the line with the note.
- **A21.2 also gave a Land Claim Block**, which 1.0 removed.
- New characters get the buff "Death XP Penalty Protection" (`buffNewbieCoat`): no XP loss on death,
  fading out at level 6 (XML `buffs.xml`).
- Finishing the Basics challenge group gives **4 skill points**.

#### 2.2 New-player chain in 1.x–3.2: "Challenges" (replaces A21's "Basic Survival 1/8")

Source: XML `challenges.xml`, `gameevents.xml`, `quests.xml`. The Basics group is identical in v1.0,
v1.4, v2.6 and v3.2. Each challenge's default reward is **100 XP** (`challenge_reward_100xp`).

**Basics group** (challenges are linked, so they unlock one after another):

| # | Challenge | Requirement |
|---|---|---|
| 0 | Redeem Challenge | Tutorial: open the Challenges window and redeem |
| 1 | Gather Resources | Gather **10 Plant Fibers, 10 Wood, 5 Small Stone** |
| 2 | Craft Stone Axe | Craft 1 Stone Axe |
| 3 | Harvest with Stone Axe | Harvest **10 Wood** (trees) and **5 Small Stone** (boulders) while holding the Stone Axe |
| 4 | Craft Clothes | Craft a **Primitive Outfit** |
| 5 | Wear Clothes | Wear the Primitive Outfit |
| 6 | Craft Wood Club | Craft a Wooden Club |
| 7 | Craft Bow | Craft a Primitive Bow |
| 8 | Craft Arrows | Craft 1 Stone Arrow |
| 9 | Group Complete | Redeem the group |

**Basics reward:** +4 skill points, then the quest **"White River Citizen 1"**: go to the nearest
trader (pine forest), talk to them, turn in. That quest gives 500 XP and a Stone Shovel, and it then
starts tracking the "craft land claim" challenge.

The next groups are unlocked by Basics. Each group gives 1000 XP plus a pick from 5 rewards
(3 skill-magazine bundles, 1 common schematic or mod, 1 perk book).

- **Homesteading:** place a Land Claim → place a Bedroll → craft a Building Block (frame) → place it
  → upgrade it with the Stone Axe (8 Wood) → place a Wood Door → place a Wood Storage Crate → place a
  Torch → place a Wood Spikes Trap → upgrade a wood block to cobblestone (10 Cobblestone Rocks).
- **Advanced Survival:** spend 1 skill point → kill 2 animals → harvest 10 Raw Meat (1.x: Bone Knife
  required; 2.x+: any tool) → place a Campfire → craft 2 Charred Meat → eat 2 Charred Meat → drink
  from a water source → place a Dew Collector → kill 5 zombies → place a Farm Plot.
- **Workstations:** read 1 skill magazine → scrap 5 items → place a Forge → craft 100 Forged Iron →
  place a Workbench → craft 20 Pipe Bombs → place a Cement Mixer → craft 100 Concrete Mix → place a
  Chemistry Station → craft 100 Gas Cans.

**For comparison, A21.2 "Basic Survival 1–8" quests** (XML `alpha21.2/Config/quests.xml`), 50 XP each:

| # | Requirement |
|---|---|
| 1 | 10 Plant Fibers → craft a Bedroll → place it |
| 2 | 2 Fibers, 2 Wood, 2 Small Stone → craft a Stone Axe |
| 3 | 5 Fibers → craft Plant Fiber Pants |
| 4 | Wear the pants |
| 5 | 5 Wood → craft a Wooden Club |
| 6 | 10 Wood, 3 Fibers, 1 Feather, 1 Small Stone → craft a Primitive Bow and a Stone Arrow |
| 7 | 10 Wood → craft, place and upgrade a frame |
| 8 | 5 Small Stone → craft and place a Campfire. Reward: 4 skill points + White River Citizen 1. |

---

### 3. Crafting

#### 3.1 How backpack crafting works

Sources: XML `XUi/windows.xml` (`windowCraftingQueue`) and `XUi_InGame/windows.xml` (v3.2); wiki
Crafting Window https://7daystodie.wiki.gg/wiki/Crafting_Window; wiki Crafting; wiki Forge
https://7daystodie.wiki.gg/wiki/Forge

| Question | Answer |
|---|---|
| Queue size | **4 slots** (1 × 4 grid). The same queue is used in the backpack, campfire, forge, workbench, chemistry station and cement mixer (1.0 and 3.2). Each slot shows a countdown. Scrapping and repairs use the same queue. |
| Count per slot | You set the quantity (and quality) before crafting; Shift-click sets the maximum. The cap per slot is **unconfirmed**. |
| Crafting time | Recipes with an explicit `craft_time` use it. Otherwise time = Σ (ingredient count × that ingredient's `CraftingIngredientTime`), with a default of 1 s per unit. Examples: Wood, Small Stone, Plant Fibers, Cloth, Leather, Bone = 0.2 s; Cobblestone 0.25 s; Forged Iron 10 s; Animal Fat 15 s; Raw Meat 3 s; Murky Water 10 s. This matches the wiki for Stone Axe (1.2 s, "00:01"), Workbench (379 s, "06:19") and Repair Kit (11 s). The display is rounded. |
| Ingredients taken when? | At **queue time** (inferred). The wiki says cancelling refunds "the unused ingredients back into the character's Inventory". |
| Cancel | Left click a queued item to cancel it and get its ingredients back. |
| Continues with UI closed? | **Unconfirmed for backpack crafting.** Workstations: the forge burns fuel while it is on, even when idle, and crafting **halts when the output slots are full** (wiki Forge). |
| Speed modifiers | **2.x+**: Pack Mule −10/20/30/40/50% on recipes tagged `packMuleCrafting` (nearly all backpack recipes). **3.x** sandbox options: "Crafting Timer"; "Backpack Crafting" (No / Yes / Limited / Workbench Only); "Workstation Crafting"; "Crafting Cost" (materials); "Crafting Yield" (items per craft); "Crafting Max Quality"; "Crafting Progression" (turns magazine and schematic unlocks on or off). |

#### 3.2 Recipe unlock system (1.x–3.x)

Sources: XML `progression.xml` (`crafting_skills`), `items.xml` (magazines); wiki Crafting.

- Recipes unlock mainly through **crafting skills** (for example Harvesting Tools, Workstations,
  Armor, Medical, Bows, Blades, Spears, Clubs).
- A skill rises **+1 level per skill magazine read**. For example "Tools Digest" raises Harvesting
  Tools and "Forge Ahead" raises Workstations. Magazines stack to 20 and give 50 XP each.
- Each skill also caps the quality you can craft.
- **Perk books** (7-volume series) and **schematics** unlock the rest. Example: "Wasteland Treasures
  Vol 6" unlocks Cloth from Plant Fibers.
- Items with no `UnlockedBy` are craftable from the start: Stone Axe/Shovel/Spear/Sledgehammer,
  Wooden Club, Primitive Bow, Stone Arrow, Bone Knife, Bedroll, Campfire, Torch, Bandage, frames,
  Wood Spikes, Wood Storage Crate, Land Claim, Repair Kit, Duct Tape.
- The Primitive Outfit needs **Armor level 1** and is required by the second Basics challenge, so
  crafting skills appear to start at level 1 (**inferred**).

Crafting-skill levels for early items. Where six numbers are listed, they are the levels for quality 1–6.

| Skill (max level) | Item | Level needed |
|---|---|---|
| Harvesting Tools (100) | Stone Axe, Stone Shovel | 1, 2, 4, 6, 8, 10 |
| | Iron Pickaxe, Iron Shovel, Iron Fireaxe | 11, 13, 16, 19, 22, 25 |
| Blades (75) | Bone Knife | 1 … 10 |
| | **Hunting Knife** | 11, 15, 20, 25, 30, 35 |
| Spears (75) | Stone Spear | 1 … 10 (Iron Spear from 11) |
| Clubs (75) | Wooden Club | 1 … 10 (Baseball Bat from 11) |
| Bows (75) | Primitive Bow | 1 … 10 (Wooden Bow from 11) |
| Armor (100) | Primitive Outfit | 1 … 10 |
| Medical (75) | First Aid Bandage | 5 |
| Repair Tools (50) | Claw Hammer | 4 |
| Workstations (75), 1.x | Dew Collector 2, **Forge 5**, **Workbench 10**, Lockpick 15, Bellows 20, Anvil 25, Cement Mixer 30, Chemistry Station 50, Crucible 75 | |
| Workstations, v2.6 (wiki: Forge lowered to 4 in V2.5) | **Forge 4**, Bellows 8, **Workbench 10**, Lockpick 12, Dew Collector 16, Anvil 20, Gatherer 26, Apiary 30, Tarp 32, Cement Mixer 34, … Chemistry Station 50, Crucible 75 | |
| Workstations, v3.2 | Same as v2.6, plus Chicken Coop 6, Brooding Lamp 14, Chicken Run 18, Nesting Box 24 | |

#### 3.3 Early-game recipes

Source: XML `recipes.xml`. Identical in 1.0 (exp), 1.4, 2.6 and 3.2 unless a row says otherwise;
2.x only added the `packMuleCrafting` tag.

- Craft time is **derived** with the formula from 3.1 unless marked "explicit" or "wiki".
- "Backpack" means the inventory crafting window; recipes with no `craft_area` can also be made at
  a Workbench.
- Recipes listing "0 Legendary Parts" are placeholders and have been left out.

| Item | Ingredients | Time (s) | Station | Unlock |
|---|---|---|---|---|
| **Stone Axe** | 2 Small Stone, 2 Plant Fibers, 2 Wood | 1.2 | Backpack | Start (Q-cap by Harvesting Tools) |
| **Stone Shovel** | 5 Small Stone, 3 Plant Fibers, 3 Wood | 2.2 | Backpack | Start |
| **Stone Spear** | 5 Small Stone, 3 Plant Fibers, 3 Wood | 2.2 | Backpack | Start |
| Stone Sledgehammer | 10 Small Stone, 10 Plant Fibers, 10 Wood | 6.0 | Backpack | Start |
| **Wooden Club** | 5 Wood | 1.0 | Backpack | Start |
| **Primitive Bow** | 8 Wood, 3 Plant Fibers | 2.2 | Backpack | Start |
| **Stone Arrow** (×1) | 1 Small Stone, 1 Wood, 1 Feather | 1.4 (explicit in 3.2) | Backpack | Start |
| **Bedroll** | 10 Plant Fibers | 2.0 | Backpack | Start |
| **Campfire** | 5 Small Stone | 1.0 | Backpack | Start |
| **Torch** | 1 Animal Fat, 5 Cloth Fragment, 1 Wood | 16.2 | Backpack | Start |
| **Bandage** | 10 Cloth Fragment | 2.0 | Backpack | Start |
| First Aid Bandage | 1 Bandage, 1 Aloe Cream | 2.0 | Backpack | Medical 5 |
| Aloe Cream | 4 Aloe Vera Leaf | 20 | Backpack | Start |
| **Cloth Fragment** (from fibers) | **20 Plant Fibers** | 4.0 | Backpack | Wasteland Treasures Vol 6 (perk book) |
| Cloth Fragment (from cotton) | 1 Cotton | 2.0 | Backpack | (same book) |
| Primitive Outfit / Hood / Gloves / Shoes (the 1.x "plant fiber clothing") | 5 Plant Fibers + 5 Wood **each** | 2.0 | Backpack | Armor 1 |
| Plant Fiber Shirt / Pants / Hat / Shoes | still in the item list but **no recipe** in 1.x–3.2. (A21: 5 Plant Fibers each, 1 s) | – | – | – |
| **Building Block** (wood frame) | 2 Wood | 0.4 | Backpack | Start. Upgrade to Wood Block with a hammer/axe: +8 Wood. |
| Wood Block (direct) | 10 Wood | 2.0 | Backpack | Start |
| Cobblestone Block | 10 Cobblestone Rocks | 2.5 | Backpack | Start |
| Cobblestone Rocks | 1 Clay Soil, 1 Small Stone | 0.4 | Backpack | Start |
| **Wood Spikes Trap** | 20 Wood | 4.0 | Backpack | Start |
| Wood Door | 10 Wood | 2.0 | Backpack | Start |
| Land Claim Block | 5 Small Stone | 5 (explicit) | Backpack | Start |
| **Wood Storage Crate** (player storage, 8 × 6 = 48 slots) | 10 Wood | 2.0 | Backpack | Start |
| **Forge** | 50 Cobblestone Rocks, 1 Wood Log, 10 Leather, 3 Duct Tape, 3 Short Iron Pipe | **81 (wiki "01:21")**; the formula gives 21.5 | Backpack | Workstations 5 (1.x) / 4 (2.5+) |
| **Workbench** | 25 Forged Iron, 20 Mechanical Parts, 5 Duct Tape, 100 Nails, 100 Wood | 379 (wiki 06:19) | Backpack | Workstations 10 |
| **Cooking Pot** | Forge material: 25 iron units + 5 clay units (= 25 Iron + 1 Clay Soil) | 15 | Forge | Start. 3.x also has a smelter-free recipe: 25 Iron + 1 Clay Soil, 5.2 s. |
| Cooking Grill | same as Cooking Pot | 15 | Forge | Start |
| Forged Iron | 10 iron units + 5 clay units (= 10 Iron + 1 Clay Soil) | 7.5 | Forge | Start |
| Nails | 1 iron unit + 1 clay unit (3.x: 1 + 5) | 1.0 | Forge | Start |
| Duct Tape | 1 Glue, 7 Cloth Fragment | 2.4 | Backpack | Start |
| Glue | 7 Bone, 1 Water | 16.4 | Campfire + Cooking Pot | Start |
| Water (boil) | 1 Murky Water | 10 | Campfire + Cooking Pot | Start |
| Charred Meat | 5 Raw Meat | 15 | Campfire | Start |
| **Bone Knife** | 5 Bone | 1.0 | Backpack | Start |
| **Hunting Knife** | 8 Forged Iron, 4 Wood, 2 Leather, 2 Duct Tape | 83.2 | Backpack / Workbench | Blades 11 |
| **Iron Pickaxe** | 20 Forged Iron, 10 Wood, 2 Leather, 2 Duct Tape | 204.4 | Backpack / Workbench | Harvesting Tools 11 |
| **Iron Shovel** | 16 Forged Iron, 10 Wood, 2 Leather, 2 Duct Tape | 164.4 | Backpack / Workbench | Harvesting Tools 11 |
| **Iron Fireaxe** | 20 Forged Iron, 10 Wood, 2 Leather, 2 Duct Tape | 204.4 | Backpack / Workbench | Harvesting Tools 11 |
| Claw Hammer | 12 Forged Iron, 6 Wood, 2 Leather, 2 Duct Tape | 123.6 | Backpack | Repair Tools 4 |
| Repair Kit | 1 Forged Iron, 1 Duct Tape | 11 | Backpack | Start |
| Dew Collector | 1.x: 100 Scrap Polymers, 4 Short Iron Pipe, 4 Duct Tape. **2.x+**: 200 Scrap Polymers, 30 Short Iron Pipe, 8 Duct Tape. | 28 / 78 | 1.x: no `craft_area` (Backpack or Workbench); 2.x+: Workbench only | Workstations 2 (1.x) / 16 (2.6) |

Notes on the Forge:
- Forge materials: 1 Iron (weight 1) = 1 iron unit; 1 Clay Soil (weight 5) = 5 clay units.
- The forge has 3 fuel slots and 2 smelting slots, and holds up to 30,000 units per material (wiki Forge).
- The Forge's craft time cannot be fully explained from XML. Its Wood Log is a block ingredient with
  no `CraftingIngredientTime`, and the wiki's 81 s implies about 60 s for that log.

#### 3.4 Stone pickaxe or plank/timber item?

Checked every item and block name in `items.xml` and `blocks.xml` for **A16.4, A17.4, A18.4, A19.6,
A20.7, A21.2, 1.0, 1.4, 2.6 and 3.2**:

- **No stone pickaxe in any of them.** The first pickaxe is the Iron Pickaxe (`pickaxeIron` in A16,
  `meleeToolPickaxeIron` in A17/A18, `meleeToolPickT1IronPickaxe` from A19).
- **No plank, lumber or timber crafting item.** The only match is `woodPlanksStack`, a decorative
  POI block with `CreativeMode = Dev` and no recipe. Wood is the only lumber resource.
  ("Lumberjack" matches are an armor set and a magazine.)
- 3.3/3.4 XML was not available. The 3.3 patch notes mention no such items.

---

### 4. Zombie loot

Sources: XML `entityclasses.xml` (`LootDropProb`, `LootDropEntityClass`, `TimeStayAfterDeath`),
`loot.xml` (`zPack*`), `progression.xml`, `buffs.xml`. Wiki Loot Bag (last updated for A20):
https://7daystodie.wiki.gg/wiki/Loot_Bag. Patch note for V2.0 b292:
https://consolepcgaming.com/7-days-to-die-v2-0-b292-exp-patch-brings-faster-zombies-new-commands-and-bug-fixes

#### 4.1 Drop chance

| Zombie type | 1.x (1.0–1.4) | 2.x–3.2 |
|---|---|---|
| Regular zombies (Joe, Arlene, Marlene, Steve, Boe…) | **2%** → regular bag | **4%** → regular bag |
| Feral and Radiated variants | **3%** → regular bag (one exception: the Radiated Hazmat male is 2%) | **4%** |
| "Strong" zombies. 1.4: Biker, Lumberjack, Fat Female, Fat Hawaiian, Bowler, Fat Cop, Mutated (all variants); the radiated Skateboarder, Soldier, Wight and Screamer. | 2–3% → **strong** bag | 4% → strong bag |
| Charged / Infernal tiers (new in 2.0) | – | **10%** → strong bag |
| Themed zombies: Nurse, Lab, Utility Worker, Soldier, and Biker + Skateboarder ("Thug" bag) | – | 4% → themed bag (zPackNurse, zPackLab, zPackUtility, zPackSoldier, zPackThug) |
| Plague Spitter / Rancher (v2.6+; not in v2.1) | – | 5% (Charged/Infernal 10%) → regular or strong bag, plus a plague bag |
| Demolisher | **30%** → boss bag | 30% |

- V2.0 experimental first used 5%; V2.0 b292 (2025-06-24) lowered it to **4%** ("general zombie loot
  bag drops… reduced from 5% to 4%").
- In 1.x the wiki's "2% chance of dropping every time a zombie dies" matches the XML.

What changes the chance:

| Modifier | Effect | Source |
|---|---|---|
| Lucky Looter Complete (all 7 volumes of the perk-book series) | `LootDropProb` +20% relative (2% → 2.4%) | XML `progression.xml`, 1.x–3.2 |
| Biome storm buffs (Burnt / Desert / Snow / Wasteland storm), 2.x+ | +500% relative (×6) while the storm buff is active | XML `buffs.xml`. It is **inferred** that this applies to the killer: the buff is a player weather buff, and Lucky Looter, also a player effect, changes the same stat. |
| Twitch-integration buffs | −100% | XML |
| 3.x sandbox "Loot Bag Drop" | "Multiplier applied to chance for enemies to drop loot bags on death" | v3.2 `Localization.csv`. Values and default **unconfirmed**. |
| Game stage / difficulty / Loot Abundance | No scaling of the drop **chance** found in XML. 1.x–2.x bags have `ignore_loot_abundance="true"`; the attribute is gone in v3.2. | XML |

#### 4.2 Bag lifetime, size and contents

| | 1.x (also v2.1) | v2.6–3.2 |
|---|---|---|
| Lifetime (`TimeStayAfterDeath`, seconds) | **1200 s = 20 min** (wiki agrees) | **3600 s = 60 min** |
| Container size | **6 × 3 = 18 slots** | 6 × 3 |
| Open time | 1 s | 1 s |
| Loot quality template | Regular: `qualBaseTemplate`; Strong and Boss: `qualPlus1Template` | same |

The v3.2 XML comment says "…will go poof after this many seconds", which confirms the unit is seconds.

**How the probabilities read:** `low` = 0.20, `med` = 0.5, `medHigh` = 0.63, `high` = 0.75,
`veryLow` = 0.05. When a sub-group line has `force_prob`, the value is the chance the sub-group rolls
at all. Inside a group, the values act as weights.

**Regular bag, 1.0 experimental only** (`v1.0/Config/loot.xml`, `groupZpackReg`):
- 1 medium ammo pile (always).
- 2 picks from {uncommon food (0.63), uncommon drinks (0.20), uncommon scrap (0.63), uncommon medical (0.5)}.
- 50% chance of 1 pick from {armor parts, perk books, skill magazines (0.75), tiered tools, armor,
  rare crafting items, helmet light mod}.
- 20% chance of 1 pick from {rare tools, weapons, 200–400 casino coins, 150–500 Old Cash, rare medical,
  treasure map, night-vision mod}.

**Regular bag, 1.4 through 3.2** (identical in v1.4, v2.1, v2.6 and v3.2):
- 1 **large** ammo pile (always).
- 1 pick from {uncommon scrap, 10–50 Cobblestone Rocks, 1–2 Glue, uncommon medical, uncommon drinks,
  uncommon food (all `high`), 1–2 Duct Tape (`med`), 1–2 Mechanical Parts or 1 Acid (`veryLow`)}.
- 1 pick of {perk book (0.63) or skill magazine (0.75)} (always).
- 50% chance of 1 pick from {armor parts, rare crafting, armor-chest parts, armor, tiered tools}.
- 20% chance of 1 pick from {rare tools, weapons, mods, 200–400 casino coins, 200–400 Old Cash, rare
  medical, treasure maps, night-vision or helmet-light mod}.
- **2.x+ only:** a Bookworm-perk chance of 1 extra book.

**Strong and Boss bags:**

| Roll | Strong 1.0 exp | Strong 1.4–3.2 | Boss 1.0 exp | Boss 1.4–3.2 |
|---|---|---|---|---|
| Large ammo | 1 | 1 | 2 | 2 |
| Basic group (01) | 2 picks | 2 picks | 2 picks | 2 picks |
| Group 02 | 1 pick | 2 picks | 1 pick | 2 picks |
| Group 03 | 20% chance | 1 pick (always) | 50% chance | 1 pick (always) |
| Rare group (04) | – | 20% chance | – | 50% chance |

In v3.2 the strong rare group adds 400–600 coins and cash, mods and tiered vehicle parts. The item
lists inside the strong and boss sub-groups were not compared item by item.

#### 4.3 Corpses

| Question | Answer (1.x–3.2) | Source |
|---|---|---|
| Can human-zombie corpses be harvested? | **No.** No zombie or zombie-template entity has `<drop event="Harvest">`. | XML `entityclasses.xml` |
| Which zombie corpses can be harvested? | Zombie animals only, with a knife or axe. Zombie Bear: 50 Rotting Flesh, 15 Leather, 5 Animal Fat, 25 Bone, 2 Testosterone Extract. Zombie Dog: 10 flesh, 4 leather, 1 fat, 15 bone. Zombie Vulture: 4 flesh, 30 feathers, 6 bone. | XML |
| Decorative corpses in POIs (gore blocks) | Harvesting gives 1–2 Rotting Flesh and 4–8 Nitrate Powder; destroying gives 5–9 Bone. | XML `blocks.xml` `goreBlockHumanCorpse` |
| Removing a corpse | Corpses have 1000 HP (`DeadBodyHitPoints`). Tools tagged `corpseRemoval` (Stone Axe, Bone Knife, Fireaxe) deal +300 damage to them. | XML `entityclasses.xml`, `buffs.xml` |
| **Despawn time** | `TimeStayAfterDeath` = **30 s** for every zombie class (1.x–3.2) | XML. A Nexus mod for v3.1 also describes the default as "around 30 seconds". |

---

### 5. World containers (brief)

Sources: XML `loot.xml` (`lootcontainer` size, `count`, `open_time`, `destroy_on_close`) and
`blocks.xml` (`LootList`); `progression.xml` (Lucky Looter). Loot respawn default: `serverconfig.xml`
`LootRespawnDays` = 7 (https://github.com/GameServerManagers/Game-Server-Configs, sdtd/serverconfig.xml).
Wiki Trash Pile: https://7daystodie.wiki.gg/wiki/Trash_Pile

| Container | Loot list | Size | Items rolled | Search time (`open_time`) | Notes |
|---|---|---|---|---|---|
| **Trash pile** | junk | 6 × 2 = 12 | 1–2 | not set (engine default) | `destroy_on_close="empty"`. The wiki says it "will destroy itself" once emptied and does not appear to respawn. |
| **Cardboard box** | cardboardBox | 6 × 3 = 18 | 1–2 | not set | |
| **Cupboard** (kitchen) | cupboard | 6 × 3 = 18 | 1 | not set | |
| Garbage can | garbage | 6 × 2 | 1–2 | not set | |
| Dumpster | dumpster | 8 × 4 | 1 | not set | |
| Medicine cabinet | medicineCabinet | 6 × 2 | 1 | not set | `destroy_on_close="empty"` |
| Bird nest | birdNest | 6 × 2 | 1 | not set | `destroy_on_close="empty"` |
| Mailbox | mailbox | 6 × 2 | 1 | not set | `destroy_on_close="empty"` |
| Purse / Weathered backpack | purse / cntBackpack | 6 × 2 | 1–2 / 1 | **1.5 s** | `destroy_on_close="empty"` |
| File cabinet | fileCabinet | 6 × 2 | 1–2 | not set | `destroy_on_close="empty"` |
| Car (sedan) | cars | 7 × 4 | 1 | **4 s** | |
| Wall safe / Gun safe | smallSafes / gunSafe | 8 × 5 / 8 × 9 | – | 1 s | Locked; `destroy_on_close="empty"`; quality +1 template |
| Player Wood Storage Crate | – | 8 × 6 = 48 | 0 | – | |

- **Search time:** most containers have no `open_time`, so the engine default applies. That default
  is **unconfirmed**. Explicit values in v1.0 `loot.xml`: 0 s (7 containers), 0.2 s (2), 0.25 s (66),
  1 s (19), 1.5 s (6), 4 s (10, mostly vehicles).
- **`destroy_on_close="empty"`:** what happens to the block is confirmed only for the trash pile, which
  the wiki says destroys itself. For mailboxes, safes, cabinets and the rest, whether the block is
  removed or switched to an empty variant is **unconfirmed**.
- Lucky Looter perk: looting is **10 / 20 / 40 / 60 / 80% faster** at levels 1–5 (XML; wiki
  https://7daystodie.wiki.gg/wiki/Lucky_Looter). One helmet adds up to −20% by quality.
- 3.x sandbox option "Loot Timer".
- **Loot respawn:** default **7 in-game days** (`LootRespawnDays`). The v3.2 UI text says it is "the
  number of in-game days before loot containers in unvisited areas reset". 3.x sandbox "Loot Respawn
  Days".

---

### 6. Gaps and open points

- **Backpack crafting with the window closed:** unconfirmed; no source found.
- **Ingredients taken at queue time:** inferred from the refund wording only.
- **Maximum count per queue slot:** unconfirmed.
- **Default loot search time** for containers without `open_time`: unconfirmed.
- **Forge craft time:** the wiki says 81 s, but the XML formula gives 21.5 s. The block-ingredient time is unexplained.
- **Quality label to tier mapping** (Faulty … Flawless): inferred from key order.
- **Storm loot-bag bonus applying to the killer:** inferred.
- **3.x "Loot Bag Drop" sandbox option:** values and default not found.
- **V3.3/3.4:** not checked against XML. The per-quality backpack slots and recipes are experimental-branch data.
- **Default stack for blocks** (wood spikes, storage crate): probably 500, unconfirmed. Only the wood frame is confirmed (500, wiki).
- **Zombie bag contents:** reworked between 1.0 experimental and 1.4. The exact 1.x patch is unconfirmed.
- **Bag lifetime change (20 → 60 min):** happened after v2.1 and by v2.6. The exact patch is unconfirmed.
- **3.x "Repair Degradation" option:** the value range and default are unconfirmed.
- **Effect of `destroy_on_close="empty"`** on containers other than the trash pile: unconfirmed.

---

# Bölüm B: toplama, arazi, aletler, oyuncu istatistikleri, zombiler

## 7 Days to Die: harvesting, terrain, tools, player stats and walkers (numbers reference)

Compiled 2026-10-31 for the Roblox co-op survival project.

### How to read this file

Most numbers here come from the game's own config files, not from wikis. A vanilla copy of `Data/Config` for every release sits in a public GitHub mirror, and I parsed it directly. Where a file did not explain a behaviour, I read a decompiled copy of the game code (`Assembly-CSharp`, V1.1 build 14).

| Tag | Meaning |
|---|---|
| **[XML]** | Read directly from the vanilla config file of the named version. Strongest evidence. |
| **[CODE V1.1]** | Read from the decompiled game code, version V1.1 b14 (Constants.cs: `cVersionMajor=1, cVersionMinor=1, cVersionBuild=14`). Assumed unchanged in later versions unless noted; that assumption is **not verified**. |
| **[WIKI]** | Community wiki page (7daystodie.wiki.gg). Often out of date; the conflicts are listed below. |
| **[FORUM]** | Developer or moderator forum post. |
| **[DERIVED]** | My own calculation from the XML values plus the code formula. |
| **unconfirmed** | No primary source found. |

#### Versions used

| Folder in mirror | What it is | Mirror commit date |
|---|---|---|
| `v1.0` | 1.0 **experimental** build (b333 era). Stable 1.0 shipped 2024-07-25. | 2024-06-24 |
| `v1.1` to `v1.4` | 1.x patch line | 2024 to 2025-04 |
| `v2.1`, `v2.6` | 2.x ("Storm's Brewing" line) | to 2026-06 |
| `v3.0.1`, `v3.1`, `v3.2` | 3.x. **v3.2 is the newest in the mirror.** A V3.3 may exist; not checked. | 2026-08-29 |

The tables quote **v3.2** values unless they say otherwise. Values that differ in v1.0 are called out. Most harvesting numbers are identical from v1.0 to v3.2.

**v2.6 check (the newest 2.x build in the mirror).** I diffed the v2.6 files against v3.2 for every tool in 5.1, the zombie hand items, the zombies in 7.1 and the player stat lines in section 6.
- **Base numbers match for every quoted value.** That covers damage, APM, stamina, range, durability, zombie HP, speed, damage and timing, and the stamina, health and drain rates.
- v2.6 still had the untiered **±4% random roll** on entity and block damage for the T1 tools (pickaxe, iron shovel, fireaxe, bat, sledge). v3.x replaced it with the `<stats>` rolls.
- v3.2 adds `ToolCategory harvestingTools` entries to most tools: 1.0 for shovels, spear, knife, pickaxe and fireaxe; 0.5 for clubs, bat and sledge. These have no effect on natural blocks, because no natural block drop has a `tool_category` (see 5.2).
- v3.2 gates the player-level stat bonus behind a sandbox option. It also simplified several difficulty-scaled bleed and poison damage-over-time values, which this file does not cover.

#### Sources

**Primary sources (XML):** everything is under `https://github.com/tassoneroberto/7dtd-assets/tree/main/<version>/Config/`. The files I used were:
- [blocks.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/blocks.xml) and [blocks.xml v1.0](https://github.com/tassoneroberto/7dtd-assets/blob/main/v1.0/Config/blocks.xml)
- [materials.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/materials.xml)
- [items.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/items.xml) and [items.xml v1.0](https://github.com/tassoneroberto/7dtd-assets/blob/main/v1.0/Config/items.xml)
- [entityclasses.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/entityclasses.xml) and [entityclasses.xml v1.0](https://github.com/tassoneroberto/7dtd-assets/blob/main/v1.0/Config/entityclasses.xml)
- [buffs.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/buffs.xml)
- [progression.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/progression.xml)
- [recipes.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/recipes.xml)
- [biomes.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/biomes.xml)
- [gameevents.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/gameevents.xml)
- [Stealth.txt v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/Stealth.txt)

**Decompiled code, V1.1 b14:** [HuitDR/AssemblyCSharp](https://github.com/HuitDR/AssemblyCSharp). The files I read were `GameUtils.cs` (HarvestOnAttack, collectHarvestedItem), `ItemActionAttack.cs` (Hit, difficultyModifier), `ItemActionDynamicMelee.cs`, `ItemActionDynamic.cs`, `BlockModelTree.cs`, `EntityFallingTree.cs`, `EntityHuman.cs`, `EntityAlive.cs`, `EntityStats.cs`, `EntityPlayerLocal.cs`, `Block.cs` (CopyDroppedFrom), `BlocksFromXml.cs` and `Constants.cs`.

**Default server settings:** the serverconfig template in [GameServerManagers/Game-Server-Configs](https://github.com/GameServerManagers/Game-Server-Configs/blob/main/sdtd/serverconfig.xml). It matches the comments in the official file, but it is a third-party copy.

**Wiki pages (7daystodie.wiki.gg):** [Pine Tree](https://7daystodie.wiki.gg/wiki/Pine_Tree), [Burnt tree](https://7daystodie.wiki.gg/wiki/Burnt_tree), [Wood](https://7daystodie.wiki.gg/wiki/Wood), [Harvesting](https://7daystodie.wiki.gg/wiki/Harvesting), [Tool](https://7daystodie.wiki.gg/wiki/Tool), [Stamina](https://7daystodie.wiki.gg/wiki/Stamina), [Land Claim Block](https://7daystodie.wiki.gg/wiki/Land_Claim_Block), [Traders](https://7daystodie.wiki.gg/wiki/Traders), [Small Stone](https://7daystodie.wiki.gg/wiki/Small_Stone), [Plant Fibers](https://7daystodie.wiki.gg/wiki/Plant_Fibers).

**Forum posts:**
- [Tin, TFP forum, 2018: Harvest vs Destroy drops](https://community.thefunpimps.com/threads/how-to-make-trees-have-a-chance-of-seed-drop.6568)
- [faatal (developer), 2022: sleeper volume triggers](https://devtrackers.gg/7-days-to-die/p/fbbbaf8e-so-i-decided-to-track-sleeper-volumes-in-poi-s-and-how-many-are-ambushes)

> Note on fandom: 7daystodie.fandom.com returned HTTP 402 to automated fetches and could not be read.

---

### 0. The harvesting mechanic (read this first)

Everything in sections 1 to 4 follows from this one algorithm. It comes from `GameUtils.HarvestOnAttack` and `collectHarvestedItem` **[CODE V1.1]**.

Each block in `blocks.xml` lists its `<drop>` entries by event:

| Event | When it pays | Notes |
|---|---|---|
| `Harvest` | Paid out **while you hit**, plus a lump on the killing blow. | Main yield for trees, rocks and terrain. |
| `Destroy` | Paid once, when the block is destroyed by a player hit. | Seeds from trees; nothing from most terrain. |
| `Fall` | When the block falls or collapses as a falling-block entity. | `stick_chance` is the chance it re-places as a block. |

#### Harvest payout per hit

1. On every non-grazing hit that damages the block, for each `Harvest` drop:
   - `N = int( randomInt(min..max) × HarvestCount )`
   - The range is re-rolled on every hit.
   - `HarvestCount` is a multiplier resolved from the drop's `tag`; see 5.4. A player with a normal tool has 1.0.
2. **Two thirds** (`N − N/3`, integer division) are paid in proportion to damage:
   - `paid = round(cumulativeDamage / (MaxHP / pool)) − round(previousDamage / (MaxHP / pool))`
   - Cumulative damage is capped at MaxHP, so overkill damage gives nothing extra.
   - Rounding telescopes, so the total over all hits is exactly `pool`. With a fixed `N`, the yield is the same whatever the damage per hit.
3. **One third** (`N/3`) is paid as a **lump on the killing blow**. This is the felling bonus. It is part of the listed total, not extra.
4. A drop's `prob` attribute is rolled at each payout.
5. Items go **straight into the inventory**. If the inventory is full they drop at the player's feet. The player also gets XP: `item material Experience × count`.
6. After the harvest, `Destroy` drops are added:
   - `count × HarvestCount` for that drop's tags.
   - With no tag, the multiplier is the default 1, so seeds are not boosted by perks.
7. Grazing hits (edge-of-swing hits) **never harvest**. They cost only 1% of the swing's stamina (`GrazeStaminaPercentage` default 0.01) **[CODE V1.1]**.

**Worked example (DERIVED):** a full-grown pine has 1200 HP and `Harvest wood count=150`.
- Pool = 100 wood, lump = 50 wood. That is 1 wood per 12 HP of damage.
- A Stone Axe does 22 damage to wood. That works out to about 1.8 wood per hit over 55 hits, then +50 on the fell. Total 150.

#### What "Harvest" and "Destroy" mean, in TFP's words

> "Use the 'Harvest' to gather as you whittle something down, 'Destroy' to get it all at the end."

Tin, TFP forum, 6 July 2018 (Alpha 17 era). The V1.1 code above refines this with the 2/3 and 1/3 split.

#### Tool choice and total yield

**Conflicting sources:**
- The code and XML say the tool changes **speed** (block damage), not the total, unless the tool carries a `HarvestCount` modifier.
- Clubs, bats, spears, sledges and batons carry −0.75, so they yield **25%**. See 5.4.
- wiki.gg *Harvesting* (edited May 2024) agrees: "The speed at which a block is destroyed does not reduce the total resources obtained."
- wiki.gg *Wood* (edited May 2026) says "The better the tool the better the amount yielded". That text dates from older alphas and is contradicted by both the XML and the code.

#### How drops inherit **[CODE V1.1]**

When a block uses `Extends`, the parent's drops are **appended, per event**, unless the child already has a drop of the **same item name**. `<dropextendsoff/>` disables inheritance. This comes from `Block.CopyDroppedFrom` and `BlocksFromXml`.

**Sources (section 0):**
- Code, V1.1 b14:
  - [GameUtils.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/GameUtils.cs) (HarvestOnAttack, collectHarvestedItem)
  - [Block.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/Block.cs) (CopyDroppedFrom)
  - [BlocksFromXml.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/BlocksFromXml.cs)
  - [ItemActionDynamicMelee.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/ItemActionDynamicMelee.cs)
- XML: [blocks.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/blocks.xml) (header comment)
- Wiki and forum:
  - [wiki.gg Harvesting](https://7daystodie.wiki.gg/wiki/Harvesting)
  - [wiki.gg Wood](https://7daystodie.wiki.gg/wiki/Wood)
  - [TFP forum, Tin 2018](https://community.thefunpimps.com/threads/how-to-make-trees-have-a-chance-of-seed-drop.6568)

---

### 1. Trees

#### 1.1 Tree catalogue **[XML v3.2]**

**HP comes from the material**, because tree blocks set no `MaxDamage` of their own. The four tree-wood materials share the same properties:
- `MtreeWoodSmall` 300 HP, `MtreeWoodMedium` 600 HP, `MtreeWoodLarge` 900 HP, `MtreeWoodFull` 1200 HP.
- All have `damage_category=wood`, `Hardness=1` and `Experience=2`.

| Block (in-game group) | Size note (XML comment) | Material | HP | Harvest: wood (total) | Other Harvest drops | Destroy (on fell) |
|---|---|---|---|---|---|---|
| `treeOakSml01` | Oak 10 m | Small | 300 | 30 | none | 1 Oak seed (`treePlantedOak1m`) |
| `treeOakMed01` | Oak 23 m | Medium | 600 | 70 | none | 2 Oak seeds |
| `treeOakMed02` | Oak 23 m | Large | 900 | 110 | none | 2 Oak seeds |
| `treeOakLrg01` | Oak 45 m | Full | 1200 | 150 | none | 2 Oak seeds |
| `treeJuniper4m` | small Christmas-like evergreen | Small | 300 | 30 | none | 1 Pine seed (`treePlantedMountainPine1m`) |
| `treeMountainPine12m` | Pine 12 m | Small | 300 | 30 | none | 1 Pine seed |
| `treeMountainPine19m` | Pine 19 m | Medium | 600 | 70 | none | 1 Pine seed |
| `treeMountainPine27m` / `31m` | Pine 27 / 31 m | Large | 900 | 110 | none | 2 Pine seeds |
| `treeMountainPine41m` / `48m` | Pine 41 / 48 m | Full | 1200 | 150 | none | 2 Pine seeds |
| `treeFirLrg01` | large fir | Full | 1200 | 150 | none | 2 Pine seeds |
| `treeWinterEverGreen` | snowy evergreen 6 m | Small | 300 | 30 | none | 1 Winter-pine seed |
| `treeWinterEverGreenLarge` (added after 1.0) | snowy 13 m | Small | 300 | 30 | none | 1 Winter-pine seed |
| `treeWinterPine13m` | snowy pine | Medium | 600 | 70 | none | 2 Winter-pine seeds |
| `treeWinterPine19m` | snowy pine | Large | 900 | 110 | none | 2 Winter-pine seeds |
| `treeWinterPine28m` | snowy pine | Full | 1200 | 150 | none | 2 Winter-pine seeds |
| `treeDeadTree01` / `02` | dead tree 6 m | Small | 300 | 30 | none | **nothing** |
| `treePlainsTree2` | dead tree 11 m | Small | 300 | 30 | none | nothing |
| `treeMountainPineDry21m` | dead pine 21 m | Large | 900 | 110 | none | 1 Pine seed |
| `treePineBurntMed` / `treePineBurntFullMed` | burnt pine | Large | 900 | 110 | Coal 11–22 (`oreWoodHarvest`) | 1 Pine seed |
| `treePineBurntLrg` | burnt pine, large | Large | 900 | **150** | Coal 15–30 | 1 Pine seed |
| `treeBurntMaple01` | burnt maple 3 m | Small | 300 | 30 | Coal 3–8 | nothing |
| `treeBurntMaple02` | burnt maple 5 m | Large | 900 | 110 | Coal 11–22 | nothing |
| `treeBurntMaple03` / `04` (`04` added after 1.0) | burnt maple, large | Full | 1200 | 150 | Coal 15–30 | nothing |
| `treeCactus01`…`06` | saguaro-type cactus | `Mcactus` | 100 | 10 Plant Fibers | none | 2–3 Yucca Fruit + 5 Plant Fibers. Touching it deals 3 damage (`Damage=3`). |

Notes on the table:
- **Coal.** Burnt trees list a second, identical coal drop tagged `coalHarvest`. Nothing in v3.2 (player, perks, buffs, items or mods) grants HarvestCount for `coalHarvest`, so that second entry pays **0**. Only the `oreWoodHarvest` coal is real.
- **Honey.** Every tree inherits from `treeMaster` a `Harvest foodHoney prob=.05 count=1` drop tagged `WasteTreasuresHoneyHarvest`. The player base sets that tag to 0. It only pays after reading the book *Wasteland Treasures Vol. 1 (Honey)* (`perkWasteTreasuresHoney`). Then each tree has about a 5% chance to give 1 honey.
- **Tree types that are not in the game:**
  - There are **no birch trees and no living maple trees** in any shipped version.
  - In v1.0 to v1.4, `treeBirch10m/12m/15m` and `treeMaple13m/15m` exist only **inside XML comments**, so they are disabled. They were deleted by v2.1.
  - "Maple" exists only as burnt maples. "Oak" is the deciduous tree.
- Grass, shrubs and the leafy "plains tree" bush are in section 2.

#### 1.2 Wood per hit (DERIVED from 0 and 1.1)

| Tree size | HP | Total | Paid during chopping | Lump on fell | HP of damage per 1 wood |
|---|---|---|---|---|---|
| Small | 300 | 30 | 20 | 10 | 15 |
| Medium | 600 | 70 | 47 | 23 | 12.8 |
| Large | 900 | 110 | 74 | 36 | 12.2 |
| Full | 1200 | 150 | 100 | 50 | 12 |

Example: an Iron Fireaxe (47 damage to wood at Q1) pays about 3–4 wood per hit on a full tree and fells it in 26 hits.

#### 1.3 What felling gives

- **Extra wood:** only the one-third lump described above. There is no separate wood bonus in the `Destroy` event in 1.0 to 3.2 **[XML]**.
  - Older wiki text ("Felling a Tree will yield a bonus amount of Wood", wiki.gg *Wood*) describes the same lump in pre-1.0 terms.
  - The wiki.gg *Burnt tree* page (June 2024) claims "drops Wood Log" and 150/550/750 wood. **That contradicts the XML** (30/110/150 wood, no logs). The XML is newer and authoritative.
- **Seeds:** 1–2 tree seeds of the matching species. Dead trees and burnt maples give none.
  - wiki.gg *Pine Tree* (planted pines) lists 1 seed at stage 1 and 2 seeds at stages 2–4. That matches the XML.
- **Coal:** from burnt trees only (above).
- **Wood logs:** the XML has no log drop from trees in any version checked.

#### 1.4 Stumps

A stump **does not remain** after felling. The tree block becomes air **[CODE V1.1 `EntityFallingTree.DestroyTree`]**. Stumps (`treeStump`, `treeStumpPOI`) are separate world-generation decorations, for example `prob=.002` in pine-forest sub-biomes.

| Version | Stump HP | Harvest | Destroy |
|---|---|---|---|
| v1.0 – v2.1 | 300 (MtreeWoodSmall) | Wood 20–30 | 20% chance of 1 Honey |
| **v2.6 – v3.2** | 300 | Wood **10–15** | Wood **10–15**, plus the `block_tree_stump_bees` event |

The `block_tree_stump_bees` event (v2.x and later) **[XML gameevents]** runs on destruction:
- 20% chance that it fires at all.
- If it fires: +1 Honey and the `buffHarvestHoney` buff.
- Within that, a 50% chance to spawn an **aggressive bee swarm** 2–3 m away and give +1 Beeswax.

The stump-yield change landed somewhere between v2.1 and v2.6. The exact patch was not checked.

#### 1.5 Falling trees **[CODE V1.1]**

`BlockModelTree` and `EntityFallingTree` work like this:

- **A real physics object.** When HP reaches 0 and the tree has `FallOver=true` (the default for trees), the game spawns a `fallingTree` entity with a Unity Rigidbody.
- **Direction.** An impulse of `(80 + 8·h) × 5` is applied at 65% of the trunk height, **away from the player who felled it**. Here `h` is 0.9 × the collider height, minimum 3 m × 0.9.
- **Mass.** `(15 + 7·h) × 5`.
- **Damage.**
  - Entities hit take Crushing damage of `int(mass × 0.36)`, once per entity, only if that is more than 10, and only after a **1.5 s** delay.
  - **Players are explicitly excluded** (`treeCanDamageEntity` returns false for `EntityPlayer`), so falling trees hurt zombies and animals but never players.
  - Example (DERIVED): a 20 m collider gives h = 18, mass 705, so 253 damage to a zombie.
- **Lifetime.** At least 3 s. When it comes to rest (velocity² < 0.1) it fades out over 1 s and is removed. It is also removed if it falls below y = 1.
- **Drops** are not affected by the fall. Wood was already paid during chopping and seeds on the kill hit.
- **Explosions.** Trees are not explosion-affected (`ExplosionAffected=false`). An explosion that does reach one makes it fall.
- **Saplings and seeds** (`FallOver=false`) simply disappear.

#### 1.6 Regrowth, planting and saplings

- **Natural trees do not regrow and do not grow.** wiki.gg *Pine Tree*: "Naturally generated trees do not grow to more mature stages."
  - Nothing in the XML respawns felled world trees.
  - The only reset is the server option `MaxChunkAge`: chunks not visited for N in-game days reset to their original state. The default is −1, which means never **[serverconfig template]**.
- **Planted trees** **[XML]**: a seed (`treePlantedMountainPine1m`, `treePlantedOak1m`, `treePlantedWinterPine1m`) grows through 4 stages to full size.

| Planted stage | HP | Wood | Seeds on fell | Needs `FertileLevel` |
|---|---|---|---|---|
| Seed / sapling | 10 (`MaxDamage=10`, `Mplants`) | 0 | itself (1) | 1 |
| Stage 1 | 300 | 30 | 1 | 1 |
| Stage 2 | 600 | 70 | 2 (Oak) / 1 (Pine 19 m) | 1 |
| Stage 3 | 900 | 110 | 2 | 3 |
| Stage 4 (final) | 1200 | 150 | 2 | 5 |

Notes on planting:
- `GrowthRate=63` per stage. The wiki says 63 minutes per stage but lists 3 h 09 total, which is only 3 transitions. Units (game or real minutes) are **unconfirmed**.
- Fertility: `Mdirt` and `MforestGround` have `fertile_level=5`. `Msand` and `Msnow` have 1.
- Placement rule **[CODE V1.1]**: no other tree within ±3 blocks horizontally and ±6 vertically.
- Saplings **[XML vs WIKI conflict]**:
  - The wiki says "Saplings cannot be harvested or directly attacked" and that destroying them yields nothing.
  - The XML gives the seed block a `Destroy` drop of itself (1 seed) and 10 HP.
  - Behaviour in game is unconfirmed.

**Sources (section 1):**
- XML:
  - [blocks.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/blocks.xml), [blocks.xml v1.0](https://github.com/tassoneroberto/7dtd-assets/blob/main/v1.0/Config/blocks.xml), [blocks.xml v2.1](https://github.com/tassoneroberto/7dtd-assets/blob/main/v2.1/Config/blocks.xml) (stumps, birch and maple removal)
  - [materials.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/materials.xml)
  - [gameevents.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/gameevents.xml) (stump bees)
  - [entityclasses.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/entityclasses.xml) (HarvestCount tags)
  - [progression.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/progression.xml) (honey book)
- Code, V1.1 b14: [BlockModelTree.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/BlockModelTree.cs), [EntityFallingTree.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/EntityFallingTree.cs), [GameUtils.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/GameUtils.cs)
- Server: [serverconfig template](https://github.com/GameServerManagers/Game-Server-Configs/blob/main/sdtd/serverconfig.xml) (MaxChunkAge)
- Wiki: [wiki.gg Pine Tree](https://7daystodie.wiki.gg/wiki/Pine_Tree), [wiki.gg Burnt tree](https://7daystodie.wiki.gg/wiki/Burnt_tree), [wiki.gg Wood](https://7daystodie.wiki.gg/wiki/Wood)

---

### 2. Bushes and grass **[XML v3.2]**

| Block | Description | Material | HP | Harvest drop | Destroy |
|---|---|---|---|---|---|
| `treeTallGrassDiagonal`, `treeShortGrass`, `treeForestGrassDiagonal` | green grass (forest) | `Mtallgrass` | 1 | **2 Plant Fibers** | 0 |
| `treeBrownGrassDiagonal`, `treeSnowyGrassDiagonal`, `treeGreenBrownGrassDiagonal` | brown, snowy and other grass | `Mtallgrass` | 1 | 2 Plant Fibers | 0 |
| `treeDesertShrub` | desert shrub | `Mtallgrass` | 1 | 2 Plant Fibers | 0 |
| `treeDeadPineLeaf` | "Dead bush easily harvested for wood in many biomes" | `Mleaves` | 1 | **Wood 1–3** | 0 |
| `treeSnowyDeadBush` | snow-biome dead bush | `Mleaves` | 1 | Wood 1–3 | 0 |
| `treeAzalea` | small green bush | `Mleaves` | 1 | Wood 1–3 | 0 |
| `plantHedge`, `plantShrub`, `plantShrubDead` and snow variants | hedges and shrubs | `MleavesStable` | 1 | Wood 1–3 | 0 |
| `treePlainsTree` | leafy plains bush-tree | `Mleaves` | 1 | Wood 1–5 | 0 |
| `plantHangingIvy01/02` | ivy | `MleavesStable` | 10 | none | 2–4 Plant Fibers |
| `terrForestGround` (the ground block itself) | forest floor | `MforestGround` | 250 | Clay 22 **and 2 Plant Fibers** | 0 |

- All of these die in one hit (HP 1), so the whole drop is paid at once. With `N − N/3` plus the lump, a roll of 1–3 gives 1–3 wood.
- Grass has `HarvestOverdamage=false`. The exact effect of that flag is **unconfirmed**; it only matters for multi-hit blocks.
- **Tool bonuses on fibers and bush wood:**
  - The tags are `allHarvest` and `perkJunkMiner`; bushes also carry `lumberjackHarvest`.
  - No knife or sickle bonus exists in vanilla. The Bone Knife has HarvestCount bonuses only for `butcherHarvest` (corpses).
  - **v1.0 – v1.4:** clubs, bats, spears and sledges had `HarvestCount −0.75` on `allHarvest`. Grass then gives `int(2 × 0.25) = 0` fibers, so **a club got no fibers from grass**. This was removed by v2.6.
  - **Junk Miner** perk (v2.x+): +20/40/60/80/100% on `perkJunkMiner` drops while holding a Miner 69'r tool (axe, pick or shovel).
  - **Lumberjack armor set bonus**: +100% `lumberjackHarvest` (wood) while holding an axe or chainsaw.
  - `allHarvest` is also boosted by Scavenger gloves (per the header comment in blocks.xml; values not extracted).
- Fist on grass yields the full 2 fibers. wiki.gg *Plant Fibers* only says fibers come from "breaking Tall Grass or Brown Grass or Prickly Pear" and gives no amounts.

**Sources (section 2):**
- XML:
  - [blocks.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/blocks.xml) and [materials.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/materials.xml)
  - [items.xml v1.0](https://github.com/tassoneroberto/7dtd-assets/blob/main/v1.0/Config/items.xml) (the −0.75 allHarvest penalty) and [items.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/items.xml)
  - [progression.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/progression.xml) (Junk Miner)
- Wiki: [wiki.gg Plant Fibers](https://7daystodie.wiki.gg/wiki/Plant_Fibers)

---

### 3. Rocks and boulders **[XML v3.2]**

| Block | What it is | Material | HP | Harvest | Destroy | Notes |
|---|---|---|---|---|---|---|
| `rock01`…`rock07` | small loose rock on the ground | `Mstone` | **1** (`MaxDamage=1`) | none | **1 Small Stone** | `CanPickup=true` with param `resourceRockSmall`, so **interacting picks it up as 1 Small Stone** |
| `resourceRock01`…`03` | boulder, 3×2×3 multiblock | `Mboulder` | **400** | **22 Small Stones** | 0 | `PassThroughDamage=true` |
| `oreBoulderMaster` children | surface ore boulders (deco ore veins) | see below | 600 | see below | 0 | `dropextendsoff` on master |
| `oreIronBoulder` | iron | `MoreMetal` (metal) | 600 | 105 Scrap Iron + 14 Small Stones | 0 | |
| `oreLeadBoulder` | lead | `MoreMetal` | 600 | 50 Lead + 14 Small Stones | 0 | |
| `oreCoalBoulder` | coal | `MoreStone` (stone) | 600 | 50 Coal + 14 Small Stones | 0 | second `coalHarvest` line pays 0 |
| `orePotassiumNitrateBoulder` | nitrate | `MoreStone` | 600 | 50 Potassium Nitrate + 14 Small Stones | 0 | |
| `oreShaleBoulder` | oil shale | `MoreStone` | 600 | 50 Oil Shale + 14 Small Stones | 0 | |

**Picking up loose rocks:**
- The key is the default "activate/use" key, **E** on PC. This comes only from a community tutorial; I did not confirm it against the 1.x controls menu.
- Hitting the rock also works: 1 HP, 1 stone.
- The wiki says they "do not spawn on roads and only on terrain such as dirt".
- One guide claims they respawn. Nothing in the XML supports that (**unconfirmed**).

**Underground ore veins** (`terrOre*` terrain blocks, 600 HP each) **[XML]**:

| Block | Material | Harvest |
|---|---|---|
| `terrOreIron` | MoreMetal | 105 Scrap Iron + 14 Small Stones |
| `terrOreLead` | MoreMetal | 50 Lead + 14 Small Stones |
| `terrOreCoal` | MoreStone | 50 Coal + 14 Small Stones |
| `terrOrePotassiumNitrate` | MoreStone | 50 Nitrate + 14 Small Stones |
| `terrOreOilDeposit` | MoreStone | 50 Oil Shale + 14 Small Stones |

- Perk-gated bonus drops:
  - Brass 100–400 (5% chance, needs the Strength mastery perk; added after v1.0).
  - Diamond 0.5%, Silver 1%, Gold 0.7%, all needing the *Art of Mining "Lucky Strike"* book.
- Surface ore boulders mark the underground deposits ("used in deco_ore_vein POIs").

**Tool efficiency against rock:** see the material modifier table in 5.2. Rock blocks are `damage_category=stone` (boulders and coal/nitrate/shale) or `metal` (iron and lead).

**Sources (section 3):**
- XML: [blocks.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/blocks.xml), [materials.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/materials.xml), [progression.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/progression.xml) (Lucky Strike, Brass)
- Wiki: [wiki.gg Small Stone](https://7daystodie.wiki.gg/wiki/Small_Stone)
- The pickup key comes from a community tutorial only (not authoritative).

---

### 4. Terrain digging

#### 4.1 Terrain blocks **[XML v3.2; v1.0 identical except snow HP]**

HP is the material `MaxDamage` unless the block overrides it. "Harvest" is the total per block, paid 2/3 during digging and 1/3 on the final hit. "Fall" drops apply only when the block falls as a falling-block entity.

| Block | Display name (approx.) | Material / category | HP | Harvest (total per block) | Fall drops |
|---|---|---|---|---|---|
| `terrDirt` | Dirt | `Mdirt` / earth | 200 | **22 Clay Lumps** | 25% re-sticks as dirt; 18.7% chance of 44 Clay |
| `terrTopSoil` | Topsoil | `Mdirt` / earth | 200 | 22 Clay Lumps | same as dirt |
| `terrForestGround` | Forest ground (grass-topped) | `MforestGround` / earth | 250 | 22 Clay + 2 Plant Fibers | 25% re-sticks; 18.7% chance of 44 Clay |
| `terrBurntForestGround` | Burnt forest ground | `MforestGround` / earth | 250 | 22 Clay | Destroy: 25% chance of 1 Plant Fiber |
| `terrDesertGround` | Desert ground (desert surface, 4 deep) | `MDesertGround` / earth | 180 | 9 Crushed Sand + 9 Clay | 50% chance of 11 Crushed Sand |
| `terrSand` | Sand | `Msand` / earth | 100 | 11 Crushed Sand + 2 Clay | 50% chance of 11 Crushed Sand |
| `terrSandStone` | Sandstone (desert subsoil) | `Mstone` / stone | 500 | 55 Small Stones | as stone |
| `terrSnow` | Snow | `Msnow` / earth | **160** (v1.0–1.4: **50**) | 11 Snowballs | 25% re-sticks; 18.7% chance of 22 Snowballs |
| `terrGravel` | Gravel | `Mgravel` / earth | 200 | 8 Crushed Sand + 9 Small Stones | 16% chance of 23 Sand; 16% chance of 26 Stones |
| `terrStone` | Stone (the bulk underground) | `Mstone` / stone | 500 | **55 Small Stones** | 23% chance of 44 Stones; 10% becomes Destroyed Stone |
| `terrDestroyedStone` | Destroyed stone (rubble; wasteland surface) | `Mrubble` / stone | 200 | 12 Small Stones + 4 Crushed Sand | none |
| `terrDestroyedGrass` | Wasteland destroyed grass | `Mrubble` / stone | 200 | 12 Small Stones + 4 Crushed Sand | none |
| `terrAsphalt` | Asphalt (road) | `Mconcrete` / stone | **1500** (block override) | 27 Small Stones | 75% becomes Destroyed Stone |
| `terrConcrete` | Concrete terrain | `Mconcrete` / stone | 1500 | 27 Small Stones | 75% becomes Destroyed Stone |
| `terrBedrock` | Bedrock | `Mbedrock` | 50 000, `Hardness=10000`, **`CanDestroy=false`** | nothing | |
| `terrDestroyedWoodDebris` | wood debris | `Mwood_regular` / wood | 30 | Wood 1–2 | |

- **No clay terrain block exists.** There is no `terrClay` in any version checked. Clay Lumps come from dirt, topsoil, forest ground, desert ground and sand.
- "Desert sand" in the brief maps to `terrDesertGround` (surface) and `terrSand`.
- `terrStone` has `LPHardnessScale=2`. Its meaning (probably extra hardness under land-claim protection) is **unconfirmed**.
- Terrain column per biome **[XML biomes.xml v3.2]**:

| Biome | Layers from the surface down |
|---|---|
| pine forest | 1 Forest Ground, 3 Dirt, Stone, 3 Bedrock |
| burnt forest | 1 Burnt Forest Ground, 3 Dirt, Stone, 3 Bedrock |
| desert | 4 Desert Ground, Sandstone, 3 Bedrock |
| snow | 1 Snow, 3 Dirt, Stone, 3 Bedrock |
| wasteland | 2 Destroyed Stone or Destroyed Grass, 2 Dirt, Stone, 3 Bedrock |

#### 4.2 Tool and yield

- The yield per block is fixed by the table above. The tool only changes **how fast** you get it, through block damage times the material modifier (see 5.2 and 5.3).
- Exception: clubs, spears, bats, sledges and batons give 25% (`HarvestCount −0.75` on `oreWoodHarvest`).
- Fists give the full yield, just slowly.
- Boosts on `oreWoodHarvest` (wood, stone, ore, clay and sand):

| Source | Bonus |
|---|---|
| Mother Lode perk | +20/40/60/80/100% (ranks 1–5) |
| Rock Busters candy | +20% |
| *Art of Mining* coffee books | +10% each while the matching coffee buff is active |
| *Art of Mining* complete set | +20% |
| Chainsaw | +20% |
| Auger | +20% (all tags) |

#### 4.3 Bedrock and dig depth

- **Every biome's terrain column ends in 3 layers of `terrBedrock`** **[XML biomes.xml]**.
- Bedrock cannot be damaged. Its material has `CanDestroy=false`, and `ItemActionAttack.Hit` sets the hardness multiplier to 0 for such materials **[CODE V1.1]**.
- The absolute Y level, and so the depth below the surface, is **unconfirmed**. Forum reports conflict, and one 2024 post says it was raised.

#### 4.4 Putting terrain back

Players can craft placeable terrain blocks **[XML recipes.xml, identical in v1.0 and v3.2]**:

| Block | Recipe | Where |
|---|---|---|
| Dirt (`terrDirt`) | 16 Clay | backpack, 3 s |
| Topsoil (`terrTopSoil`) | 16 Clay | backpack, 3 s |
| Destroyed Stone | 18 Small Stones | backpack, 2 s |
| Gravel | 11 Crushed Sand + 11 Small Stones | backpack |
| Gravel | 10 + 10 | cement mixer |
| Stone (`terrStone`) | 10 Crushed Sand + 18 Small Stones + 4 Cement | cement mixer |
| Asphalt | 8 Crushed Sand + 17 Small Stones + 5 Oil Shale | cement mixer |

Digging dirt gives 22 clay; crafting 1 Dirt costs 16. A dug block cannot be picked up as itself. When dirt or snow falls, there is a 25% chance it re-places as a block (`Fall` with `stick_chance=1`).

#### 4.5 Protection near traders, land claims and POIs

All of the following come from `ItemActionAttack.Hit` **[CODE V1.1]**:

| Case | Effect |
|---|---|
| Inside a **trader area** | Block damage is 0. |
| Outside the playable world bounds (less than 50% in bounds) | Block damage is 0. |
| Material with `CanDestroy=false` (bedrock) | Block damage is 0. |
| Inside a **land claim** (for non-owners and non-allies) | Block hardness is multiplied by `LandClaimOnlineDurabilityModifier` / `LandClaimOfflineDurabilityModifier`, **default 4** each **[serverconfig template]**. That means 1/4 damage. |

- Land claim defaults: `LandClaimSize=41` (41×41 m, full height), `LandClaimDeadZone=30`, `LandClaimCount=3`, `LandClaimExpiryTime=7` real days.
- wiki.gg *Land Claim Block*: non-owners "cannot place or destroy blocks in its area". It also suppresses POI sleeper respawns and quest selection of that POI.
- wiki.gg *Traders*: the compound and surroundings "are indestructible"; players "cannot place or destroy any blocks". Open 04:05–21:50; players are kicked out at closing. The trader-zone size is **unconfirmed**.
- No general "cannot dig near POIs" rule was found (**unconfirmed**).

**Sources (section 4):**
- XML:
  - [blocks.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/blocks.xml) and [blocks.xml v1.0](https://github.com/tassoneroberto/7dtd-assets/blob/main/v1.0/Config/blocks.xml) (snow HP)
  - [materials.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/materials.xml)
  - [biomes.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/biomes.xml)
  - [recipes.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/recipes.xml)
  - [progression.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/progression.xml) (Mother Lode)
- Code, V1.1 b14: [ItemActionAttack.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/ItemActionAttack.cs) (trader, bounds, CanDestroy, land claim)
- Server: [serverconfig template](https://github.com/GameServerManagers/Game-Server-Configs/blob/main/sdtd/serverconfig.xml)
- Wiki: [wiki.gg Land Claim Block](https://7daystodie.wiki.gg/wiki/Land_Claim_Block), [wiki.gg Traders](https://7daystodie.wiki.gg/wiki/Traders)

---

### 5. Tools and melee

#### 5.1 Base stats **[XML v3.2 items.xml]**

Values are for **Quality 1, no perks, no mods**. Swing interval is `60/APM + 0.1 s` **[CODE V1.1 ItemActionDynamicMelee]**.

| Tool (item name) | Block dmg | Entity dmg | Attacks/min (swing interval) | Stamina, light | Stamina, power | Entity range / block range (m) | Durability Q1→Q6 |
|---|---|---|---|---|---|---|---|
| **Fist** (`meleeHandPlayer`) | 2.2 | 5 | 80 (0.85 s) | 10.5 | 15.8 | 2.0 / 2.6 | none |
| **Stone Axe** (`meleeToolRepairT0StoneAxe`) | 22 | 6 | 105 (0.67 s) | 8 | **no power attack**: RMB is Repair/Upgrade, repair amount 100 | 2.4 / 3.0 | 250→500 |
| **Stone Shovel** (`meleeToolShovelT0StoneShovel`) | 38 | 9 | 50 (1.30 s) | 16.2 | 32.5 | 2.6 / 3.5 | 250→500 |
| **Stone Spear** (`meleeWpnSpearT0StoneSpear`) | 5 | 12 | 55 (1.19 s) | 18.5 | 26.1 | light 2.6, power **3.6** / 3.5 | 100→200 |
| **Wooden Club** (`meleeWpnClubT0WoodenClub`) | 11 | 12 | 55 (1.19 s) | 17.4 | 26.1 | 2.4 / 3.0 | 100→200 |
| **Bone Knife** (`meleeWpnBladeT0BoneKnife`) | 4 | 5 | 120 (0.60 s); power 60 | 7.3 | 10.9 | 2.0 / 2.5 | 250→500 |
| **Iron Pickaxe** (`meleeToolPickT1IronPickaxe`) | 42 | 11.2 | 65 (1.02 s) | 18.4 | 31.3 | 2.4 / 3.5 | 500→1000 |
| **Iron Shovel** (`meleeToolShovelT1IronShovel`) | 62 | 15 | 50 (1.30 s) | 20.3 | 40.6 | 2.6 / 3.5 | 500→1000 |
| **Iron Fireaxe** (`meleeToolAxeT1IronFireaxe`) | 47 | 15 | 65 (1.02 s); **v1.0: 60** | 18.4 (v1.0: 19.9) | 31.3 (v1.0: 39.9) | 2.6 / 3.5 | 500→1000 |
| *Iron Club*: **does not exist** in 1.x–3.x. Nearest T1 equivalents follow. | | | | | | | |
| Baseball Bat (`meleeWpnClubT1BaseballBat`, T1 club) | 18 | 20 | 52 (1.25 s) | 20.9 | 35.6 | 2.4 / 3.0 | 200→500 |
| Iron Sledgehammer (`meleeWpnSledgeT1IronSledgehammer`, T1 blunt) | 52 | 32 | 34 (1.86 s) | 36.7 | 73.4 | 2.6 / 3.5 | 200→400 |

**Quality and degradation:**
- Quality tiers 2→6 add **+15%→+75% block damage** for axes and picks. For shovels and weapons they add +10%→+50% block damage. Entity damage gets **+10%→+50%** on all of these.
- `DegradationPerUse=1` per hit.
- `DegradationBreaksAfter` is false (also the code default), so at 0 durability the tool **does not break**; it just cannot be used ("needs repair").
- Below 50% condition, damage scales linearly down to **50% at 0 condition** (`DegradationModifier`) **[CODE V1.1]**.

**Random stat rolls by version:**
- **v3.x adds per-item random stat rolls** (`<stats>` blocks). Every item gets a base roll of +0–10% entity and block damage, +0–2% APM, 0 to −10% stamina cost and +0–10% durability. Higher qualities get extra "boosted" rolls.
- v1.0–1.4 instead had an untiered random ±4% on entity and block damage.

#### 5.2 Material multipliers (`DamageModifier perc_add` by the block's `damage_category`) **[XML v3.2; same in v1.0]**

| Tool | wood | earth (dirt, clay, sand, gravel, snow, grass, leaves) | stone (stone, boulder, asphalt, coal, nitrate, shale) | metal (iron and lead ore) |
|---|---|---|---|---|
| Fist | ×1 | ×0.5 | ×0.5 | ×0.5 |
| Stone Axe | ×1 | **×0.15** | ×0.67 | ×0.5 |
| Stone Shovel | ×0.3 | ×1 | ×0.2 | ×0.2 |
| Stone Spear | ×0.2 | ×1 | ×0.1 | ×0.1 |
| Wooden Club | ×1 | ×0.5 | ×0.5 | ×0.5 |
| Bone Knife | ×1 | ×0.2 | ×0.2 | ×0.2 (and **+60% vs organic targets**) |
| Iron Pickaxe | ×0.2 | ×0.2 (gravel ×1.0, because +0.8 vs the block tag `terrGravel` cancels the −0.8) | ×1 | ×1 |
| Iron Shovel | ×0.3 | ×1 | ×0.2 | ×0.2 |
| Iron Fireaxe | ×1 | ×0.2 | ×0.25 | ×0.25 |
| Baseball Bat | ×1 | ×0.5 | ×0.5 | ×0.5 |
| Iron Sledgehammer | ×1 | ×1 | ×1 | ×1 |

How the multipliers combine:
- `perc_add` values on the same stat are **additive**. Example: a Q6 Fireaxe power attack on wood is `47 × (1 + 0.75 + 1.25)`, not `47 × 1.75 × 2.25`.
- The final block damage per hit is **truncated to an integer, with a minimum of 1** **[CODE V1.1]**.
- All natural materials have `Hardness=1`. Damage is divided by hardness.
- "Harvest multiplier vs damage": the material multiplier changes **damage only**. Yield is a separate `HarvestCount` multiplier (5.4).
- The `ToolCategory harvestingTools` value and param1 only apply to drops carrying `tool_category="harvestingTools"`. No natural block uses it in v3.2; only `Disassemble` and `Butcher` are used.

#### 5.3 Hits to destroy (DERIVED: Q1, primary attack, no perks, no v3 stat rolls)

| Target (HP, category) | Fist | Stone Axe | Stone Shovel | Wooden Club | Iron Pickaxe | Iron Shovel | Iron Fireaxe |
|---|---|---|---|---|---|---|---|
| Small tree / stump (300, wood) | 150 hits, ≈128 s | **14, ≈9 s** | 28, 36 s | 28, 33 s | 38, 39 s | 17, 22 s | **7, 7 s** |
| Full tree (1200, wood) | 600, ≈8.5 min | 55, 37 s | 110, 143 s | 110, 131 s | 150, 153 s | 67, 87 s | 26, 27 s |
| Dirt / gravel (200, earth) | 200, 170 s | 67, 45 s | **6, 8 s** | 40, 48 s | 25, 26 s (gravel 5, 5 s) | **4, 5 s** | 23, 24 s |
| Sand (100) | 100 | 34 | 3 | 20 | 13 | 2 | 12 |
| Snow (160 in v2+) | 160 | 54 | 5 | 32 | 20 | 3 | 18 |
| Boulder (400, stone) | 400, 340 s | 29, 19 s | 58, 75 s | 80, 95 s | **10, 10 s** | 34, 44 s | 37, 38 s |
| Stone terrain (500, stone) | 500 | 36, 24 s | 72 | 100 | **12, 12 s** | 42 | 46 |
| Ore block (600, stone or metal) | 600 | 43 (stone) / 55 (metal) | 86 | 120 | **15** | 50 | 55 |
| Asphalt (1500, stone) | 1500 | 108 | 215 | 300 | 36 | 125 | 137 |

Effective damage per hit used above (wood/earth/stone/metal): Fist 2/1/1/1, Stone Axe 22/3/14/11, Stone Shovel 11/38/7/7, Wooden Club 11/5/5/5, Iron Pickaxe 8/8/42/42, Iron Shovel 18/62/12/12, Iron Fireaxe 47/9/11/11. Others: Stone Spear 1/5/1/1, Bone Knife 4/1/1/1, Bat 18/9/9/9, Iron Sledge 52/52/52/52.

#### 5.4 Harvest multiplier (`HarvestCount`)

`HarvestCount` is **separate from damage** **[XML entityclasses + items]**:

| Source | Effect |
|---|---|
| Player base (entity class) | HarvestCount **1.0** for `allHarvest`, `oreWoodHarvest`, `cropHarvest` and `wildCropsHarvest`. 0.5 for `butcherHarvest`. **0** for every perk-gated tag (honey, Lucky Strike gems, Brass, `coalHarvest`, …). |
| Wooden Club, Baseball Bat, spears, sledgehammers, Stun Baton, flashlight, Junk Sledge | `base_add −0.75` on `oreWoodHarvest` and `allToolsHarvest`, so **25% yield** from trees, stone, terrain and ore. In v1.0–1.4 also on `allHarvest` (grass and bushes). |
| Axes, picks, shovels, knives | no penalty (1.0) |
| Knives, axes, machete | HarvestCount 0.7–1.0 for `butcherHarvest` (animal corpses) |
| Perks, books, buffs | see 4.2 and section 2 |

The wiki says the same (wiki.gg *Harvesting*, May 2024): "Clubs, hammers, and spears have an inherent 75% loss of all resources when used for harvesting."

#### 5.5 Power attacks (right mouse button) **[XML v3.2]**

- Power attacks use Action1 with `UsePowerAttackAnimation`, a separate, slower animation.
- Damage bonus by weapon type (Q1):

| Bonus (entity and block) | Weapons |
|---|---|
| +100%, so ×2 | Fist, spear, club, bat, knife, pickaxe |
| +125%, so ×2.25 | Shovels, Fireaxe, sledgehammer |

- **Bone Knife:** power attack gets +5.1 flat entity damage before the ×2, so `(5 + 5.1) × 2 = 20.2`, and its APM drops by 60 (to 60).
- **Stamina:** the cost uses the `secondary` value in 5.1 (about 1.4–2× the light attack).
- **Stamina stunt:** a power attack applies `buffPowerAttackStaminaStunt`, which **stops stamina regeneration for 1.5 s**.
- **Spear:** reach rises from 2.6 m to 3.6 m.
- **Sledge:** +30% dismember chance on power attacks (+10% on light attacks).
- The attack-rate gate in code is the same `60/APM + 0.1 s` for both buttons. How long the power-attack animation actually takes is **not in the files** (unconfirmed).
- The Stone Axe and other repair tools have **no** power attack.

Examples (Q1, power attack): Iron Fireaxe 33.75 entity / 105.75 block; Iron Sledgehammer 72 / 117; Wooden Club 24 / 22; Iron Shovel 33.75 / 139.5.

#### 5.6 Headshots, dismemberment and knockdown

**Headshot multiplier:**
- **v1.0:** the player has `DamageModifier perc_add +1 tags="head"`, so **×2 damage to the head**.
- **v3.2:** the same +100% is written as `HeadshotDamageModifier`. That name is **not in the V1.1 `PassiveEffects` enum**, so its engine wiring in 3.x is **unconfirmed**.
- Attributes add more for their own weapons: `+10%` per level at levels 2–8 (up to +70%), +85% at level 9 and +100% at level 10 (progression.xml). Examples: Perception for spears, Strength for clubs and sledges.
- A community post claims the attribute bonus *replaces* rather than stacks with the base bonus (unconfirmed).

**Dismemberment** **[CODE V1.1 + XML]**:
- Base `DismemberChance` is 0.05. Attribute levels 2–10 add +5% to +45%. The sledgehammer adds +10% (light) and +30% (power).
- Zombie multipliers: `DismemberMultiplierHead/Arms/Legs` are 1 for normal zombies; ferals have a head multiplier of 0.7.
- On a killing hit:
  - **Head**, if the hit dealt ≥20% of max HP: chance = max(chance × 0.5, **0.3**).
  - **Other parts**, if ≥12%: chance = max(chance × 0.5, **0.5**).
- **A head dismember always kills** (damage is set to the remaining HP).

**Knockdown and cripple** (zombie template):
- Kneel when a hit deals ≥40% of max HP; prone when ≥50%. Stun lasts 0.5–1.8 s.
- Leg-cripple chance = (damage fraction) × 2 (`LegCrippleScale=2`).
- `PainResistPerHit` 0.55: hits slow the zombie until pain resistance builds up.

**Game difficulty also scales player damage to zombies** **[CODE V1.1 `difficultyModifier`]**:

| Difficulty | 0 Scavenger | 1 Adventurer | 2 Nomad | 3 Warrior | 4 Survivalist | 5 Insane |
|---|---|---|---|---|---|---|
| Player → zombie damage | ×2 | ×1.5 | ×1 | ×0.83 | ×0.66 | ×0.5 |
| Zombie → player damage | ×0.5 | ×0.75 | ×1 | ×1.5 | ×2 | ×2.5 |

Which difficulty is the vanilla default is **unconfirmed**: the serverconfig template shows `GameDifficulty=1`, while a 2019 moderator post says 2.

**Sources (section 5):**
- XML:
  - [items.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/items.xml), [items.xml v2.6](https://github.com/tassoneroberto/7dtd-assets/blob/main/v2.6/Config/items.xml), [items.xml v1.0](https://github.com/tassoneroberto/7dtd-assets/blob/main/v1.0/Config/items.xml)
  - [materials.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/materials.xml)
  - [entityclasses.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/entityclasses.xml) (HarvestCount, head bonus, knockdown)
  - [progression.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/progression.xml) (attribute headshot and dismember bonuses)
  - [buffs.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/buffs.xml) (power-attack stamina stunt)
- Code, V1.1 b14: [ItemActionAttack.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/ItemActionAttack.cs), [ItemActionDynamicMelee.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/ItemActionDynamicMelee.cs), [ItemActionDynamic.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/ItemActionDynamic.cs), [EntityAlive.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/EntityAlive.cs) (dismember), [ItemClass.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/ItemClass.cs)
- Server: [serverconfig template](https://github.com/GameServerManagers/Game-Server-Configs/blob/main/sdtd/serverconfig.xml)
- Wiki: [wiki.gg Harvesting](https://7daystodie.wiki.gg/wiki/Harvesting), [wiki.gg Tool](https://7daystodie.wiki.gg/wiki/Tool)

---

### 6. Stamina and player stats **[XML entityclasses + buffs, identical v1.0 → v3.2 unless noted]**

| Stat | Value | Source / notes |
|---|---|---|
| Health max | **100** base | `HealthMax base_set 100` |
| Stamina max | **100** base | |
| Food max | **100** base (code default; no XML base) | `EntityStats`: FoodMax default 100 [CODE] |
| Water max | **100** base | |
| Level bonus | +1 per player level to all four maxes (level 1 gives +0), **capped at +100** (so 200 at level 101+) | buffStatusCheck01. **v3.x:** only if the sandbox option `PlayerLevelBonusApplied` is on. |
| Stamina regen | **+10 per second** (`StaminaChangeOT base_set 10`) | Scaled by the water band below. Ticks every 0.5 s [CODE]. |
| Sprinting | `perc_add −1.45` → **net −4.5 stamina/s** | Crouch-walking −15% regen. Swimming −1.15 (net −1.5/s). Swim-sprint −1.9 (net −9/s). |
| Jump | **20 stamina per jump** (`StaminaLoss base_set 20 tags=jumping`; code default 4) | The Parkour perk reduces it by up to 50%. |
| Swim stroke | 40 (`StaminaLoss` tag `swimming`) | |
| Melee swing | per weapon, 7.3–36.7 light and 10.9–73.4 power (5.1) | Grazing hits cost 1% of that. |
| Water band on regen | Water ≥50%: ×1. 25–50%: ×0.5. Under 25%: ×0.25. **Water 0: no stamina or health regen.** | `EntityStats.GetWaterPercent` [CODE V1.1] |
| Health regen | `HealthChangeOT 0.017/s`, about **1 HP per minute** (XML comment), × water band | Disabled while Starving (Hungry03) or Dehydrated (Thirsty03). |
| Food drain | `−0.00833/s` = **30 per real hour**; at the default 60-minute day, **30 per in-game day** | Plus 0.00408 food per stamina point regenerated. |
| Water drain | `−0.0111/s` = **40 per real hour**, so 40 per in-game day | Plus 0.00453 water per stamina point regenerated and 0.06 water per HP healed. |
| Carry | 45 UI slots; 27 base carry capacity (cvar) | |

**At 0 stamina** **[CODE V1.1 + WIKI]**:
- **No melee swing** if current stamina is below that swing's cost. The game shows the "Out of stamina" tooltip and plays a sound.
- **No sprinting** (wiki.gg *Stamina*).
- Jumping: the code deducts stamina but has no stamina check in the jump path, so it is probably still allowed (**unconfirmed**).
- Damage is **not** scaled by stamina for players. `ItemActionDynamicMelee` passes a stamina multiplier of 1; only the old `ItemActionMelee` class used by zombie hands uses stamina %.
- Aiming can be held at 0 stamina (wiki).

**Hunger and thirst stages** (buffStatusCheck01 → buffStatusHungry01–03 / Thirsty01–03). Thirst works exactly like hunger, using the Water stat.

| Food (or water) % of max | Buff | Effect |
|---|---|---|
| ≤ 50% | Hungry01 / Thirsty01 | blocks **20%** of (100 + level bonus) max stamina |
| ≤ 25% | Hungry02 / Thirsty02 | blocks **40%** of max stamina |
| ≤ 2% | Hungry03 / Thirsty03 ("starving" / "dehydrated") | blocks **60%** of max stamina, **−0.25 HP every 2.2 s** (≈ 6.8 HP/min, "~14:30 [min] @ 100HP"), no natural health regen, Hungry03 also −10% stamina regen |
| 0% water | Thirsty03 still active, plus the water band ×0 | everything in the ≤2% row, and also **no stamina or health regen at all** |

**Wiki conflict:** wiki.gg *Stamina* (edited April 2026) says "Max Stamina is usually equal to your Fullness level". That describes A17–A20. In 1.0+ the XML instead uses the fixed 20/40/60% "blockage" stages above.

**Sources (section 6):**
- XML: [entityclasses.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/entityclasses.xml) and [entityclasses.xml v1.0](https://github.com/tassoneroberto/7dtd-assets/blob/main/v1.0/Config/entityclasses.xml) (playerMale), [buffs.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/buffs.xml) and [buffs.xml v2.6](https://github.com/tassoneroberto/7dtd-assets/blob/main/v2.6/Config/buffs.xml) (buffStatusCheck01, Hungry and Thirsty)
- Code, V1.1 b14: [EntityStats.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/EntityStats.cs), [EntityPlayerLocal.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/EntityPlayerLocal.cs), [EntityAlive.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/EntityAlive.cs) (jump), [ItemActionDynamicMelee.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/ItemActionDynamicMelee.cs)
- Wiki: [wiki.gg Stamina](https://7daystodie.wiki.gg/wiki/Stamina)

---

### 7. Regular walker zombies

#### 7.1 Stats **[XML v3.2; v1.x differences noted]**

| Zombie | Template | Base HP (v2.1 → 3.2) | Base HP (v1.0 → 1.4) | Hand item: entity / block damage, reach | MoveSpeedAggro (day min, night max) | XP |
|---|---|---|---|---|---|---|
| **Arlene** (`zombieArlene`) | Short / slim | **125** ±15% (106–144) | **150** ±15% | `meleeHandZombieShort`: **8** / 7, 1.4 m | 0.3 / 1.35 | 400 |
| **Business Man** (`zombieBusinessMan`) | Short | 125 ±15% | 150 ±15% | Short: 8 / 7, 1.4 m | 0.3 / 1.35 | 400 |
| **Joe** (`zombieJoe`) | Male, with the short hand item since v2 | 125 ±15% | 150 ±15% | v2+: Short 8 / 7. v1.x: `meleeHandZombie01` **10** / 8, 1.6 m | 0.3 / 1.35 | 400 |
| Marlene, Steve, Tom Clark, Party Girl, Nurse | Short / slim | 125 ±15% (healthSlim) | 150 | Short 8 / 7 | 0.3 / 1.35 | 400 |
| Boe (`zombieBoe`) | Male, normal | **200** ±15% (healthNormal) | 200 | Zombie01: **10** / 8, 1.6 m | 0.2 / 1.25 | 500 |
| Feral Arlene (example) | | 500 | | ShortFeral 16 / 22 | 0.6 / 1.45 | 800 |

Notes on the table:
- **Damage conflict inside the file.** The zombie hand items set `DamageEntity` in Action0 (10 male, 8 short). They also carry a passive `EntityDamage base_set 10`, but the file's own comment says passives "have no effect whatsoever on zombies". So **8 (short) / 10 (male)** is the likely value, and it is the ×1 baseline at difficulty Nomad. Multiply by the difficulty table in 5.6.
- Each zombie hit also rolls one of these on the player, with weights: Fatigued .11, Sprained arm .07, Sprained leg .07, Laceration .05, Abrasion .29, Stun .36, Bleeding .11. Infection +10 per hit once the player is infected.
- **Attack rate:** `AttackTimeoutDay = 1.5 s`, `AttackTimeoutNight = 1.1 s` between attacks.
- **Senses:**

| Property | Value |
|---|---|
| `SightRange` | 30 m |
| `MaxViewAngle` | 180° |
| `SightLightThreshold` | −2 (point blank) to 150 (at 30 m) |
| `AINoiseSeekDist` | 8 |
| `AIFeralSense` | 1.5 |
| `JumpMaxDistance` | 2.8–3.9 m (ferals 4.6–5 m) |

- Losing sight of a "hunted" player: the zombie goes to the last known location for 30 s (Stealth.txt, hardcoded).
- `LootDropProb` 0.04 (4% loot bag). The corpse stays 30 s, `DeadBodyHitPoints` 1000.

#### 7.2 Walk and run speed

**No metres-per-second value exists in the files.** Zombies use root-motion animations. `MoveSpeed*` values are animation blend and speed multipliers, so **m/s is unconfirmed**; it would have to be measured.

| Property | Value | Meaning |
|---|---|---|
| `MoveSpeed` | 0.08 | idle shamble / wander |
| `MoveSpeedAggro` | slim 0.3, 1.35; male 0.2, 1.25 | chase speed (min, max) |
| `MoveSpeedRand` | −0.2 … +0.25 | added to the min aggro speed per zombie, scaled by difficulty, clamped to 0.1…max |
| `MoveSpeedPanic` | 0.55 | |

The chase speed formula **[CODE V1.1 `EntityHuman.GetMoveSpeedAggro`]**:
- The game picks a speed setting by situation: `ZombieMove` (day), `ZombieMoveNight` (dark), `ZombieFeralMove` (ferals) and `ZombieBMMove` (blood moon).
- Setting index → factor: walk 0, jog 0.35, run 0.7, sprint 1.0, nightmare 1.35.
- If factor < 1: speed = lerp(min, max, factor). Otherwise: speed = max × factor.
- Rage (from falls etc.) uses factors 0.75 / 0.8 / 0.9 / 1.15 / 1.7.
- **Default settings** **[serverconfig template]**: `ZombieMove=0` (**walk by day**, so the min aggro speed of about 0.3), `ZombieMoveNight=3` (**sprint at night**, so 1.35 for slims), `ZombieFeralMove=3`, `ZombieBMMove=3`.
- A Steam forum post gives nightmare as 1.2× max. The V1.1 code says 1.35. The code is newer.

#### 7.3 Sleepers in POIs

From Stealth.txt and entityclasses **[XML]**, plus the developer quote **[FORUM]**:

- Sleepers spawn from **sleeper volumes** placed in the prefab. Without a volume, nothing spawns. A volume uses a spawn group from gamestages.
- They spawn in a sleeping pose when players come near the volume. A player report puts that at about 10 blocks (unconfirmed).
- Each volume has a trigger type (passive, active/attack, or a scripted trigger linked to a switch or door). Exact semantics are **unconfirmed** beyond this developer quote:

> "This happens once per AI based on stealth modified light level vs distance and only determines attack vs active. They will go active in any event and continuous stealth checks may hear or see you at any time after that."

  — faatal, TFP developer, 2022

- **Waking by noise.** Each zombie rolls `SleeperNoiseToSense` 3–8 (stir and groan) and `SleeperNoiseToWake` **9–12** (wake). Each sound in sounds.xml has a range, a volume and a duration. Sounds **stack** while their durations overlap, and crouching muffles them (`muffled_when_crouched`).
- **Waking by sight and light.** Each zombie rolls `SleeperSightToWakeMin` −40…5 (light value needed at point blank) and `SleeperSightToWakeMax` 340…480 (at 30 m), and lerps between them by distance. There are matching groan thresholds (−10…0 and 200…300).
  - The player's "stealth light value" is ambient light times a stance factor: 0.5 crouched and still, 1.25 crouch-walking, 1.5 crouch-running, 1.5 walking, 2.0 running.
  - A held light (torch, flashlight) adds its `LightValue`, up to 1.0 (100).
  - Cover is binary: vision is either blocked or not.
- **Smell:** `SleeperSmellSenseThreshold` 20–50 and `SleeperSmellWakeThreshold` 40–100 exist in **v1.0–1.4**. They were **removed by v2.1** (the v3.2 Stealth.txt smell section is empty).
- Land claims stop POI sleepers from respawning inside the claim (wiki). The POI respawn timer is not documented here (unconfirmed).

**Sources (section 7):**
- XML:
  - [entityclasses.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/entityclasses.xml), [entityclasses.xml v2.6](https://github.com/tassoneroberto/7dtd-assets/blob/main/v2.6/Config/entityclasses.xml), [entityclasses.xml v1.0](https://github.com/tassoneroberto/7dtd-assets/blob/main/v1.0/Config/entityclasses.xml)
  - [items.xml v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/items.xml) (zombie hand items)
  - [Stealth.txt v3.2](https://github.com/tassoneroberto/7dtd-assets/blob/main/v3.2/Config/Stealth.txt) and [Stealth.txt v1.0](https://github.com/tassoneroberto/7dtd-assets/blob/main/v1.0/Config/Stealth.txt)
- Code, V1.1 b14: [EntityHuman.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/EntityHuman.cs) (GetMoveSpeedAggro), [ItemActionAttack.cs](https://github.com/HuitDR/AssemblyCSharp/blob/master/ItemActionAttack.cs) (difficulty modifier)
- Server: [serverconfig template](https://github.com/GameServerManagers/Game-Server-Configs/blob/main/sdtd/serverconfig.xml) (ZombieMove settings)
- Forum: [faatal on sleeper volumes, 2022](https://devtrackers.gg/7-days-to-die/p/fbbbaf8e-so-i-decided-to-track-sleeper-volumes-in-poi-s-and-how-many-are-ambushes)

---

### 8. Gaps and unconfirmed items

1. **Zombie speed in m/s.** It comes from root-motion animations and is not in the configs. It needs measuring in game.
2. **Bedrock absolute Y / dig depth.** Only "the bottom 3 layers of the column" is confirmed.
3. **Default game difficulty** (1 or 2) is not settled, so zombie hit damage (8/10 baseline) may be ×0.75 by default.
4. **`HeadshotDamageModifier`** (the v3.x name of the ×2 head bonus) is not in the V1.1 engine enum, so its wiring is unverified. v1.0 used a plain `DamageModifier` with the head tag.
5. **Code-derived mechanics come from V1.1 b14:** harvest 2/3 + 1/3 split, falling-tree physics and damage, protection checks, the water band, swing timing and the speed formula. Changes in 2.x/3.x code are not verified.
6. **Power-attack animation duration** and real swing time beyond the `60/APM + 0.1 s` gate.
7. **Tree growth units** (`GrowthRate 63`: game or real minutes), and the wiki's 3 h 09 total does not match the 4 stages.
8. **Sapling destroy drop** (the XML says it returns itself; the wiki says nothing).
9. **`HarvestOverdamage=false`** semantics, and `LPHardnessScale=2` on stone.
10. **Loose-rock pickup key** (E, community source only) and whether loose rocks respawn.
11. **Trader protected-zone size**, and any POI dig restriction outside land claims and traders.
12. **Exact patch** where stump yields changed (between v2.1 and v2.6), and where Fireaxe APM changed from 60 to 65 (between v1.0 and v2.6).
13. **Food max base 100** is from the code default; no XML line sets it.
14. **Patch notes on 7daystodie.com were not consulted.** They would answer gap 12 and confirm the version boundaries; every version claim here comes from diffing the XML mirror.
15. **The v3.2 `ToolCategory harvestingTools` multipliers** (0.5 on clubs, bat and sledge) are inert under V1.1 code, because no natural block drop has a `tool_category`. Whether 3.x code changed that is unverified.

---

# Bölüm C: yiyecek, su, ilaç, ölüm, tarım

## 7 Days to Die: food, water, medical, death and farming (numbers reference)

**Sources.** Game XML from the tassoneroberto mirror. Consumables were checked in v1.0, v2.6 and v3.2
and match except the v1.0 rows noted. Loot and death data come from v3.2, with v1.0 checked for
respawn. [WIKI] marks the few answers the XML does not have. Researched 31 October 2026.

**How eating works [XML v3.2 `buffs.xml`].** Food points go in at 1 a second (`buffHealFood`). The
health on food heals over time at 0.5 a second (`buffHealHealth`). "Max stamina" is +10 maximum
stamina for about 423 s (`buffFoodStaminaBonus`). A cooked meal costs 5 water.

### C1. Consumables [XML v2.6/v3.2]

| Item (internal name) | Food | Water | Health (over time) | Other | Stack |
|---|---|---|---|---|---|
| Can of Chili (`foodCanChili`) | 15 | 0 | +7 | — | 10 |
| Can of Beef / Chicken / Lamb | 15 | 0 | +7 | — | 10 |
| Can of Dog Food / Cat Food | 10 | 0 | +5 | — | 10 |
| Grilled Corn (`foodCornOnTheCob`) | 10 | −5 | +5 | +10 max stamina | 10 |
| Baked Potato | 10 | −5 | +5 | +10 max stamina | 10 |
| Charred Meat | 10 | −5 | +5 | +10 max stamina | 10 |
| Grilled Meat | 10 | 0 | +5 | +10 max stamina | 10 |
| Blueberries, Potato (raw) | 2 | 0 | 0 | — | 125 |
| Corn, Yucca fruit (raw) | 2 | 0 | +3 | — | 125 |
| Murky Water (`drinkJarRiverWater`) | 0 | 10 | −5 at once | 12 % dysentery | 10 |
| Water (`drinkJarBoiledWater`) | 0 | 20 | 0 | — | 10 |
| Pure Mineral Water | 0 | 60 | 0 | Red Tea buff ~363 s | 10 |
| Yucca Juice | 0 | 34 | 0 | — | 10 |

- Canned food gives no water in 1.x and later.
- v1.0: Murky Water stacks to 125, blueberries give 1 food, raw corn heals 1.
- Recipes (campfire): Charred Meat 5 raw meat; Grilled Meat and Grilled Corn need a grill; Water
  (1 Murky Water) and Yucca Juice (1 yucca fruit + 1 Water) need a cooking pot. Drinking from a jar
  gives the empty jar back.
- Dysentery: 12 % base (perks lower it); each catch adds 1080 to its counter (cap 3600); each attack
  costs 1.5 water and 0.5 food per tick for 5.5 s.

### C2. Drinking from a lake or river

The bare hand (`meleeHandPlayer`) has a "Drink" action on water blocks in v1.0, v2.6 and v3.2:
+10 water, −5 health at once, 12 % dysentery roll, about 1 s per drink. An empty jar fills with
Murky Water at a river in 3.4 s.

### C3. Medical [XML v2.6/v3.2]

| Item | Healing | Recipe | Stack |
|---|---|---|---|
| Bandage | 0 health; only stops bleeding, usable only while bleeding | 10 Cloth | 10 |
| First Aid Bandage | 30 health over ~15 s (Physician ranks: 37.5 / 45 / 60); stops bleeding | 1 Bandage + 1 Aloe Cream (learned) | 5 |

Cloth: 1 cotton plant, or 20 yucca fibres (learnable). Aloe Cream: 4 aloe leaves.

### C4. Death and respawn [XML v3.2; same in v1.0]

| DeathPenalty option | Respawn |
|---|---|
| None | Food, water, health and stamina at max; no XP debt |
| XP Only (the `default` sequence) | XP debt; food, water, health and stamina at max; debuffs removed |
| Injured | XP debt; food and water at 50 %; dysentery and infection stay |
| Permanent Death | Character, map, land claims and bedroll reset |

For 6.5 s after respawning: +100 physical resist and health held full. The wiki's "90 %
health / food / water" does not match the XML. Which option is the default is not in the XML; the
event naming suggests XP Only (unconfirmed).

### C5. Farming [XML v3.2; growth also v1.0/v2.6]

- **Farm Plot:** 4 wood, 10 rotting flesh, 25 potassium nitrate, 100 clay, 20 s; craftable from the
  start. Zombies cannot spawn on a player-placed plot.
- **Seeds:** 5 of the crop make 1 seed (unlocked: blueberry level 12, corn 18, potato 20); very rare
  in cupboard loot.
- **Growth:** stage 1 → stage 2 → harvestable, 63 min each (~126 min total), real time [WIKI]. Light
  level 8+ [WIKI]. **No water needed** (removed in Alpha 9.2).
- **Yield:** 2 crops without perks; 50 % chance to get the seed back; breaking a growing crop returns
  its seed. Living Off The Land: +100 % / +100 % / +200 %.
- **Zombies:** no XML rule; zombies walk through crops (trampling removed in Alpha 10 [WIKI]).

### C6. Loot that carries food [XML v3.2]

- Regular and feral zombies drop a bag 4 % of the time (charged 10 %).
- `zPackReg`: ammo plus one pick from `groupZpackReg01`: food, drinks, medical, scrap, cobblestone
  and glue at high (0.75) each, duct tape 0.5, two items at 0.05. Read as weights, ~15 % food and
  ~15 % drink per bag.
- Food in bags (`groupFoodUncommon`): cans of beef, chili, dog food, sham, lamb, pasta, peas, salmon,
  stock, tuna. Drinks (`groupDrinksUncommon`): Yucca Juice, Goldenrod Tea, Red Tea, Coffee, Beer —
  no plain water.
- **Cupboard:** mostly food trash (bone, rotting flesh, raw corn or potato 0.35, sham sandwich);
  common food 0.05; 20 % extra roll for ingredients or seeds.
- **Cooler:** `groupDrinksCommon` high (empty jar base, Murky Water 0.35, Water 0.20, Mineral Water
  0.05); common and uncommon food 0.20 each.
