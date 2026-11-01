# Sonraki aşama

Durum 1 Kasım 2026 itibarıyla. Önce [HANDOFF.md](HANDOFF.md) dosyasını oku. Tasarım kararları
[PLAN.md](PLAN.md) dosyasında; çelişki olursa PLAN.md geçerli.

## Neredeyiz

**İnceleme (1 Kasım 2026):** Kod ve oyunun tam incelemesi [REVIEW_2026-11-01.md](REVIEW_2026-11-01.md)
içinde. Kod değişmedi. Öne çıkanlar:
- Tepme kamerada birikiyor (ölçüldü).
- Hasar alınca ekranda uyarı yok.
- Hayalet zombi ve gece saldırı animasyonu kayması (koddan doğrulandı).
- Sonsuz Clay döngüsü.
- Robot gibi görünen kutu zombiler ve fazla parlak gündüz ışığı.

Önerilen düzeltme sırası belgenin 7. bölümünde.

**Düzeltme turu (1 Kasım 2026, aynı gün):** İncelemenin 1–5. maddeleri ve sesler yapıldı; 3 zombi türü
eklendi. Özet DEVAM.md'nin başında. Kalan inceleme maddeleri:
- Namlu alevini yerelde tahmin etme.
- Vuruş durması (hit-stop).
- Ölüm çöküşü ve kafa patlaması.
- Görüş konisi.
- Görünür yerde doğmama.
- Zombi rig'inin dokulu mesh'e geçmesi.
- Taş aletler ve yay için mesh; boru silahlara hurda görünüm.
- Ağaçlar ve prop'lar.

Görsel işler Studio görüntüsü düzelince yapılmalı (bu oturumda beyazdı).

Aynı gün sonradan yapılanlar:
- zombilerin görüş konisi (arkadan yaklaşılabiliyor)
- görüş alanında doğmama
- son kod incelemesi ve düzeltmeleri

İncelemede kalan küçük notlar:
- Yüksek pingte bir vuruşun efekti sonraki salınıma kayabilir (yalnızca görsel).
- Ateş çıtırtısı her saniye bütün yapı parçalarını tarıyor; büyük üslerde etiket ya da sinyale geçmeli.
- Doğma kontrolü kameranın değil karakterin yönünü kullanıyor.

Kullanıcı kararı bekleyen:
- **Kalıcılık (DataStore):** PLAN 3. aşama. Şema geri dönüşü zor bir karar olduğu için kullanıcı onayı
  olmadan başlanmadı.

**Silah kullanımı (1 Kasım 2026, Codex):** Şarjör/doldurma artık her silah için sunucuda gerçek;
nişan, tepme, mermi paneli ve birinci/üçüncü şahıs tutuşu yenilendi. 90 test geçti. Kontroller:
R/B Reload, RMB/L2 Aim; yakıt T. [WEAPON_HANDLING.md](WEAPON_HANDLING.md) kullanıcı testini içerir.
Sıradaki görsel kontrol farklı avatar oranları ve telefondaki HUD/performans; sesler kullanıcı seçimi.
Silindir/sürgü/şarjörün ayrı parça olarak sökülüp takıldığı animasyon henüz yok.

