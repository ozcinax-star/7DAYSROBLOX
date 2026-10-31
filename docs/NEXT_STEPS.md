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
| Envanter | Bitti: 10 + 45 slot, kaynaklı yığınlar, elde görünen alet, arayüz |
| Vuruş | Bitti: 7DTD hasar ve hızları, kafa vuruşu, aşınma, duvar kontrolü |
| Toplama | Bitti: ağaç, çalı, ot, yerdeki taş, kaya; 7DTD verim formülü, ağaç devirme |
| Crafting | Bitti: 7DTD kuyruğu (4 iş), malzeme süreleri, iptal ve iade, taşla tamir, panel |
| Zombi loot'u | Bitti: %20 torba, arama, sığmayan eşya ayağa düşer |
| Gündüz-gece | Bitti: 11 dk döngü, gün sayacı, horde gecesi işareti, gece daha sık saldırı |
| Tehdit ve horde | Bitti: Gürültü / İz / 5 kademe, ortam nüfusu, oyuncu başına 20 zombilik horde dalgaları |
| İnşa, hayatta kalma, kazı, silahlar, tarım | **Sıradaki iş** (kullanıcı 31 Ekim: her iş bitince sıradakini kapat) |
| Kapı 1: 80 zombiyle orta seviye telefonda 30 FPS | **Ölçülmedi**; kullanıcı erteledi |
| Kapı 2: 3 kişilik test grubu "bir gece daha" diyor | Henüz yapılamaz |

## Kullanıcı kararı bekleyenler

Her sorunun ilk seçeneği benim önerim.

1. **Taş kazma ve kereste tarifleri:** 7DTD'de taş kazma yok (ilk kazma demirdir, demirci ocağı
   ister) ve kereste diye bir eşya yok. Kullanıcı istediği için ikisi de eklendi: taş kazma 4 taş /
   3 lif / 3 odun (2 sn), kayada en iyi alet; kereste 2 odun (0,4 sn). İtiraz yoksa böyle kalır.
2. **Telefon testi:** Ertelendi. Bina parça sayısı hedefin üstünde, ölçüm hâlâ yok.
3. **Edit modunda harita önizlemesi:** Play başlarken eski önizlemeyi kendiliğinden silen küçük bir
   değişiklik yapılsın mı? Daha önce teklif edildi, yanıt gelmedi.
4. **Git yedeği:** Uzak depo yok. GitHub'da özel bir depo açılıp gönderilsin mi? Dışarıya açık bir adım
   olduğu için onay gerekir.
5. **Kaynaklar yeniden çıksın mı?** 7DTD'de doğal ağaç ve kayalar geri gelmez; şimdilik bizde de öyle.
   Harita küçük ve dünyalar kalıcı olacak (PLAN), yani bir grup haftalar içinde ormanı bitirebilir.
   Öneri: kalıcılık adımına kadar böyle kalsın; o adımda kesilen nesneler id'leriyle kaydedilsin ve
   ot, çalı ve yerdeki taş birkaç oyun gününde geri gelsin. Ağaç ve kaya 7DTD gibi gelmesin; bunun
   yerine tohum dikimiyle ağaç yetiştirilsin.

Cevaplananlar: oyuncu zombiye aletle vuracak (bu planın 2. maddesi); zombiler üst kata çıkıyor
(bitti); kapsam kuralı değişti, ana referans 7DTD ve karşılığında bir şey çıkmıyor (PLAN, Kapsam).

## Sıradaki işler

Sıra kullanıcının isteğindeki sırayı izler. Her madde ayrı commit'lenir; her maddeden sonra kullanıcıya
tam test adımları yazılır.

### 1. Envanter (bitti, 31 Ekim)

`ec74896`, `383297a`, `859c573`. 7DTD boyutları: 10 slot alet kemeri, 45 slot (5×9) sırt çantası; odun,
küçük taş ve bitki lifi 6000'lik yığın. Kalanlar:
- Fare tekeriyle slot değiştirme: tekerlek kamera zoom'unda; kamera adımında karar.
- 7DTD'nin taşıma yükü (fazla eşyada yavaşlama): sonra.
- Eşya simgeleri: şimdilik renkli kare.

