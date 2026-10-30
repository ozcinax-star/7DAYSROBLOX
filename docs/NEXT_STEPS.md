# Sonraki aşama

Durum 31 Ekim 2026 itibarıyla. Önce [HANDOFF.md](HANDOFF.md) dosyasını oku. Tasarım kararları
[PLAN.md](PLAN.md) dosyasında; çelişki olursa PLAN.md geçerli.

## Neredeyiz

Proje PLAN.md yol haritasının 1. aşamasında (Prototip). Kullanıcı 30 Ekim'de sırayı değiştirdi:
telefon kapısı ertelendi, 2. aşamadan toplama, crafting ve zombi loot'u öne alındı (PLAN.md,
Yol haritası notu ve Kararlar tablosu).

| Hedef | Durum |
| --- | --- |
| Harita | Bitti: kodla kurulan 2048×2048 harita, 37 bina |
| Zombi altyapısı | Bitti: Humanoid yok, akış alanı, LOD, ses takibi, dalgalar |
| Zombi davranışı | Bitti: yavaş sarsılan yürüyüş, eve girip çıkma, merdivenle üst kat, bina içinde uyuyan zombi, saldırı öncesi kol uzatma, vurulunca sendeleme |
| Zombi görünümü | Bitti: 17 parçalı rig, zayıf ve çürümüş yüz, ten dağılımı, prosedürel topallama, ölünce yığılma |
| Stres testi aracı | Bitti |
| Envanter, toplama, crafting, vuruş, zombi loot'u, kazı | **Sıradaki iş** (aşağıda 1–6) |
| Gündüz-gece, tehdit hesabı, tahta duvar, kamera | **Yapılmadı** |
| Kapı 1: 80 zombiyle orta seviye telefonda 30 FPS | **Ölçülmedi**; kullanıcı erteledi |
| Kapı 2: 3 kişilik test grubu "bir gece daha" diyor | Henüz yapılamaz |

## Kullanıcı kararı bekleyenler

Her sorunun ilk seçeneği benim önerim.

1. **Taş kazma:** 7DTD'de taş kazma yok; ilk kazma demirdir ve demirci ocağı ister. Kullanıcı istediği
   için taş kazma eklenecek ve kayada en iyi alet o olacak. İtiraz yoksa böyle kalır.
2. **Telefon testi:** Ertelendi. Bina parça sayısı hedefin üstünde, ölçüm hâlâ yok.
3. **Edit modunda harita önizlemesi:** Play başlarken eski önizlemeyi kendiliğinden silen küçük bir
   değişiklik yapılsın mı? Daha önce teklif edildi, yanıt gelmedi.
4. **Git yedeği:** Uzak depo yok. GitHub'da özel bir depo açılıp gönderilsin mi? Dışarıya açık bir adım
   olduğu için onay gerekir.

Cevaplananlar: oyuncu zombiye aletle vuracak (bu planın 2. maddesi); zombiler üst kata çıkıyor
(bitti); kapsam kuralı değişti, ana referans 7DTD ve karşılığında bir şey çıkmıyor (PLAN, Kapsam).

## Sıradaki işler

Sıra kullanıcının isteğindeki sırayı izler. Her madde ayrı commit'lenir; her maddeden sonra kullanıcıya
tam test adımları yazılır.

### 1. Envanter

- **Config:** `Config.Items` (yığın boyutu, alet istatistikleri; sayılar aşağıdaki 7DTD tablosundan).
- **Saf modül:** `Shared/Inventory` (ekle, çıkar, yığınla, slot taşı) ve Lune testleri.
- **Sunucu:** `InventoryService`. Envanter sunucuda; yalnızca sahibine yayınlanır. Her yığın kaynağını
  taşır (`Types.ItemSource`).
- **İstemci:** 8 slotluk hotbar ve sırt çantası arayüzü. Seçili alet ele kaynaklı görünür. CoreGui
  sırt çantası kapatılır. Metinler Localization'dan.
- **Kontroller:** PC 1–8 ve fare tekeri, mobilde hotbar'a dokunma, gamepad L1/R1.

### 2. Vuruş

- Tek bir `UseTool` remote'u; yük yalnızca nişan yönü (birim vektör).
- Sunucu doğrular: tip, NaN ve sonsuz değer, birim uzunluk, bekleme süresi (aletin dakikadaki vuruşu),
  hız sınırı.