**Görsel ek (31 Ekim 2026, Codex):** Kullanıcı önceliğiyle 13 alet ve silah modeli yenilendi.
Detaylar, doğrulamalar ve kullanıcı testi [EQUIPMENT_ART.md](EQUIPMENT_ART.md) içinde.
Binalar, mobilyalar, yerleştirilen eşyalar ve çevre bu görsel adımda değiştirilmedi.
Mobil FPS kapısı ölçülmedi; aşağıdaki sistem sırası devam ediyor.

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
| Envanter | Bitti: 10 + 45 slot, kaynaklı yığınlar, elde görünen alet, arayüz, eşya atma (G / Drop), silah yuvasında cephane (şarjör / taşınan) |
| Vuruş | Bitti: 7DTD hasar ve hızları, kafa vuruşu, aşınma, duvar kontrolü |
| Toplama | Bitti: ağaç, çalı, ot, yerdeki taş, kaya; 7DTD verim formülü, ağaç devirme |
| Crafting | Bitti: 7DTD kuyruğu (4 iş), malzeme süreleri, iptal ve iade, taşla tamir, panel |
| Zombi loot'u | Bitti: %20 torba, arama, sığmayan eşya ayağa düşer |
| Gündüz-gece | Bitti: 11 dk döngü, gün sayacı, horde gecesi işareti, gece daha sık saldırı |
| Tehdit ve horde | Bitti: Gürültü / İz / 5 kademe, ortam nüfusu, oyuncu başına 20 zombilik horde dalgaları |
| İnşa (ahşap, kırık taş) | Bitti: çerçeve, ahşap blok, kırık taş blok, merdiven; yükseltme, tamir, çökme, zombiler duvar kırar, kırılan bloktan 7DTD düşüşü |
| Hayatta kalma | Bitti: dayanıklılık, yemek, su, kademeler, koşma, zıplama, konserve / su / bandaj, gölden içme, ölüm torbası, HUD |
| Bina kapları | Bitti: 174 aranabilir mobilya, ortak, 7 günde yeniden dolar |
| Kazı | Bitti: 7DTD can ve verimi, kil / kırık kum / taş, adım kuralı, Dirt ile doldurma |
| Ahşap kapı | Bitti: 1000 can, aç/kapa, açıkken zombi geçer, kapalıyken duvar |
| Yakın dövüş silahları | Bitti: tahta sopa, taş mızrak; toplamada dörtte bir verim |
| Yay ve ok | Bitti: ilkel yay, taş ok, sunucuda yerçekimli uçuş |
| Boru tabanca | Bitti: 9 mm, şarjör 6, doldurma, sapma, atış gürültüsü; tutkal kamp ateşinde kemikten |
| Boru tüfek, pompalı, makineli ve nişan | Bitti: 7DTD 3.2 sayıları, pompalıda 10 saçma, makinelide basılı tutunca otomatik atış; nişan sağ tık / L2 / dokunmatik "Aim" |
| Tahta parmaklık | Bitti: 3 kereste, 300 can; zombiyi durdurur, mermi / ok / mızrak içinden geçer |
| Yatak rulosu | Bitti: 10 lif; kuran oyuncu ölünce üstünde doğar. Kayıt yok |
| Kırık taş kademesi | Bitti: ahşap blok + 10 kırık taş → 1500 can; kırık taş 1 kil + 1 taş. Beton kademesi (çimento karıştırıcı) yok |
| Tahta kazık tuzağı | Bitti: 20 odun; zombiye saniyede 33 hasar, hızını 0,18'e düşürür, 12 vuruşta kırılır |
| Mobilya kırma | Bitti: 30 tür kasaba mobilyası 7DTD canı ve düşüşleriyle kırılır; kap içindekini döker; pencere camı tek vuruşta kırılır |
| Tarım | Bitti: tarla, 3 ekin, büyüme, hasat, tohum geri |
| Jeneratör ve lamba | Bitti: benzin, aç/kapa, 48 stud'da 50 W, gürültü ve İz |
| Grafik ayarları | Bitti: Auto / Low / Medium / High, yalnızca istemci, gece görüşü sabit |
| Depolama sandığı | Bitti: 36 yuva, ortak, kırılınca torba |
| Evin içine inşaat | Bitti: zemin katta 2 hücre, kapı boşluğu barikatı |
| Kamp ateşi ve pişirme | Bitti: fırında patates, közde mısır (ızgara), kaynamış su (tencere); odun / odun kömürü yakar, çakmak ya da lifle yanar |
| Demirci ocağı ve demir | Bitti: odun kömürüyle yanan ocak, dövme demir, boru, tencere / ızgara; demir cevheri kayaları; demir balta, kazma, kürek |
| Vuruş animasyonları | Bitti: birinci şahısta kollar ve eldeki eşya, üç vuruş hareketi; üçüncü şahısta aynı hareketler |
| İlk dakikalar (1 Kasım kullanıcı testi) | Bitti: Tab / I / Bag düğmesi, oyuncu listesi kapalı, 7DTD başlangıç eşyaları, vuruş can çubuğu ve "Too far away", kontrol listesi (H), görev zinciri (19 görev), omuz kamerası (V, Alt), vuruş parçacıkları, ölüm ekranı ve torba işareti, otlu zeminden lif, eşya bilgi paneli (çanta ve crafting satırı) |
| UI cilası | **Sıradaki iş** (kullanıcı 31 Ekim: her iş bitince sıradakini kapat) |
| Kapı 1: 80 zombiyle orta seviye telefonda 30 FPS | **Ölçülmedi**; kullanıcı erteledi |
| Kapı 2: 3 kişilik test grubu "bir gece daha" diyor | Henüz yapılamaz |

## Kullanıcı kararı bekleyenler

Her sorunun ilk seçeneği benim önerim.

1. **Taş kazma ve kereste tarifleri:** 7DTD'de taş kazma yok (ilk kazma demirdir; demir kazma artık
   oyunda) ve kereste diye bir eşya yok. Kullanıcı istediği için ikisi de eklendi: taş kazma 4 taş /
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
6. **Sesler:** Oyunda hiç ses yok. Kancalar hazır: `Config.Ranged.Weapons.<silah>.SoundId` (atış:
   `PrimitiveBow`, `PipePistol`, `PipeRifle`, `PipeShotgun`, `PipeMachineGun`),
   `Config.ZombieVisual.GroanSoundId` (inleme). Creator Store'daki
   ücretsiz seslerin çoğu başka oyunlardan (COD, PvZ, CS:GO, Half-Life) koparılmış kullanıcı
   yüklemeleri; telif bildirimiyle silinebilirler. Roblox'un kendi yüklediği lisanslı ses kütüphanesi
   aramada çıkmadı. Öneri: sesleri sen dinleyip seç ya da kendi sesini yükle; kimliği
   (`rbxassetid://...`) ilgili alana yapıştırmak yeter. Ben tahmini bir ses seçmedim.