### 2. Vuruş (bitti, 31 Ekim)

`6be883f`, `1b0fb72`. Kalanlar (7DTD'de var):
- Güçlü vuruş (sağ tık): 2× veya 2,25× hasar, daha çok stamina.
- Stamina: vuruş başına stamina; stamina yetmezse vuruş yok. Hayatta kalma istatistikleriyle birlikte.
- Vuruş sesi ve ThreatService'e gürültü; isabet efekti.
- PvP lobi seçeneği gelince oyuncuya vuruş.

### 3. Toplama (bitti, 31 Ekim)

`bf7164e`, `4b47110`, `1102479`, `aaa870f`, `94e90be`. Kalanlar:
- **Tohum:** ağaç devrilince 1–2 tohum (Destroy düşüşü). Tarım adımında.
- **Ağaç zombiyi ezsin:** 7DTD'de düşen ağaç, yolundaki zombilere 1,5 sn sonra
  `int((15 + 7h) × 5 × 0,36)` hasar verir (h: gövde boyu × 0,9, metre); oyunculara vermez.
- **Vuruş efekti ve sesi:** ağaca, kayaya, ota vurunca parçacık ve ses; ağaç vurulunca hafif sallansın.
- **Binaların kapı alanları** açılışta bir kez kuruluyor; bina yanında devrilen ağaç o alanlara yansımaz.
- **Kazı** (6. madde) aynı `onWorldHit` dinleyicisini kullanacak: arazi malzemesi toprak / taş.
- Telefon: alt bitki örtüsü 14.492 parça ekledi; ölçülmedi.

### 4. Crafting (bitti, 31 Ekim)

`5cf6af2`, `f3e58ab`, `410cc9b`, `459404d`. Tarifler: taş balta 2 taş / 2 lif / 2 odun (1,2 sn) ve taş
kürek 5 / 3 / 3 (2,2 sn) 7DTD'den; taş kazma ve kereste bizim (1. soru). Kalanlar:
- **Kuyruk kaydı:** oyuncu çıkınca kuyruk ve içindeki malzeme kayboluyor (7DTD saklar). Kalıcılık
  adımında.
- **İş istasyonları ve tarif kilitleri:** kamp ateşi, tezgah, demirci ocağı ve kitap / perk kilidi
  yok; ihtiyaç doğunca.
- **Tahta sopa:** istenirse eklenecek tarif.
- **Dar ekran:** sırt çantası en küçük slotla 432 px, panel 340 px; 800 px'ten dar ekranda sığmaz.
  Telefon / kamera adımında mobil düzen.

### 5. Zombi loot'u (bitti, 31 Ekim)

`74caafe`, `8c39766`, `531edd1`. Kalanlar:
- **Torba penceresi:** 7DTD'de torba açılınca 18 slotluk pencere çıkar ve eşya tek tek alınır;
  bizde arama sığan her şeyi alır. Sandık / iş istasyonu arayüzüyle birlikte.
- **İçerik:** yiyecek, su, ilaç, mermi ve kitap yok (hayatta kalma istatistikleri ve silahlar
  gelince tabloya eklenecek).
- **Üst üste torbalar:** aynı noktada ölen zombilerin torbaları üst üste duruyor; prompt en
  yakınını seçiyor.
- **Bina loot'u:** binaların `Loot` özelliği (`Food`, `Medical`, …) aynı servisle kaplara bağlanacak.

### 6. Gündüz-gece (bitti, 31 Ekim)

`b97f319`. Kalanlar:
- **Lobi seçimi:** horde aralığı şimdilik sabit 7; lobi kurulurken 5–10 seçimi lobi adımında.
- **Gece görüşü:** gece karanlığı oyuncu ışığı (meşale, fener) gelene kadar hafif tutuldu.
- **Kayıt:** gün ve saat sunucu kapanınca sıfırlanır (kalıcılık adımı).

### 7. Tehdit ve horde (bitti, 31 Ekim)

`9ce4af5`, `9944473`, `adcf548`. Kalanlar:
- **İz kaynakları:** inşa parçası, ışık, ateş, jeneratör gelince `ThreatService.setTraceSource`.
- **Özel zombiler:** PLAN'a göre kademe özel zombi oranını artırır; özel zombi yok.
- **Ortam ipuçları:** uzaktan inlemeler, ufukta sürü, karga, telsiz (PLAN tasarım kuralı 1).
- **Horde hedefi:** PLAN'da İz horde'un hedefini belirler; şimdilik en yakın oyuncu. Üs gelince en
  yüksek İz'li üs.
- **Koşma gürültüsü:** koşma (sprint) yok; hayatta kalma adımında stamina ile gelecek.
- **Yığılma:** kovalama hâlinde hareketsiz kalan birkaç zombi görüldü (Chase, 0 stud/sn); duvar ya
  da merdiven kuyruğu olabilir, incelenmedi.

### 8. Kazılabilir zemin

- Malzeme sınıfına göre voxel canı. Kazınca eşya verir (kil, taş).
- Yasak alanlar: bina çevresi, asfalt ve kaldırım, su kenarı, ana kaya sınırı.
- MapService yükseklik ızgarası ve yol bulma güncellenir.

### 9. Sonra

- **Araç zinciri:** Kullanıcı `rokit install` ve `rojo plugin install` komutlarını kendisi çalıştırır.
  Sonra `stylua --check src tests`, `selene src`, `lune run tests/run`, `rojo build -o build.rbxl`
  ilk kez çalıştırılır ve çıkan sorunlar düzeltilir.
- **Telefon FPS testi** (kullanıcı yapar):
  1. *File → Publish to Roblox*.
  2. Telefondan gir; debug paneli `Config.Debug.AllowedUserIds` içindeki hesapta görünür.
  3. Spawn 80 ve 120 için kasabada ve ormanda 30 sn sonra FPS ve tick oku.

  Tutmazsa sırayla: bina süs parçalarını birleştir, `StreamingTargetRadius` düşür, orman yoğunluğunu
  azalt, istemci `RenderDistance` kıs.
- **BuildService (tahta duvar):** `BuildRequest` (hücre, yön), tam doğrulama, 24 stud menzil, 2000
  parça tavanı, parça canı 250, zombinin en zayıf parçaya saldırması, ızgara güncellemesi. Kereste
  burada kullanılır.
- **Kamera:** Omuz kamerası varsayılan, FPS geçişi (Input Action System), zoom 4–14.
  - Dokunmatik ve gamepad ekran ortasından nişan alır. Hesap: varsayılan kamera başın ~15° aşağısına
    bakarken yumruğun 5,6 stud'luk ışını yerden ~3 stud yukarıda biter. Yani ota (2,6 stud) ve
    yerdeki taşa vurmak için kamera ~40° aşağı eğilmeli. Omuz kamerasında yere bakmak kolay olmalı;
    yerdeki taşta E prompt'u zaten çalışıyor.
- **Prototip oyun testi:** 3 kişi, bir gece ve bir horde.

## 7DTD referans sayıları

Hepsi [REFERENCE_7DTD.md](REFERENCE_7DTD.md) dosyasında; başında bizim uyarlamalarımızın tablosu var.

## Sonra: 7DTD'den gelecekler

- **Hayatta kalma istatistikleri:** can, stamina, yemek, su 100. Stamina saniyede 10 dolar, koşu net
  −4,5/sn, zıplama 20. Yemek saatte 30, su 40 düşer (gerçek saat = 1 oyun günü). Can dakikada 1 dolar
  (Roblox'un varsayılan %1/sn yenilenmesi kapatılır).
- **Zombilerin oyuncuya girmesi:** saldıran zombi oyuncudan en az bir gövde mesafesinde durmalı.
- **Taşıma yükü:** 45 slotun 27'si cezasız; sonrası her slot %2,6 yavaşlatır.
- **Alet kalitesi (1–6).**

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