- Hedefi sunucu bulur: kafadan raycast (`RespectCanCollide`), zombi için koni. Hedef zombi, ağaç,
  çalı, kaya veya arazi olabilir.
- Dayanıklılık: her vuruş 1 düşer. 0'da alet envanterde kalır ama kullanılamaz; küçük taşla onarılır.
- Girdi: Input Action System (PC sol tık, gamepad R2, mobilde ekran düğmesi). Sallama animasyonu diğer
  oyunculara yayınlanır; vurulan zombi sendeler (`ZombieRenderController.flinch` hazır).

### 3. Toplama

- **Ağaç:** Her vuruş, verdiği hasarla orantılı Odun verir (7DTD gibi). Devrilen ağaç istemcide düşer
  ve kaldırılır. Yol bulma hücreleri yeniden hesaplanır; `markNavigation`'daki hesap tek hücre için ortak
  bir yardımcıya taşınır.
- **Çalı ve ot:** Bitki lifi.
- **Kaya:** Küçük taş. Kasaba ve şehir bölgelerinde kaya yok. Ormanda ve taş ocağında daha çok kaya.
- **Yerden taş:** ProximityPrompt ile +1 küçük taş; belli bir süre sonra yeniden çıkar.
- Oyuncu boş elle başlar: yumrukla ağaç keser, yerden taş toplar.

### 4. Crafting

- `Config.Recipes`:
  - Taş balta 2/2/2.
  - Taş kürek 5/3/3.
  - Taş kazma: özel tarif, öneri 4 taş / 3 lif / 3 odun.
  - Odun'dan Kereste.
  - İstenirse tahta sopa.
- Saf `Crafting` modülü ve Lune testleri.
- `CraftingService`: 4 slotluk kuyruk. Malzeme kuyruğa alınırken düşer, iptalde geri verilir.
- Crafting arayüzü.

### 5. Zombi loot'u

- `LootService`, `ZombieService.onDied` olayını dinler (hazır).
- Yaklaşık %20 ihtimalle torba bırakılır; oran Config'de.
- Torbada "Ara" ProximityPrompt'u. Eşyalar envantere girer, sığmayan torbada kalır.
- Torbanın ömrü Config'de.

### 6. Kazılabilir zemin

- Malzeme sınıfına göre voxel canı. Kazınca eşya verir (kil, taş).
- Yasak alanlar: bina çevresi, asfalt ve kaldırım, su kenarı, ana kaya sınırı.
- MapService yükseklik ızgarası ve yol bulma güncellenir.

### 7. Sonra

- **Araç zinciri:** Kullanıcı `rokit install` ve `rojo plugin install` komutlarını kendisi çalıştırır.
  Sonra `stylua --check src tests`, `selene src`, `lune run tests/run`, `rojo build -o build.rbxl`
  ilk kez çalıştırılır ve çıkan sorunlar düzeltilir.
- **Telefon FPS testi** (kullanıcı yapar):
  1. *File → Publish to Roblox*.
  2. Telefondan gir; debug paneli `Config.Debug.AllowedUserIds` içindeki hesapta görünür.
  3. Spawn 80 ve 120 için kasabada ve ormanda 30 sn sonra FPS ve tick oku.

  Tutmazsa sırayla: bina süs parçalarını birleştir, `StreamingTargetRadius` düşür, orman yoğunluğunu
  azalt, istemci `RenderDistance` kıs.
- **DayNightService:** `Lighting.ClockTime` döngüsü (11 dk, %60 gündüz), gün sayacı, faz yayını,
  saf saat modülü + testler, `SkipPhase` debug komutu.
- **ThreatService:** Gürültü (%5/sn söner), İz (günde 3), `Tehdit = İz + Gürültü × 0.35`, 5 kademe
  (0/20/40/60/80), ilk 3 günde en fazla 3. kademe. `emit` → `ZombieService.hearSound`. Ekranda sayaç
  yok, yalnızca debug panelinde.
- **BuildService (tahta duvar):** `BuildRequest` (hücre, yön), tam doğrulama, 24 stud menzil, 2000
  parça tavanı, parça canı 250, zombinin en zayıf parçaya saldırması, ızgara güncellemesi. Kereste
  burada kullanılır.