7. **Ateş tasarımı (bizim):** 7DTD'de çakmak yok, istasyon düğmeyle yanar; odun kömürü yok, kömür
   kazılır. Kullanıcının isteğiyle eklendi: yakmak için çakmak (50 kullanım, mutfak dolaplarında) ya da
   2 bitki lifi; kamp ateşinde 3 odun → 1 odun kömürü; demirci ocağı yalnızca odun kömürü yakar.
   Öneri: böyle kalsın; kömür kayası gelince odun kömürü ikinci kaynak olarak kalsın.
8. **Eksik malzemelerin yerine geçenler:** deri, koli bandı, kütük, ham demir ve tamir kiti yok.
   Demirci ocağında odun / kumaş / tutkal, demir aletlerde kumaş / tutkal, demir kayasında hurda
   demir, tamirde dövme demir kullanılıyor (PLAN, Kararlar). Öneri: hayvan ve av (deri) ya da tezgâh
   (tamir kiti, koli bandı) gelene kadar böyle kalsın.

Cevaplananlar: oyuncu zombiye aletle vuracak (bu planın 2. maddesi); zombiler üst kata çıkıyor
(bitti); kapsam kuralı değişti, ana referans 7DTD ve karşılığında bir şey çıkmıyor (PLAN, Kapsam).

## Sıradaki işler

Sıra kullanıcının isteğindeki sırayı izler. Her madde ayrı commit'lenir; her maddeden sonra kullanıcıya
tam test adımları yazılır.

### 1. Envanter (bitti, 31 Ekim)

`ec74896`, `383297a`, `859c573`. 7DTD boyutları: 10 slot alet kemeri, 45 slot (5×9) sırt çantası; odun,
küçük taş ve bitki lifi 6000'lik yığın. Kalanlar:
- Fare tekeriyle slot değiştirme: karar verildi (1 Kasım), tekerlek zoom'da kalır, slot 1–0 ile.
- 7DTD'nin taşıma yükü (fazla eşyada yavaşlama): sonra.
- Eşya simgeleri: renkli karenin üstünde emoji (`Shared/ItemIcons`, `7748aed`); gerçek simge çizimi
  sonraki görsel adım.

### 2. Vuruş (bitti, 31 Ekim)