- **Kamera:** Omuz kamerası varsayılan, FPS geçişi (Input Action System), zoom 4–14.
- **Prototip oyun testi:** 3 kişi, bir gece ve bir horde.

## 7DTD referans sayıları

30 Ekim'de 7 Days to Die 1.0+ wiki'sinden derlendi. Uygulanınca Config'e taşınır.

**Tarifler** (sırt çantasında, kilit yok):

| Eşya | Malzeme | Süre |
| --- | --- | --- |
| Taş balta | 2 küçük taş, 2 bitki lifi, 2 odun | 1,2 sn |
| Taş kürek | 5 küçük taş, 3 bitki lifi, 3 odun | 2,2 sn |
| Taş mızrak | 5 küçük taş, 3 bitki lifi, 3 odun | — |
| Tahta sopa | 5 odun | — |
| İlkel yay | 8 odun, 3 bitki lifi | — |
| Yatak rulosu | 10 bitki lifi | — |
| Kamp ateşi | 5 küçük taş | — |
| Tahta çerçeve | 2 odun | — |

7DTD 1.0'da kereste yok; bizde kullanıcı kararıyla var.

**Kaynak verimleri:**

| Kaynak | Can | Verim |
| --- | --- | --- |
| Küçük ağaç | 300 | toplam 30 odun |
| Orta ağaç | 600 | 70 odun |
| Büyük ağaç | 900 | 110 odun |
| Tam boy ağaç | 1200 | 150 odun |
| Kaya (boulder) | 400 | 22 küçük taş |
| Taş arazi | 500 | 55 küçük taş |
| Toprak | 200 | 22 kil |
| Çakıl | 200 | 8 kum + 9 küçük taş |
| Kum | 100 | 11 kum + 2 kil |
| Ot | 1 | 2 bitki lifi |
| Çalı | — | 1–3 odun |
| Yerdeki küçük taş | — | E ile 1 küçük taş |

Ağaçta odun, verilen hasara oranla her vuruşta gelir; devrilince yalnızca tohum düşer.

**Aletler:**

| Alet | Blok hasarı | Odun / Toprak / Taş çarpanı | Varlık hasarı | Vuruş/dk | Stamina | Dayanıklılık |
| --- | --- | --- | --- | --- | --- | --- |
| Yumruk | 2,2 | 1,0 / 0,5 / 0,5 | 5 | 80 | 10,5 | — |
| Taş balta | 22 | 1,0 / 0,15 / 0,67 | 6 | 105 | 8 | 250 |
| Taş kürek | 38 | 0,3 / 1,0 / 0,2 | 9 | 50 | 16,2 | 250 |
| Demir kazma | 42 | 0,2 / 0,2 / 1,0 | 11,2 | 65 | — | — |

- Crafting kuyruğu 4 slot.
- Zombi loot torbası 7DTD'de %2–4, 6×3 kap, 3600 sn ömür. Bizde %20 (kullanıcı kararı).

## Sonra: 2. aşamanın kalanı

- **Bina loot'u:** Binaların `Loot` özelliği hazır (`Food`, `Medical`, `Metal`, `Fabric`…).
- **Taş inşa kademesi.**
- **3 zombi türü:** Normal, Hızlı, Ses-duyarlı.
- **Horde gecesi:** oyuncu başına 20 zombi, eş zamanlı tavan 120, dalgalar. Dalga altyapısı hazır.
- **Tehdit ipuçları ve karşı önlemler.**
- **Ölüm cezası:** taşınan ham kaynakların %50'si düşer, ekipman kalır (PLAN, Temel kararlar).
- **Kapı:** Test oyuncuları tehdidi bilerek yönetiyor.

## Harita cilası

Düşük öncelikli; telefon ölçümü izin verirse yapılır.

- Bina parça sayısını 10 binin altına indirmek: kasa, kaplama ve süpürgelikleri birleştirmek.
- Yol çizgileri, bordürler, bahçe çitleri.
- Kasaba dışındaki binaların görsel kontrolü: Cabin, Shack, Barn, SawmillShed, FarmHouse.
- Kapıların açılıp kapanması ve kırılması (`DoorBreak` Gürültüsü).