`6be883f`, `1b0fb72`. Kalanlar (7DTD'de var):
- Güçlü vuruş (sağ tık): 2× veya 2,25× hasar, daha çok stamina.
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
- **İş istasyonları ve tarif kilitleri:** kamp ateşi ve demirci ocağı var (23. madde); tezgâh,
  kimya istasyonu ve kitap / perk kilidi yok.
- **Tahta sopa:** istenirse eklenecek tarif.
- **Dar ekran:** sırt çantası en küçük slotla 432 px, panel 340 px; 800 px'ten dar ekranda sığmaz.
  Telefon / kamera adımında mobil düzen.

### 5. Zombi loot'u (bitti, 31 Ekim)

`74caafe`, `8c39766`, `531edd1`. Kalanlar:
- **Torba penceresi:** 7DTD'de torba açılınca 18 slotluk pencere çıkar ve eşya tek tek alınır;
  bizde arama sığan her şeyi alır. Sandık / iş istasyonu arayüzüyle birlikte.
- **İçerik:** mermi ve kitap yok (silahlar gelince). Yiyecek, su ve bandaj eklendi.
- **Üst üste torbalar:** aynı noktada ölen zombilerin torbaları üst üste duruyor; prompt en
  yakınını seçiyor.
- **Bina loot'u:** bitti (`91a33a8`). Kalan: 7DTD'deki çöp kutusu, tuvalet, masa, dosya dolabı,
  kitaplık kapları (eşyaları yok); kap penceresi (eşyayı tek tek alma); kayıt.

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
- **Yığılma:** kovalama hâlinde hareketsiz kalan birkaç zombi görüldü (Chase, 0 stud/sn); duvar ya
  da merdiven kuyruğu olabilir, incelenmedi.

### 8. İnşa (bitti, 31 Ekim)

`c95e07a`, `7574e5f`, `123b9d8`. Kalanlar:
- **Kapı (bitti, 31 Ekim, `f84534b`):** kalanlar: kilit ve sahiplik yok (7DTD'de kilitli kapıyı
  yalnızca sahibi ve arkadaşları açar); açılma / kapanma sesi ve kırılma gürültüsü yok; demir kapı,
  kapak (hatch) ve garaj kapısı yok; kapı taş baltayla yükseltilmez.
- **Taş kademesi:** ahşap blok → kırık taş (10 Cobblestone, 1500 can); taş ocağı / betonarme
  zinciri gelince.
- **Şekiller:** yalnızca küp. 7DTD'de rampa, yarım blok, merdiven basamağı ve plaka var.
- **Yatay açıklık:** 7DTD'de ahşap 8 bloktan sonra çöker; bizde sınır yok.
- **Bina içi:** kasaba binalarının tabanına blok konamaz (üst kat yol bulma katmanı yapıyı bilmiyor).
- **Çerçeveyi geri alma:** 7DTD'de çerçeve toplanabilir; bizde yok.
- **Kazık tuzağı:** 20 odun, 33 hasar, 3 aşınma kademesi.
- **Zombinin üstteki oyuncuya ulaşması:** 2 blokluk sütunun tepesindeki oyuncunun altındaki sütunu
  zombiler ~20 sn'de kırdı (ölçüldü). Daha yüksek kule ve köprü ölçülmedi.
- **Kayıt:** bloklar sunucu kapanınca kaybolur (kalıcılık adımı).

### 9. Hayatta kalma (bitti, 31 Ekim)

`c46dd6a`, `3b49494`, `1d61b94`, `b74fe9c`. Kalanlar:
- **Yiyecek kaynağı:** zombi torbası (~30 zombide bir konserve) ve bina kapları (`91a33a8`). Av yok.
- **Kamp ateşi ve pişirme:** bulanık su → su (tencere), et, mısır; pişmiş yemeğin +10 maks
  dayanıklılık etkisi.
- **Dizanteri** (bulanık su ve göl %12), **kanama** (bandaj yalnızca onu durdurur), kırık bacak.
- **Yabani yiyecek:** yaban mersini, yucca, mısır bitkileri (her biri 2 yemek).
- **Ölüm torbası herkese açık;** sahibine özel değil.
- **Telefon:** HUD üst ortada, Run düğmesi Hit'in solunda; ikisi de ölçülmedi.

### 10. Kazılabilir zemin (bitti, 31 Ekim)

`499eb61`, `858d355`. Kalanlar:
- **Kil ne işe yarar:** şimdilik yalnızca Dirt. 7DTD'de kırık taş (1 kil + 1 taş) → taş blok
  kademesi ve demirci ocağı; taş kademesi gelince.
- **Çukur tuzağı:** zombiler yükseklik ızgarasını izlediği için çukura düşüp takılmaz, iner ve çıkar.
  7DTD'de çukur savunmadır (zombi tırmanmakta zorlanır). Yol bulma hücrelerine adım maliyeti
  eklenebilir.
- **Derinlik:** arazi tabanı −24; 0 yüksekliğindeki zemin 4 kat kazılır. Daha derin bodrum için taban
  indirilmeli (açılışta daha çok voksel yazılır; ölçülmeli).
- **Kayıt:** kazılan sütunlar sunucu kapanınca geri gelir (kalıcılık adımı).
- **Görsel:** kazı vuruşunda toz efekti ve ses yok; Dirt için hedef önizlemesi yok.
- **Kar:** 7DTD kartopu vermez bizde; kar boş kazılır.

### 11. Yakın dövüş silahları (bitti, 31 Ekim)

`114cc42`. Kalanlar:
- **Mızrak:** güçlü saldırı (3,6 m) ve fırlatma yok; tek "use" düğmesi var.
- **Kalite (1–6):** 7DTD'de dayanıklılık 100 → 200, hasar +%10 → +%50.
- **Sinsi saldırı:** 7DTD'de fark etmemiş zombiye çömelerek vuruş ×2 (bizde çömelme yok).
- **Görsel:** sopa ve mızrak da aletlerin sallama pozunu kullanıyor; mızrak dürtmesi yok.

### 12. Yay (bitti, 31 Ekim)

`e72be4b`. Kalanlar:
- **Germe:** 7DTD'de yay 0,5 sn gerilir, erken bırakılan ok zayıftır; bizde her atış tam gerili.
- **Yayılma ve nişan:** 7DTD'de kalçadan 2,8°, nişan alınca ×0,1; bizde yayılma yok, nişan imleçte.
- **Hasar düşüşü:** 7DTD'de 20 m'den sonra hasar azalır (eğrisi bilinmiyor); bizde 100 m'ye kadar
  tam hasar.
- **Ok toplama:** 7DTD'de saplanan ok kırılmadıysa geri alınır; bizde ok kaybolur.
- **Demir ok, ateşli ok, tatar yayı;** oklar bloğa hasar vermez (7DTD 1).
- **Tüy:** 7DTD'de kuş yuvasından; tüy kaynağı gelince ok tarifindeki lif tüye döner.
- **Sinsi atış:** fark etmemiş zombiye çömelerek ×3 (7DTD); bizde çömelme yok.

### 13. Tarım (bitti, 31 Ekim)

`6303735`. Kalanlar:
- **Pişirme:** 7DTD'de ürünler kamp ateşinde pişer (fırında patates, közde mısır); kamp ateşi yok,
  ürünler çiğ yenir (2 yemek).
- **Yabani ekin:** 7DTD'de doğada toplanabilir mısır / patates / yaban mersini var; bizde tohum
  yalnızca mutfak kaplarından.
- **Tarla tarifi:** 7DTD'nin çürük et (10) ve potasyum nitrat (25) malzemeleri yok; ikisi gelince tarife eklenir.
- **Perk:** Living off the Land yok; tohum hep geri gelir, bonus %50 sabit.
- **Işık ve su:** 7DTD'de ekin güneş ister; bizde çatı altında da büyür.
- **Kayıt:** ekinler sunucu kapanınca kaybolur.
- **Görsel:** ekin modelleri basit parçalar; aşama geçişinde efekt yok.

### 14. Jeneratör ve lamba (bitti, 31 Ekim)

`717d039`. Kalanlar:
- **Kablo:** 7DTD'de cihazlar kabloyla bağlanır, röle / anahtar / zamanlayıcı var; bizde yarıçap
  (PLAN: elektrik ağı "Sonrası").
- **Motor:** 7DTD'de jeneratör motorla 50 W'tan 300 W'a çıkar; bizde sabit 50 W (10 lamba).
- **Tarif:** 7DTD'de 15 dövme demir; ocak ve çalışma tezgâhı yok, yerine 50 hurda. Parçalar 15 / 21
  yerine 6 / 8 (tek kasaba). Ocak gelince dövme demire dönülür.
- **Ses:** jeneratör çalışırken ses efekti yok (gürültü yalnızca zombi ve tehdit için).
- **Gündüz kapatma:** otomatik değil; oyuncu kapatır (benzin tasarrufu bilinçli bir karar).
- **Başka tüketiciler:** taret, tuzak, spot ışığı yok.
- **Benzin kaynağı:** 7DTD'de arabalar ve benzin istasyonu; bizde depo kapları.
- **Kayıt:** jeneratör yakıtı ve durumu sunucu kapanınca kaybolur.

### 15. Grafik ayarları (bitti, 31 Ekim)

`767fdd2`. Kalanlar:
- **Kayıt:** seçim oturumluk; kalıcılık adımında oyuncu verisine yazılır.
- **Görüş mesafesi:** harita akışı (`StreamingTargetRadius` 384) sunucu genelinde; istemci başına
  ayarlanamaz. Ön ayar yalnızca zombi çizim mesafesini kısar.
- **Ot ve partikül:** `Terrain.Decoration` script'ten değişmiyor; partikül efekti henüz yok. Gelince
  ön ayara eklenir.
- **Telefon FPS testi:** Low'un telefonda yetip yetmediği ölçülmedi (kapı 1 hâlâ kullanıcıda).

### 16. Depolama sandığı ve arayüz (bitti, 31 Ekim)

`fdef2f5`, `e3f36c2`. Kalanlar:
- **Kilit:** 7DTD'de sandık kilitlenip şifrelenir; bizde herkes açar.
- **Sürükle bırak ve yarım yığın:** sandığa yalnızca bütün yığın gider; bölmek için önce çantada
  "Split".
- **Yükseltme:** 7DTD'de ahşap sandık demir / çeliğe yükseltilir; demir yok.
- **Sayılar:** 7DTD ahşap sandığın tarifi, canı ve yuva sayısı doğrulanamadı (bizim: 4 kereste,
  150 can, 36 yuva).
- **Kayıt:** sandık içeriği sunucu kapanınca kaybolur.
- **Simgeler:** emoji simgeler geldi (`7748aed`); gerçek çizim simgeler sonraki görsel adım.

### 17. Evin içine inşaat (bitti, 31 Ekim)

`4ed6ce1`. Kalanlar:
- **Üst kat (31 Ekim'de boyutlandırıldı, yapılmadı):** gereken değişiklikler: `structureCosts` kat
  başına (anahtar `cell + (level - 1) * cellCount`), `setStructure(level, ...)`; `structureCell` ve
  `moveToward` içindeki `here` zombinin katına göre; vuruş geri çağrısı katı da vermeli (şimdi
  `grid:cellCenter`); üst kat alan önbelleği (`upperFields`, `nav.topField`) yapı değişince boşalmalı;
  blok kalkınca üst hücre eski maliyetine dönmeli (üst ızgara için `reopenArea` yok); BuildService
  `updateColumn` üst kat yüksekliğini (`info.upperCells[1].Y`) kullanmalı; içeri kuralı ikinci bir
  bant ve istemci aynası; destek kontrolü üst döşemeyi zemin saymalı. Zombi yol bulmasına dokunduğu
  için ayrı ve dikkatli bir adım. Eski not: üst kat yol bulma ızgarası (`upperGrid`) blokları bilmiyor; üst kata blok konunca
  zombiler içinden geçerdi. Açmak için `ZombieService.setStructure` üst kat ızgarasına da yazmalı.
- **Pencereler:** pencere altındaki duvar (denizlik 4 stud) yol bulmada duvar sayılır; zombi
  pencereden girmez, bu yüzden pencereyi kapatmaya gerek yok. 7DTD'de
  zombiler pencere kırar; gelirse pencere de barikatlanabilir olmalı.
- **Binayı yıkmak:** harita parçaları (duvar, kapı kanadı) kırılmaz; mobilya artık kırılıyor (§21). 7DTD'de her blok
  kırılır; bizde binalar yüzlerce parça ve yol bulma ızgarası açılışta pişiriliyor. Ayrı adım.
- **Taban yüksekliği:** kural döşeme üstünün bir hücre tabanına 1,25 stud'dan yakın olmasına dayanır.
  Bugün tüm binalar 0 yüksekliğinde (döşeme üstü 1,0); yüksek arazide bina kurulursa zemin kat
  hücresi döşemeye çarpar ve blok konmaz. O durumda bina tabanı ızgaraya hizalanmalı.

### 18. Kamp ateşi ve pişirme (bitti, 31 Ekim)

`8b6e19d`. Kalanlar:
- **Yakıt:** 7DTD kamp ateşi pişirirken odun yakar; bizde yakıt yok. Yakıt yuvası gelirse pişirme
  odun ister.
- **İstasyonun kendi kuyruğu:** 7DTD'de iş kamp ateşinin içinde sürer ve ateş kırılınca içindekiler
  düşer; bizde iş oyuncunun kuyruğunda, istasyon yalnızca kuyruğa alırken aranır.
- **Isı ve tehdit:** 7DTD'de yanan ateş ısı haritasına 5 ekler (çığlıkçı çeker). Bizde ateş İz'e
  her blok gibi 0,04 ekler; ayrı gürültü yok.
- **Maks dayanıklılık bonusu:** pişmiş yemeğin +10 maks dayanıklılık etkisi yok.
- **Tarif kilitleri:** 7DTD'de fırında patates ve közde mısır dergiyle öğrenilir (`learnable`); bizde
  hepsi açık.
- **Et ve av:** hayvan yok, bu yüzden közlenmiş et / ızgara et yok.
- **Çalışma masası:** PLAN MVP parçası. Aynı istasyon altyapısıyla gelir (7DTD tarifi 25 dövme
  demir, 20 mekanik parça, 5 bant, 100 çivi, 100 odun; bizde demir, bant ve çivi yok).

### 19. Boru tabanca (bitti, 31 Ekim)

`7e1c6ed`, `fdde123`. Kalanlar:
- **Ses:** kanca hazır (`293bc96`): silahın `SoundId` alanı doluysa her istemci sesi namluda çalar
  (Play'de geçici bir motor sesiyle doğrulandı: 2 atışta 2 ses, 4 sn sonra temizlendi). Ses seçimi
  kullanıcıda (Kullanıcı kararı bekleyenler 6).
- **Nişan alma (bitti, `9868b76`):** sapma silahın 7DTD nişan payına iner, kamera yaklaşır. Kalan:
  7DTD'de yürürken / koşarken sapma artar, nişanda yürüme yavaşlar; bizde yok. Nişan dürbünü yok.
- **Hasar düşüşü:** 7DTD'de 12 m'den sonra hasar azalır; yok. XML yalnızca menzili veriyor, eğri motor
  kodunda; doğrulanmadan sayı uydurmamak için eklenmedi.
- **Sağ tık ve kamera:** nişan alırken (sağ tık basılı) varsayılan kameranın fareyle dönmeye devam
  ettiği elle doğrulanmalı (MCP ile ölçülemedi).
- **Görünmeyen istemler:** bir test oturumunda istemler görünmez oldu, yeniden üretilemedi (HANDOFF
  ölçümler). Görülürse ne yapıldığı not edilmeli.
- **Cephane yapımı:** 9 mm çalışma masasında kurşun ucu + barut + kovan ister; üçü de yok, cephane
  yalnızca loot.
- **Diğer boru silahlar (bitti, `9868b76`):** kalanlar: tüfeğin kafa hasarı +%25'i (bizde her silahta
  kafa ×2), hasar düşüşü (tüfek 50 m, makineli 34 m sonrası), makinelinin gerçek doldurma süresi (XML
  vermiyor, 3 sn bizim), 7,62 ve fişek yapımı (çalışma masası ister; cephane yalnızca loot).
- **Tamir:** 7DTD'de silah tamir kitiyle tamir edilir; tamir kiti yok.
- **Dayanıklılık:** 300 bizim; 7DTD'nin temel değeri doğrulanamadı.
- **Kemik:** 7DTD'de cesetten ve hayvandan; bizde zombi torbasında.

### 20. Tahta parmaklık (bitti, 31 Ekim)

`b39694a`. Kalanlar:
- **Görünüm:** kafesin görüntüsü bu gece beyaz gelen ekran görüntüsü yüzünden gözle doğrulanmadı.
- **İnce parmaklık:** 7DTD'de parmaklık ince bir bloktur; bizde tam 4 stud'luk hücre. Mızrak yine
  uzanıyor (7,3 stud), sopa ve balta uzanmayabilir.
- **Demir parmaklık:** PLAN'da sonraki aşama (dövme demir ve demirci ocağı ister).
- **Pencere:** PLAN MVP'deki pencere yok; parmaklık şimdilik pencere boşluğunun yerini tutar.
- **Loot torbası:** torba parmaklığın kutusunun üstüne düşer (diğer bloklar gibi).

### 20b. Tahta kazık (bitti, 31 Ekim)

`f7c47eb`. Kalanlar:
- **Oyuncuya hasar:** 7DTD'de kazık oyuncuyu da yaralar ve yavaşlatır; bizde yalnızca zombi (ortak
  oyunda kendi tuzağına basan oyuncu cezalanmasın diye; istenirse aynı kontrol karakterlere de uygulanır).
- **Yol bulma:** 7DTD'de kazığın `Path` değeri "solid": zombi yolu varsa etrafından dolaşır, yoksa
  üstünden geçer. Bizde her zaman üstünden geçer.
- **Vuruş sıklığı:** 7DTD'nin değme başına hasar sıklığı XML'de yok; saniyede bir bizim.
- **Kırılınca odun (bitti, `bd684fc`):** oyuncu kırarsa 2–6 odun; zombi kırarsa ya da aşınırsa yok.
- **Demir kazık:** 4 dövme demirle yükseltme (dövme demir yok).

### 20c. Kırık taş kademesi (bitti, 31 Ekim)

`8b79d1a`. Kalanlar:
- **Zombi yol maliyeti:** `BuildGrid.pathCost` 500 canda zaten tavana (`StructureCellCost` 8) vuruyor;
  ahşap blok, kapı ve kırık taş yol bulmada aynı pahalılıkta. Zombi sütundaki en zayıf bloğa vurur ama
  komşu sütunlardaki daha zayıf duvarı tercih etmez. Tavanı yükseltmek tüm yol bulmayı etkiler; ayrı adım.
- **Beton:** 10 beton karışımı + çimento karıştırıcı (istasyon yok).
- **Kırılınca düşüş (bitti, `bd684fc`):** oyuncunun kırdığı blok 7DTD düşüşünü verir; zombinin ya da
  aşınmanın kırdığı blok vermez (7DTD yere düşürür).

### 21. Mobilya kırma (bitti, 31 Ekim)

`7934fed`. Kalanlar:
- **İngiliz anahtarı:** 7DTD'de metal ve tesisat mobilyası anahtarla sökülünce ek "Harvest" verir
  (buzdolabı 1–2, klozet 5–10 hurda demir; lavabo boru, pirinç, kurşun; mikrodalga elektrik ve
  mekanik parça). Anahtar ve pirinç / kurşun yok; gelince `Harvest` listelerine eklenir.
- **Üst kat:** üst kattaki mobilya kırılınca üst kat yol ızgarası güncellenmez (hücre kapalı kalır;
  zombi boş yeri dolanır, zararsız). Üst kat inşaatıyla birlikte çözülmeli.
- **Kayıt:** kırılan mobilya kaydedilmez; `FurnitureCell` kimliği kayıt için hazır.
- **Görsel:** vuruşta mobilyada sarsılma / kıymık efekti yok; düşen eşya sağdaki akışta görünür.
- **Cam (`ea7e10b`):** mermi ve ok camı kırmaz (RangedService dünya vuruşunu toplama servisine
  iletmiyor); 7DTD'de kırar. Zombiler pencere kırıp girmez (denizlik duvar sayılır); 7DTD'de girer.
  Kırık camdan oyuncu atlayıp girebilir (denizlik 3 stud).

### 23. Kullanıcı testi sonrası: ateş, ocak, demir, animasyon (bitti, 1 Kasım)

Kullanıcının 1 Kasım bulguları: vuruş animasyonu yok, birinci şahıstan oynanmıyor, fare ortada
kilitli ve soldaki panele ulaşılmıyor, zombiye hasar verilemiyor, demir ve ateş yok, inşa yok.

- `08a1031`, `809479f`: nişangâhın altındaki zombiye isabet; vurulan zombinin canı çubukta. **Yalnızca
  sabit test kamerasıyla ölçüldü**; gerçek fareyle zombi vurmayı kullanıcı doğrulamalı.
- `64b7345`: debug panelinin üstünde "Tab ya da Alt basılı tut, tıkla" yazısı. Fare omuz modunda
  ortada kilitli; Alt basılıyken ya da çanta açıkken serbest kalır.
- `0617fa1`, `b7241b7`: birinci şahıs kollar ve vuruş animasyonları; üçüncü şahısta eklem
  `Transform`'una bindirilen vuruşlar (avatar eklemleri AnimationConstraint).
- `be63203`: crafting sekmeleri.
- `eef8033`: kamp ateşi yakıtı (R), yakma / söndürme (F), çakmak, lif, odun kömürü.
- `2549bc6`: demirci ocağı; dövme demir, metal boru, tencere, ızgara; jeneratör 15 dövme demir.
- `68256dc`: demir cevheri kayaları ve demir balta / kazma / kürek.
- İnşa zaten vardı: çantada Building sekmesi → çerçeve (Wood Frame) üret, toolbelt'e al, elde tutarken
  hayalet önizleme çıkar, sol tık koyar; çantada kereste varken taş baltayla vurmak ahşap bloğa
  yükseltir.

Kalanlar:
- **Ölüm:** kullanıcı denemedi.
- **Ses:** kullanıcı kararı (6. soru).
- **Ocak arayüzü:** 7DTD'de ocakta yakıt, girdi ve çıktı yuvaları var; bizde üç istem (E / R / F).
  Telefonda üç istem üst üste; dokunmatikte denenmedi.

### 24. Sıradaki 7DTD sistemleri

Kullanıcı "7DTD'nin bütün özelliklerini kapsamlı ve oynanabilir" istedi. Önerilen sıra (her biri ayrı
adım, PLAN'a karar satırıyla):
1. **Tezgâh (workbench):** 7DTD'de jeneratör, demir kapı ve ileri tarifler burada; tamir kiti ve koli
   bandı tarifleri.
2. **Meşale:** elde ışık ve duvara konan meşale (odun + lif + kömür), gece görünürlüğü.
3. **Kömür ve nitrat kayaları, yanık ağaç:** 7DTD'nin kömürü; barut ve cephane üretimine kapı.
4. **Kimya istasyonu ve barut / cephane üretimi.**
5. **Zırh ve giysi:** 7DTD'nin zırh kademeleri; yüzde hasar azaltma.
6. **Perk / beceri puanı ve tarif kitapları:** şimdilik bütün tarifler açık.
7. **Zombi türleri:** PLAN 2. aşama (Normal, Hızlı, Ses-duyarlı) ve 7DTD özel zombileri.
8. **Tüccar ve para:** 7DTD trader; PLAN gelir modeliyle çakışmaması gerekir, kullanıcıya sorulacak.
9. **Crafting araması** ve beton / demir inşa kademeleri.

### 22. Sonra

- **Araç zinciri:** Kullanıcı `rokit install` ve `rojo plugin install` komutlarını kendisi çalıştırır.
  Sonra `stylua --check src tests`, `selene src`, `lune run tests/run`, `rojo build -o build.rbxl`
  ilk kez çalıştırılır ve çıkan sorunlar düzeltilir.
- **Telefon FPS testi** (kullanıcı yapar):
  1. *File → Publish to Roblox*.
  2. Telefondan gir; debug paneli `Config.Debug.AllowedUserIds` içindeki hesapta görünür.
  3. Spawn 80 ve 120 için kasabada ve ormanda 30 sn sonra FPS ve tick oku.

  Tutmazsa sırayla: bina süs parçalarını birleştir, `StreamingTargetRadius` düşür, orman yoğunluğunu
  azalt, istemci `RenderDistance` kıs.
- **Kamera (yapıldı, 1 Kasım; kullanıcı doğrulaması bekliyor):** omuz / birinci şahıs / serbest fare,
  V ile. Omuz modunda fareyle bakış MCP ile ölçülemedi; kullanıcı testinde fare kamerayı döndürmüyorsa
  V ile serbest fareye geçilir ve `CameraController` düzeltilir. İnşa modunda yukarıdan görünüm yok.
  - Yumruğun 5,6 stud'luk menzili: otlu zemine ve yerdeki taşa vurmak için kamera ~40° aşağı bakmalı.
- **Prototip oyun testi:** 3 kişi, bir gece ve bir horde.

## 7DTD referans sayıları

Hepsi [REFERENCE_7DTD.md](REFERENCE_7DTD.md) dosyasında; başında bizim uyarlamalarımızın tablosu var.

## Sonra: 7DTD'den gelecekler

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
