# Zombi Survival — Roblox Oyun Planı

Oct 30, 2026 · @Esra

Konseptin özgün çekirdeği "ne kadar gelişirsen dünya o kadar tehlikeli olur" fikri; plan bunu merkeze alıp ilk sürümü 2 bölge, kalıcı özel dünyalar ve mobil uyumlu bir dikey dilimle sınırlıyor. Yazılı hâliyle konsept Seven Days to Die ölçeğinde ve Roblox'ta ilk sürüm olarak fazla büyük.

## Konsepte eleştirel bakış

Tehdit sistemi tek gerçek farklılaştırıcı; geri kalan her şey (bölgeler, gece, perk, crafting) türün standardı ve tek başına oyuncu çekmez. Bu yüzden tasarımın ve videoların merkezi tehdit olmalı.

**Güçlü olanlar**

- "Ne kadar gelişirsen o kadar tehlike" fikri risk/ödül kararını her dakikaya taşıyor: jeneratörü açmak bir karar olur, otomatik bir adım değil.
- Sınıfsız perk sistemi co-op'ta doğal rol dağılımı sağlıyor ve 1 kişiyle de oynanabiliyor.
- Bölge = loot tipi eşleşmesi (hastane → medikal) keşfe net bir neden veriyor.

**Riskli olanlar**

- **Ölçek.** 5 biyom, açık dünya, 5 kademeli inşa, hikaye ve gizli laboratuvarlar; profesyonel stüdyolarda yıllar alan kapsam. Roblox'ta ilk sürümün küçük çıkması ve sonra canlı güncellemeyle büyümesi gerekir.
- **Kitle uyumu.** Roblox kitlesinin çoğu genç ve mobilde. 7DTD'nin 60+ dakikalık döngüleri, derin crafting ağacı ve ilk 10 dakikadaki yavaşlık burada oyuncu kaybı demek. İlk 3 dakikada zombi öldürme + ilk duvarı dikme olmalı.
- **Zombi sayısı.** Roblox sunucusu yüzlerce Humanoid tabanlı NPC'yi kaldırmaz. "Horde Night" hissi sayıyla değil, tasarımla (dalgalar, yön, ses, özel zombiler) verilmeli.
- **Kalıcılık belirsiz.** Konsept dünyanın kime ait olduğunu ve kapatılınca ne olduğunu söylemiyor; Roblox sunucuları geçicidir. Bu mimariyi belirleyen en büyük karar (Temel kararlar).

**Eksik olanlar**

- Ölüm cezası (envanter düşer mi, ne kadarı?).
- Oturum yapısı: bir oyuncu 20 dakika oynayıp çıkarsa ne kazanır?
- Oyuncu üssündeyken dünyada ne oluyor (çevrimdışı saldırı var mı)?
- Teknoloji ilerleme çizgisi (hangi kaynak hangi teknolojiyi açıyor).
- Hikaye sadece "keşfet" seviyesinde; MVP için bu yeterli, ama somut bir son hedef (ör. karantina tesisindeki ilk boss) olmalı.

## Temel kararlar

En kritik karar dünya modeli: her grup kendi kalıcı dünyasına sahip olmalı (Minecraft Realms gibi), herkese açık ortak sunucu değil. Aşağıdaki tablo önerimdir; itiraz ettiğin satırı değiştir.

| Konu | Öneri | Neden | Alternatif ve bedeli |
| --- | --- | --- | --- |
| Dünya modeli | Grup başına kalıcı özel dünya (ReserveServer ile açılır, sahibinin kaydından yüklenir) | Üs inşasının anlamı kalıcılık; yabancı oyuncular üssü yıkamaz | Ortak sunucu: grief, kayıt çakışması, sahiplik sorunu |
| Lobi (public / private) | Private lobi: arkadaş grubu davet kodu/arkadaş listesiyle kendi kalıcı dünyasına girer. Public lobi: hızlı giriş, eşleşen geçici dünya; üs kalıcı değil, perk ve kozmetik profilde kalır. Lobi sahibi oyuncu atabilir. | Arkadaşı olmayan oyuncu hızlı girer; grup kendi üssünü yabancılardan korur | Public dünyaları da kalıcı yapmak: sahiplik, grief ve kayıt çakışması geri gelir |
| Oturum ritmi | 1 gün-gece döngüsü ≈ 10–12 dk; horde varsayılan her 7. gece, lobi sahibi yalnızca lobi kurulurken 5–10 arası seçer (dünya kaydında tutulur, sonradan değişmez) | 7 gece × 10–12 dk ≈ 70–85 dk'da ilk horde; uzun oturum ama ulaşılabilir | Uzun gün (15–20 dk) + 7. gece: ilk horde \~2 saat sonra, çoğu oyuncu görmeden çıkar |
| Cihaz | Önce mobil + PC, gamepad destekli; konsol sonra | Roblox trafiğinin büyük kısmı mobil | PC-öncelikli: daha zengin UI ama küçük pazar |
| Kamera | Oyun içinden değiştirilebilir: omuz kamerası (varsayılan), FPS, inşa modunda yukarıdan görünüm; zoom-out mesafesi sınırlı | Oyuncu tercihi; sınırsız zoom duvar arkasını gösterip gerilimi öldürür | Tek kamera: daha az test, ama oyuncu tercihine kapalı; her mod mobilde ayrı test ister |
| Grafik ayarları | Oyun içi menü: görüş mesafesi, gölgeler, partikül, ceset süresi, ışık kalitesi; Roblox'un kendi kalite ayarının üstüne. Düşük/Orta/Yüksek ön ayarları + cihaza göre otomatik seçim | Mobil ve zayıf PC'de 30 FPS. Ayarlar sadece istemciyi etkiler; zombi sayısı ve oynanış sunucuda aynı kalır | Sis/karanlığı kapatan ayar avantaj sağlar; gece görüşü ayardan bağımsız tutulmalı |
| Sanat stili | Stilize, low-poly, gerçekçi olmayan kan (yeşil/koyu "enfeksiyon" sıvısı) | Daha geniş yaş kitlesi ve mobil performans | Gerçekçi kan: daha dar kitle, moderasyon riski |
| Ölüm cezası | Taşınan ham kaynakların %50'si düşer, ekipman kalır; 5 dk içinde geri alınabilir | Risk/ödül hissi korunur, genç kitle için acımasız değil | Tam kayıp: hardcore oyuncu sever, çoğunluğu kaybeder |
| Çevrimdışı saldırı | Yok; dünya yalnızca sunucu açıkken ilerler | Kaybetme kaygısı olmadan geri dönme | Çevrimdışı simülasyon: teknik yük + adaletsizlik hissi |
| Dil (kod/içerik) | Kaynak dil İngilizce; Türkçe dahil çeviriler üstüne | Global kitle, Roblox otomatik çevirisi İngilizce kaynakla en iyi çalışır | Türkçe kaynak: çeviri kalitesi düşer |

## Tehdit sistemi

Tehdidi iki ayrı değere böl: anlık **Gürültü** (ne yaptığın) ve kalıcı **İz** (ne kurduğun). Tek bir değer kullanılırsa oyuncu ya hiç büyümemeyi öğrenir ya da sistemi görmezden gelir; ikiye bölmek "saklanma" ile "büyüme" arasındaki gerilimi okunur kılar.

**Bileşenler**

- **Gürültü (0–100, hızlı söner).** Silah sesi, patlama, kırılan kapı, koşma, çalışan jeneratör. Saniyede \~%5 söner. Duyma menzilindeki zombiler sesin geldiği noktaya yürür ve daha yüksek ya da daha yeni bir ses duyana kadar o hedefe ilerlemeye devam eder (The Walking Dead tarzı). Hedefe varınca bir süre etrafı arar, sonra dağılır; böylece sürü yemle başka yere çekilebilir.
- **İz (0–100, yavaş söner).** Üsün blok sayısı, aydınlatma, jeneratör gücü, açık ateş, depolanan yiyecek. Oyun günü başına ancak birkaç puan düşer. Gece saldırılarının büyüklüğünü ve horde'un hedefini belirler.
- **Tehdit Seviyesi = İz + Gürültünün bir kısmı**, 5 kademeye bölünür (Sessiz, Fark Edildi, Avlanıyor, Kuşatılmış, Hedef). Her kademe spawn hızını, özel zombi oranını ve horde boyutunu çarpanla artırır.

**Tasarım kuralları**

1. **Bilinir olmalı, bağırmamalı.** Ekranda kalıcı tehdit sayacı ve her olayda uyarı yok; gerçekçiliği bozar. Sistem ilk karşılaşmada bir kez açıklanır, parçanın İz etkisi yalnızca inşa modundaki yerleştirme önizlemesinde görünür. Geri kalan bilgi dünyadan gelir: uzaktan gelen inlemeler, ufukta toplanan sürü, karga sürüsü, telsiz anonsları.
2. **Karşı önlem olmalı.** Susturucu, perde/karartma, ses yalıtımlı jeneratör odası, şaşırtma (yemle sürüyü başka yere çekme). Engineer ve Builder perkleri bunları ucuzlatır.
3. **Büyümek değmeli.** Üst kademeler daha iyi loot taşıyan özel zombiler getirir; yüksek tehdit hem ceza hem fırsat olur.
4. **Kapı sabit.** Tehdit asla ilk 3 oyun gününde "Kuşatılmış"a çıkamaz; yeni oyuncu ezilmez.
5. **Grup boyutuyla ölçeklenir.** Horde boyutu oyuncu başına 20 zombidir (1 kişi: 20, 6 kişi: 120); tehdit kademesi sayıyı değil özel zombi oranını artırır, çünkü 1 ve 6 kişilik grup aynı üssü farklı hızda kurar.

Tüm katsayılar (sönme hızı, kademe eşikleri, çarpanlar) tek bir ModuleScript yapılandırmasında tutulmalı; dengeleme kod değişikliği gerektirmemeli. Yukarıdaki sayılar başlangıç tahminidir, playtest ile ayarlanır.

## Kapsam

MVP tek bir soruyu cevaplamalı: "Tehdit sistemi oyunculara tekrar döndürüyor mu?" Bunun dışındaki her şey ertelenir.

| Sistem | MVP (dikey dilim) | Sürüm 1.x | Sonrası |
| --- | --- | --- | --- |
| Bölgeler | Orman + Küçük Kasaba | Şehir, Endüstriyel | Askerî/Karantina |
| İnşa kademeleri | Tahta, Taş | Beton, Demir | Çelik (en sert ve dayanıklı) |
| İnşa parçaları | Duvar, kapı, pencere, zemin, merdiven, sandık, çalışma masası, tahta parmaklık | Jeneratör, ışık, tuzaklar, demir parmaklık ve çubuklar | Taret, elektrik ağı |
| Zombi türleri | Normal, Hızlı, Ses-duyarlı | Ağır/Zırhlı, Bölge özel | Boss enfekteler |
| Kaynaklar | Odun, Kereste, Küçük taş, Bitki lifi, Metal hurdası, Kumaş, Yiyecek, Medikal | Elektronik, Mekanik | Nadir askerî parçalar |
| Toplama ve arazi | Ağaç kesme, çalı ve ot, kaya kırma, yerden taş toplama, kazılabilir zemin | Maden damarları (demir, kömür) | Yapısal arazi çökmesi |
| Perkler | Scavenger, Builder, Combat (her biri 3 kademe) | Medic, Engineer | Perk sinerjileri |
| Gece/Horde | Gündüz-gece, horde varsayılan 7. gece (lobi kurulurken 5–10) | Hava olayları (sis = görüş azalır) | Mevsimsel etkinlikler |
| Tehdit | Gürültü + İz, 5 kademe, ortam ipuçları | Karşı önlem eşyaları | Bölge çapında dünya tehdidi |
| Multiplayer | 1–6 kişi, public hızlı giriş + private davet kodu, PvP lobi ayarı; 7–10 kişilik abonelikli sunucu 1.x'te | Public lobi filtreleri (dil, PvP, horde aralığı) | Dünyalar arası ticaret (dikkat: Roblox etiket kuralları) |
| Hikaye | Yok; ortam ipuçları (notlar) | Ana görev hattı, laboratuvar | Sezonluk gizem olayları (kaynak açıklanmaz) |
| Kayıt | Oyuncu profili + dünya kaydı | Dünya yedekleri | Dünya paylaşımı |

Kapsam kuralı (31 Ekim 2026'da kullanıcı kararıyla değişti; eski kural "bir giren, bir çıkar" idi):

- **Ana referans 7 Days to Die.** 7DTD'de olan bir sistem, bu plandaki özgün kararlarla çelişmediği sürece MVP'ye eklenebilir; karşılığında bir şey çıkarmak gerekmez.
- **Fark özgün kararlardan gelir.** Tehdit sistemi (Gürültü + İz), grup başına kalıcı dünya ve lobi, oturum ritmi, stilize sanat, ölüm cezası, çevrimdışı saldırının olmaması, gelir modeli ve mobil öncelik 7DTD'den ayrıldığı yerde bu plan geçerlidir.
- **Sayılar 7DTD'den alınır.** Roblox veya mobil için uyarlanan her sayı Config'de, gerekçesiyle birlikte Kararlar tablosunda yazılır. Araştırılan sayılar `docs/REFERENCE_7DTD.md` dosyasında tutulur.

## Teknik mimari

Sunucu otoriter, istemci yalnızca görüntüler: hasar, loot, inşa ve tehdit hesabı sunucuda yapılır. Roblox'ta exploit yaygın; istemciye güvenen her RemoteEvent bir açıktır.

**Zombi AI (en büyük performans riski)**

- Humanoid kullanma. Zombiler sunucuda sade veri (konum, durum, hedef, can) olarak tutulur; istemci modeli kendi çizer ve araya yumuşak geçiş (interpolation) uygular.
- Başlangıç bütçesi: sunucu başına aynı anda 60–80 aktif zombi, horde'da 120 tavan. Oyuncu başına 20 zombi formülü 6 kişide tam bu tavana denk geliyor; horde dalgalar hâlinde gelirse aynı anda sahnedeki sayı tavanın altında kalır. Bu sayılar tahmin; stres testiyle doğrulanır.
- Görüş alanı ve LOD: istemci yalnızca kamera görüş alanındaki ve yakındaki zombilerin modelini ve animasyonunu oynatır; görüş dışındakiler animasyonsuz kalır ama sesleri çalmaya devam eder, yoksa arkadan gelen saldırı sessiz olur. Sunucuda uzak zombiler daha seyrek güncellenir (ör. yakın 10 Hz, uzak 2 Hz).
- Yol bulma: PathfindingService pahalı; tek hedefe giden sürü için akış alanı (flow field) veya ortak yol + bireysel sapma kullan.
- Üsse saldırı: zombi en yakın en zayıf yapı parçasını hedefler; bu kural üs tasarımını anlamlı kılar.
- Binalar: zombiler kapılardan girip çıkar, merdivenle üst kata çıkar. Üst katlar ikinci bir yol bulma katmanıdır; merdivenler iki katmanı bağlar. Hiçbir kat güvenli sığınak değildir.

**İnşa sistemi**

- Izgara tabanlı (ör. 4 stud). Serbest yerleştirme yok; hem kayıt boyutu hem hile hem de zombi yol bulması için.
- Dünya başına parça tavanı (başlangıç: 2.000). Tavan aynı zamanda performans sınırı ve İz'in doğal üst sınırı.
- Yapısal bütünlük MVP'de yok; sadece parça canı ve kademe. Parmaklık ve demir çubuklar ayrı çarpışma grubunda: mermi raycast'i onları yok sayar, zombi geçemez ama vurarak hasar verir.

**Kayıt (DataStore)**

- Anahtar başına veri sınırı 4.194.304 karakter (≈ 4 MB). Bir dünyayı tek anahtarda tutmak mümkün, ama yapıları kompakt diz: parça başına `[tip, x, y, z, rot, can]`, tam CFrame değil.
- Ayrı depolar: `Player_v1` (perk, envanter), `World_v1` (yapılar, sandıklar, tehdit, gün), `WorldIndex_v1` (oyuncunun dünya listesi). Sürüm eki şema göçüne izin verir.
- Yazım: UpdateAsync ile, periyodik (her 2–3 dk) + sunucu kapanırken (BindToClose). Çakışma kontrolü için dünya kaydına sunucu kilidi (lease) ekle; aynı dünyanın iki sunucuda açılması veri kaybı demek.
- Throughput ve istek sınırları değişiyor; resmi belgede tüm sunucularda anahtar başına limitler tanımlı. Kayıt katmanı retry + backoff ve limit loglama içermeli.

**Diğer**

- StreamingEnabled açık; kasaba binaları Model olarak akışa uygun kurulur.
- Mobil hedef: orta seviye Android'de 30 FPS. Parça sayısı, ışık ve partikül bütçesi bu cihazda ölçülür.
- Kod yapısı: Rojo + Git (dosya tabanlı geliştirme, sürüm kontrolü), Luau `--!strict`, servis bazlı modüller (ThreatService, ZombieService, BuildService, SaveService, LootService).
- Analitik: Roblox'un kendi analitiği + özel olaylar (ilk duvar, ilk gece, ilk horde, ölüm nedeni). D1/D7 tutma bu olaylardan okunur.

## Gelir modeli

6 kişiye kadar oynamak tamamen ücretsiz; gelir kalabalık sunucu aboneliğinden, silahlardan ve kolaylık ürünlerinden gelir. Tüm ödemeler Robux. Pass ile abonelik aynı üründür: Roblox Game Pass tek seferlik olduğu için pass, aylık Robux aboneliği olarak kurulur. Pass'ten gelen silah ve kozmetikler abonelik bitince kaybolur; tek seferlik satın alınanlar kalıcıdır. Envanterde her eşya kaynağını (pass / satın alım / craft) taşır, böylece aynı eşya iki yoldan gelmişse abonelik bitince satın alınan kopya korunur.

| Ürün | Roblox türü | Abonelik pass'ine dahil mi | Kural |
| --- | --- | --- | --- |
| 6 kişiye kadar özel sunucu | Ücretsiz | — | Her oyuncuya |
| Karakter görünümleri | Ücretsiz | — | Hepsi oyun içinde açılır |
| Kalabalık sunucu (7+ kişi) | Abonelik (Robux, aylık) | Evet (pass'in kendisi) | Yalnızca lobi sahibi öder, diğerleri ücretsiz katılır. Abonelik biterse dünya silinmez, 6 kişi sınırı geri gelir |
| Silah kozmetiği | Developer Product | Evet | İstatistik değiştirmez |
| Standart silahlar | Developer Product | Evet | Hazır gelir, craft gerekmez; oyunda craft edilen silahlarla aynı güç seviyesinde |
| Ek dünya slotu | Developer Product | Evet | Ücretsiz oyuncuya 1 dünya |
| Özel güçlü silahlar | Developer Product | Hayır | Hazır gelir, craft gerekmez. Yalnızca zombilere hasar verir; PvP açıkken oyunculara ve yapılara hasar vermez. Ürün açıklamasında belirtilir, sunucudaki hasar fonksiyonunda zorunlu tutulur |
| Uçakla loot yardımı | Developer Product | Hayır | İçeriği satın almadan önce gösterilir ve sabittir. Düşüş yüksek Gürültü üretir, zombileri bölgeye çeker |
| Horde erteleme | Developer Product | Hayır | Aktif oyuncuların yarısından fazlası onaylarsa ödeme alınır; onay çıkmazsa ödeme yok |

**Teknik notlar**

- **Horde erteleme akışı:** oyuncu isteği başlatır → sunucu 30 sn oylama açar → aktif oyuncuların yarısından fazlası (başlatan dahil) onaylarsa ancak o zaman satın alma ekranı açılır. ProcessReceipt ertelemeyi tek sefer uygular (idempotent). Horde ödeme tamamlanmadan başladıysa erteleme bir sonraki horde'a geçer, para kaybolmaz.
- **Erteleme sınırı:** her horde döngüsünde en fazla 1 erteleme; yoksa ödeyen grup horde'u hiç görmez ve tehdit sistemi anlamsızlaşır.
- **Kalabalık sunucu:** bir place'in oyuncu üst sınırı sabittir. Bu yüzden 6 kişilik ve kalabalık dünyalar ayrı place'lerde çalışır, dünya kaydı ikisinde de açılır. Üst sınır önerisi 10 kişi.
- **Horde tavanı:** oyuncu başına 20 zombi 10 kişide 200 eder; 120 eş zamanlı tavanı aşılır. Kalabalık sunucuda horde dalgalara bölünür, toplam sayı korunur.
- **Abonelik doğrulaması:** lobi açılırken ve periyodik olarak sunucuda kontrol edilir; istemciye güvenilmez.

Kaçınılacaklar: ücretli rastgele kutu (Roblox'ta etiket ve bölgesel uyum sorunları doğurur, bazı ülkelerde yaş sınırı getirir), ücretli canlandırma. Uçakla loot yardımının içeriği bu yüzden sabit ve görünür; rastgele olursa ücretli rastgele öğe sayılır.

## Global yayın

Global olmak ilk günden üç şey demek: İngilizce kaynak metin, doğru içerik etiketi ve bölgesel uyum. Sonradan eklemek pahalıdır.

**Dil**

- Tüm UI metni tek bir yerelleştirme tablosundan gelsin; kodda sabit metin yok.
- MVP dilleri: İngilizce, İspanyolca, Portekizce (BR), Türkçe. Roblox otomatik çevirisi geri kalanı kapatır; oynanışı etkileyen metinler (tutorial, tehdit uyarıları) elle kontrol edilir.
- Metin yerine ikon: uzunluğu değişen çeviriler mobil UI'ı bozar.

**İçerik derecelendirmesi**

- Yayından önce Maturity & Compliance anketi doldurulmalı; eksik veya yanlış bilgi oyunun oynanabilirliğini platform genelinde kısıtlar.
- Etiketten bağımsız olarak yüklenen varlıklarda (mesh, görsel) gerçekçi veya aşırı şiddet ve kan moderasyona takılabilir; zombi tasarımları bu yüzden stilize olmalı.
- Anket sonucu bölgesel uyumsuzluk listesi de verir; oyun içinde ülkeye göre içerik kapatmak için PolicyService kullanılır (ör. satın alımlar).

## Yol haritası

Her aşama bir geçiş kriteriyle kapanır; kriter tutmazsa bir sonrakine geçilmez.

**Değişiklik (30 Ekim 2026, kullanıcı kararı):** 1. aşamanın telefon kapısı ertelendi. 2. aşamadan toplama, crafting ve zombi loot'u öne alındı; zombi davranışı ve görünümü bunlardan önce bitirildi. Güncel sıra NEXT_STEPS.md'de.

1. **Prototip.** Gri kutu harita, 1 zombi türü, tahta duvar, gündüz-gece, ilk tehdit hesabı.
   - Kapı: 80 zombiyle orta seviye telefonda 30 FPS; 3 kişilik test grubu "bir gece daha" diyor.
2. **Çekirdek döngü.** Loot, crafting, taş kademe, 3 zombi türü, horde gecesi, tehdit ipuçları ve karşı önlemler.
   - Kapı: test oyuncuları tehdidi bilerek yönetiyor (jeneratörü kapatıyor, perde çekiyor).
3. **Kalıcılık ve multiplayer.** Özel dünya, davet kodu, DataStore katmanı, sunucu kilidi, perkler.
   - Kapı: 50 kayıt/yükleme döngüsünde sıfır veri kaybı; aynı dünya iki sunucuda açılamıyor.
4. **Cilalama ve yerelleştirme.** Sanat geçişi, ses, tutorial (ilk 3 dakika), 4 dil, mobil kontroller, analitik olayları.
   - Kapı: yeni oyuncu yardımsız ilk duvarını 3 dakikada dikiyor.
5. **Kapalı beta ve yayın.** Maturity anketi, mağaza sayfası, 50–100 kişilik beta, sonra açık yayın.
   - Kapı: D1 tutma ≥ %20 (hedef; tür ortalaması için kendi verimizle güncellenecek).
6. **Canlı operasyon (yayın sonrası).** Düzenli güncellemeler: Şehir bölgesi, beton ve demir kademe, Medic/Engineer, sezon kartı.

## Riskler

| Risk | Olasılık | Etki | Önlem |
| --- | --- | --- | --- |
| Kapsam taşması (konseptin tamamını MVP'ye sokmak) | Yüksek | Proje bitmez | 7DTD referansıyla net hedef, sistem başına ayrı adım, commit ve ölçüm; özgün kararlar dışında yeni icat yok |
| Zombi sayısı performansı çökertiyor | Yüksek | Mobilde oynanamaz | Humanoid'siz AI, LOD, ilk iş olarak stres testi |
| Dünya kaydında veri kaybı | Orta | Oyuncu güveni biter | UpdateAsync, sunucu kilidi, sürümlü şema, yedek anahtar |
| Exploit ile loot/hasar hilesi | Yüksek | Ekonomi bozulur | Sunucu otoriter mantık, Remote doğrulama ve hız sınırı |
| PvP açık public lobide grief | Yüksek | Yeni oyuncu kaçar | Ayrı eşleştirme havuzu, lobi sahibinin oyuncu atması, PvP durumunun girişte görünmesi |
| Yanlış içerik etiketi | Orta | Oyun kısıtlanır | Stilize kan, ankete dürüst cevap |
| İlk dakikaların yavaşlığı | Yüksek | D1 tutma düşer | 3 dakikalık tutorial hedefi, analitikle ölçüm |

## Kararlar

Lobi, PvP ve hikâye için verilmiş kararlar.

| Konu | Karar | Tasarıma etkisi |
| --- | --- | --- |
| Lobi | Public (hızlı giriş) ve private (davetli) ikisi de MVP'de | Temel kararlar tablosundaki Lobi satırı geçerli |
| Salgının kaynağı | Bilinmeyecek | Hikaye cevap değil gizem üretir; notlar çelişkili ipuçları verir |
| PvP | Var; lobi kurulurken açılır/kapanır. Açıkken oyuncular ve yapılar hasar alır | Public hızlı giriş PvP açık ve kapalı lobileri ayrı havuzda eşleştirir; lobi listesinde PvP durumu görünür. Yapı hasarı sunucuda doğrulanır ve kayıtla tutarlı kalır |
| Ses takibi | Zombiler yeni ses duyana kadar ilk yüksek sese ilerler | Tehdit sistemi, Gürültü |
| Horde | Varsayılan 7. gece; lobi kurulurken 5–10; oyuncu başına 20 zombi | Temel kararlar ve Teknik mimari |
| İnşa kademeleri | Tahta → Taş → Beton → Demir → Çelik (en dayanıklı) | Kapsam |
| Zombi hareketi | Horde dışı zombiler yavaş ve sarsılarak yürür (The Walking Dead); kollarını öne uzatarak saldırır | Yürüyen oyuncu kaçabilir; tehlike sayıdan ve sıkışmaktan gelir. Hızlar Config'de |
| Zombiler ve binalar | Zombiler evlere girip çıkar ve merdivenle üst kata çıkar. Spawn'ların düşük bir kısmı (varsayılan %10) bina içinde uyuyan zombidir | Üst kat güvenli sığınak değil. Uyuyan zombi görünce, duyunca ya da çarpılınca uyanır |
| Zombi görünümü | Zayıf, çürümüş yüz ve görünen deri; stilize, kan yok. Ten dağılımı küçük bir ABD kasabası gibi: %70 açık, %16 buğday, %14 koyu/siyah | Sanat stili satırıyla uyumlu. Oranlar Config'den ayarlanır |
| Zombi loot'u | Ölen zombi yaklaşık %20 ihtimalle loot torbası bırakır. İçerik şimdilik bir ortak seçim (hurda demir, kumaş veya küçük taş) ve %15 ihtimalle aşınmış taş alet; torba 18 slot, 20 dk ömür, 1 sn arama (7DTD). Envantere sığmayan eşya oyuncunun ayağına torba olarak düşer | 7DTD'de %2–4; oturumlar kısa olduğu için daha cömert. Oran ve tablo Config'de |
| Toplama ve crafting | 7DTD referans alınır. Oyuncu boş elle başlar: ağaca vurur, yerden taş toplar. Ağaç Odun verir; Kereste envanterde Odun'dan yapılır ve inşa parçalarında kullanılır. Çalı ve ot bitki lifi verir. Taş balta ve taş kürek 7DTD tarifleriyle; 7DTD'de olmayan taş kazma kullanıcının isteğiyle eklendi | Kaynaklar satırı. Tarifler `Config.Recipes`'te |
| Kaya yerleşimi | Kasaba ve şehir bölgelerinde kırılabilir kaya ve toplanabilir taş yok | Harita |
| Kazılabilir zemin | Var, 7DTD gibi | Yeni kapsam kuralıyla MVP'de; karşılığında bir şey çıkmadı |
| Telefon kapısı | Ertelendi; yeni sistemlere geçilebilir | Yol haritası notu |
| Vuruş | 7DTD sayıları: yumruk 5, taş balta 6, taş kürek 9 hasar; kafaya ×2; vuruşlar arası 60/APM + 0,1 sn; zombi 125 ±%15 can, 1,5 sn'de 8 vurur. 7DTD metresi 2,8 stud sayılır | Hedefi sunucu seçer (zombi başına silindir + öne eğik kafa küresi, duvar kontrolü). PvP lobi seçeneği gelince oyuncuya vuruş eklenir; şimdilik oyuncular vurulmaz |
| Taş kazma istatistikleri | 7 varlık / 26 blok hasarı, 70 vuruş/dk, 2,4 m, 250 dayanıklılık | 7DTD'de karşılığı yok; taş balta ile demir kazma arasına kondu |
| Crafting kuyruğu | 7DTD sırt çantası crafting'i: 4 iş, yalnızca ilki ilerler, malzeme kuyruğa alınırken düşer, iptal kalanı iade eder; taş aletler küçük taşla aynı kuyrukta tamir edilir. Taş kazma 4 taş / 3 lif / 3 odun, kereste 2 odun (bizim tariflerimiz). Sığmayan ürün kuyrukta bekler; iadesi sığmayan iptal, loot torbası gelene kadar reddedilir | Hiçbir eşya kaybolmaz. Kuyruk kayıt adımına kadar oyuncu çıkınca kaybolur. Tamir edilen alet boşsa eski slotuna döner |
| Gündüz-gece | 11 dk döngü, %60 gündüz (06:00–18:30), uzun gece; dünya 1. gün 08:00'de başlar. Horde gecesi horde gününün bütün gecesidir (7DTD 22:00–04:00; bizim gece zaten kısa). Gece zombiler 1,1 sn'de vurur (7DTD), ama horde dışı zombiler gece de yavaş kalır (7DTD gece koşar) | Zombi hareketi satırı 7DTD'nin gece koşusunu geçersiz kılar; gece tehlikesi sayıdan ve saldırı sıklığından gelir |
| Horde boyutu ve dalgalar | Horde oyuncu başına toplam 20 zombidir; gecenin ilk %60'ına yayılan 4 dalgada gelir. Tehdit kademesi horde sayısını değiştirmez (tasarım kuralı 5, "her kademe horde boyutunu artırır" cümlesinden daha özel). Horde zombileri görmeden en yakın oyuncuyu bulur ve 11 stud/sn koşar (7DTD'nin "jog" ayarı; varsayılan sprint yürüyen oyuncuyu geçer). Horde gecesinde ortam spawn'ı durur (7DTD) | 7DTD'de blood moon'un büyüklüğü gamestage'e göre artar ve 04:00'e kadar sürer; burada toplam oyuncu başına sabit (Teknik mimari, Horde tavanı). Dalgalar gecenin sonuna kadar baskı bırakır |
| Ortam nüfusu | Canlı oyuncu başına gündüz 6, gece 10 zombi; kademe çarpanı 1 / 1,15 / 1,3 / 1,45 / 1,6; sunucuda en fazla 80. Oyuncudan 270 stud'dan uzak boştaki zombi silinir, yenisi oyuncunun yakınında doğar | Bütçe 60–80 (Teknik mimari). 7DTD biyom spawn'ının karşılığı; kademe "spawn hızını" artırır |
| Toplama gürültüsü | Ağaca ve kayaya vuruş 1,5 gürültü / 35 stud ses, devrilen ağaç 6 / 70 stud; ot ve çalı sessiz | 7DTD'de kesmek ve kazmak ısı haritasını artırır. Ağaç kesen oyuncu yakındaki zombileri çeker |
| İnşa | 7DTD bloğu: 4 stud'luk küp, çerçeve (100 can, 1 kereste) taş baltayla 3 vuruşta ahşap bloğa (500 can, +4 kereste) döner; tamir odunla. Taş balta bloğa hasar vermez, yalnızca yükseltir ve tamir eder (7DTD'de ikinci eylem; bizde tek "use" düğmesi var). Yerleştirme 24 stud. Kasaba binalarına yalnızca zemin katta, kattan 2 hücreye kadar blok konur (kapı boşluğu barikatı). Yere bağlantısı kopan bloklar düşer; 7DTD'nin 8 blokluk yatay sınırı yok | Mobilde tek düğme. Zombi en zayıf duvarı yol maliyetiyle seçer (Teknik mimari, üsse saldırı) |
| Hayatta kalma zamanı | 7DTD'nin oyun günü başına sayıları korunur: yemek günde 30, su 40 düşer, doğal can günde 60 dolar (bizim 11 dk'lık günümüzde). Dayanıklılık (10/sn, koşu −4,5/sn, zıplama 20) ve açlık hasarı (2,2 sn'de 0,25) gerçek saniyeyle | 7DTD bu sayıları varsayılan 60 dk'lık güne göre koyar; gerçek saate bağlarsak yemek bizde 5 gün sürer ve hiçbir şey ifade etmez |
| Yeniden doğuş | İstatistikler dolu doğar (7DTD varsayılanı "XP Only"). Ceza PLAN'daki gibi: taşınan ham kaynakların (odun, küçük taş, lif, hurda demir, kumaş) yarısı 5 dk'lık torbaya düşer; kereste, blok, yiyecek ve aletler kalır | Ölüm cezası satırı; XP borcu yok çünkü XP yok |
| Koşma | Yürüme Roblox varsayılanı 16 stud/sn, koşma 24 (7DTD m/s vermez). Shift basılı, gamepad L3 ve dokunmatik Run aç/kapa. 0'da biten koşu 25 dayanıklılıkta yeniden başlar (bizim; titremesin diye) | Horde 11 stud/sn: yürüyen oyuncu açık arazide kaçabilir |
| Yeme, içme, gölden içme | Tek "use" düğmesi: elde yiyecek / içecek / bandaj varsa kullanılır, boş el göl suyuna bakıyorsa içer (7DTD'de el "Drink"), yoksa yumruk | Mobilde tek düğme |
| Bina kapları | Kasaba mobilyası (buzdolabı, dolap, raf, gardırop, ilaç dolabı, depo) aranır; ilk aramada dolar, 7 oyun günü sonra yeniden (7DTD LootRespawnDays), bütün oyunculara ortak. Yiyecek ekonomisi bizim: 7DTD dolapları çoğunlukla çöp verir; burada ~90 yemek kabının her biri ortalama ~0,5 konserve ve ~0,5 su verir, 3 kişilik grup günde ~12 kap arayarak doyar ve kasaba yaklaşık bir haftada (yeniden dolma süresi) tükenir | Oturum ritmi kısa; zombi torbası tek başına doyurmaz (~30 zombide bir konserve) |
| Yakın dövüş silahları | 7DTD tahta sopa ve taş mızrak sayılarıyla (12 hasar, 55 vuruş/dk, 100 dayanıklılık). Silahlar toplamada odun, taş, kil ve kumun dörtte birini verir, lifin tamamını (7DTD 2.6+; 1.x'te lif de dörtte birdi). Mızrağın yalnızca hafif saldırısı var. Sopa odunla tamir edilir (birim başına 0,5 sn bizim; 7DTD süre vermez). İkisi de zombi torbasından çıkabilir | Tek "use" düğmesi (mobil); güçlü saldırı ve fırlatma ikinci bir eylem ister |
| Boru tabanca | 7DTD 3.2 sayılarıyla: 4 metal boru + 2 tutkal + 6 odun, dakikada 126 atış, 6'lık şarjör, ~2 sn doldurma, 9 mm 32 − 4 = 28 hasar, 40 m, 1,5° sapma. Mermi hitscan değil 250 m/sn düşüşsüz uçar (yayın sunucu uçuşu). Her atış "Gunshot" gürültüsü. Tutkal kamp ateşinde tencereyle 7 kemik + kaynamış sudan; kemik zombi torbasından. Cephane yalnızca loot | PLAN gürültü kaynağı "silah sesi" böylece oyuna girdi: tabanca güçlü ama sürüyü çağırır. Nişan alma ve hasar düşüşü mobil kontrol adımına kaldı |
| Eşya simgeleri | Gerçek simge çizilene kadar her eşyada renkli karenin üstünde bir emoji | Görsel yüklemeden her cihazda okunur; Roblox Unicode 12'ye kadar emoji çizdiği için yeni emojiler (kütük, kaya) yerine eskileri kullanıldı |
| Boru tüfek, pompalı, makineli, nişan | 7DTD 3.2 sayılarıyla, tarifler tabancayla aynı. Pompalı fişeği 10 ayrı saçma uçurur. Nişan alma sapmayı 7DTD `SpreadMultiplierAiming` payına indirir, kamera FOV 50'ye yaklaşır; telefonda Vur düğmesinin üstünde "Aim" anahtarı. Makinelinin doldurma süresi XML'de yok, 3 sn bizim; cephane yalnızca loot | Kullanıcının "silahlar" maddesi. Nişanın sunucuda sapma olarak işlemesi otoriter kuralı korur: istemci yalnızca "nişan alıyorum" der |
| Pencere camı | Kasaba camları tek vuruşta kırılır (7DTD Mglass 1 can), düşüş yok. Zombi yolu değişmez | "Evler yıkılabilir" isteğinin küçük bir parçası; zombilerin pencereden girmesi yol bulma değişikliği ister, ayrı adım |
| Mobilya kırma | Kasaba mobilyası (şömine hariç) 7DTD 3.2 blok malzemesi canıyla kırılır, eşleşen 7DTD bloğunun kırılma düşüşünü verir; kap içindekini torbaya döker. Anahtara bağlı "salvage" düşüşleri anahtar gelene kadar yok. Metal için taş çarpanı. Yatak / kanepe kumaşı bizim | "Evler özelleştirilebilir" isteği ve 7DTD'nin "her şey kırılır, kırılan şey malzeme verir" döngüsü. Binanın duvarları ayrı ve büyük adım; mobilya mevcut toplama sistemiyle küçük bir adım |
| Blok düşüşleri | 7DTD bloklarının Harvest düşüşü alet vuruşlarına bölünür, Destroy düşüşü kırana gider. Zombinin ya da aşınmanın kırdığı blok bir şey vermez (7DTD yere düşürür; torba kalabalığı yapmasın diye bizim) | Yanlış konan bloğu geri almanın 7DTD yolu; tamir maliyeti düşüşten büyük olduğu için tamir-kır döngüsü kazanç vermez |
| Kırık taş kademesi | 7DTD sayılarıyla: ahşap blok + 10 kırık taş (taş baltayla 3 vuruş) → 1500 can, tamir 8 kırık taş; kırık taş 1 kil + 1 küçük taş. Blok aletlere taş gibi davranır (kazma daha iyi) | Kullanıcının "base inşası" maddesi: horde gecesi için ahşabın üstünde bir kademe. Malzemeler (kazı kili, yer taşı) zaten oyunda |
| Tahta kazık tuzağı | 7DTD sayıları: 20 odun, 33 hasar, 0,18 hız, 12 vuruşta kırılır (üç aşama × 4). Çarpışmasız; zombi her zaman üstünden yürür. Saniyede bir vuruş ve oyuncuya hasar vermemesi bizim | Kullanıcının "base inşası" maddesinin eksik parçası (tuzak). 7DTD'de oyuncu da yaralanır; ortak oyunda kendi tuzağına basan oyuncuyu cezalandırmamak için şimdilik yalnızca zombi |
| Tahta parmaklık | 3 kereste, 300 can, tamir 3 odun (bizim sayılar: çerçeve ile ahşap blok arası). Hücre görünmez kutu + dekor kafes; kutu ayrı çarpışma grubunda: zombi geçemez ve kırar, mermi / ok / zombi görüşü / yakın dövüş içinden geçer | PLAN MVP "tahta parmaklık" ve "parmaklıklar ayrı çarpışma grubunda" kararı. 7DTD'de yalnızca dövme demir parmaklık var; o sonraki aşama |
| Kamp ateşi ve pişirme | 7DTD 3.2: kamp ateşi 5 küçük taş, 100 can. Fırında patates 10 sn, közde mısır 5 sn (ızgara), kaynamış su 10 sn (tencere, bulanık sudan); pişmiş yemek 10 yemek, 5 can, −5 su. Tencere ve ızgara mutfak dolaplarından. İstasyon yalnızca kuyruğa alırken 10 stud içinde aranır, iş oyuncunun kuyruğunda sürer. Yakıt yok | Mevcut kuyruk ve panel yeniden kullanıldı (tek düğme, dokunmatik uyumlu). 7DTD'de iş ateşin içinde sürer ve ateş odun yakar; ikisi ayrı adım. Dövme demir ve demirci ocağı olmadığı için tencere / ızgara yalnızca loot |
| Evin içine inşaat | Kasaba binasının zemin katına blok, kapı, sandık konur; kattan en fazla 2 hücre (kapı boşluğu 8 stud). Blok altındaki döşemeye ya da bordüre 1,25 stud'a kadar gömülebilir. Üst kata konmaz | 7DTD'de her POI üs olur. Üst kat yol bulma katmanı blokları bilmiyor; zemin kat barikatı zombiyi zaten durdurur (ölçüldü). Binanın kendisini yıkmak ayrı adım |
| Depolama sandığı | MVP "sandık": 4 kereste, 7 sn, 150 can, 36 yuva, herkesin açabildiği ortak sandık; kırılınca içindekiler torbaya düşer. Arayüz: crafting panelinin yerinde; yuvaya tıkla al, çantadan seç ve tıkla koy | 7DTD sayıları doğrulanamadı; kilit sahiplik sistemiyle gelir. Tıkla-al / seç-koy düzeni mevcut çanta düzeniyle aynı ve dokunmatikte de çalışır |
| Grafik ön ayarları | Low / Medium / High + Auto; değişenler zombi çizim, ayrıntı ve animasyon mesafesi, ceset süresi, güneş gölgesi, bloom, güneş ışınları, lamba ışığı erimi. Sis, atmosfer, gökyüzü, gece tonu ve DepthOfField ön ayarda yok. Auto: dokunmatik + klavyesiz cihaz Low, öbürleri Roblox kalitesine göre. Medium eski görünüm. Zombi çizim mesafesi en çok 260 (despawn mesafesi) | PLAN satırı (görüş mesafesi, gölge, partikül, ceset süresi, ışık kalitesi): partikül yok, ot ve harita akışı script'le değişmiyor; risk satırı gereği gece görünürlüğünü değiştiren hiçbir şey ayarda değil; DoF uzaktaki zombiyi bulanıklaştırdığı için dışarıda |
| Jeneratör ve lamba | 7DTD jeneratör bankası (motor başı 50 W, 1000 benzin, 1,8 benzin / watt / gerçek saat) kablosuz: çalışan jeneratör 48 stud içindeki lambaları 50 W'a kadar yakar, her lamba bir jeneratörden. Saat oranı tarımdaki gibi oyun gününe ölçeklenir (5 W lamba günde 9 benzin). Tarif 50 hurda + 6 mekanik + 8 elektrik parçası (7DTD: 15 dövme demir + 15 + 21, tezgâhta); lamba 4 hurda + 2 elektrik parçası (bizim). Benzin ve parçalar depo kaplarında. Jeneratör açıkken 3 sn'de bir gürültü (Noise ≈ 21, tek ses noktası), İz: lamba 1,5, jeneratör 3. Benzin elde "use" ile dökülür, tek istem aç/kapa | PLAN "jeneratörü açmak bir karar": ses zombileri çeker, benzin kıt (bir depo taraması dört lambayı ~3,5 gün yakar); elektrik ağı "Sonrası" olduğu için kablo yerine yarıçap; ocak ve tezgâh yok, tek kasabada 7DTD parça sayısı ulaşılamaz; mobilde iki istem kalabalık |
| Tarım | 7DTD 3.2: tohum yalnızca tarlaya ekilir, ekin 3 aşamalı, aşama 63 dk / 60 dk'lık gün = 1,05 oyun günü (≈ 23 dk'da olgun), oyuncunun ekini 2 ürün + %50 bir daha verir, 5 ürün = 1 tohum. Perk olmadığı için tohum hasatta hep geri gelir (7DTD'de Living off the Land 3). Tarla 4 odun + 100 kil (7DTD'deki çürük et ve nitrat bizde yok), 250 can, kimseyi engellemeyen yassı blok. Mısır, patates, yaban mersini; tohumlar mutfak kaplarında | Perksiz 7DTD tarımı tohum açığı verir (2,5 ürün / tohum, tohum 5 ürün); oyun günü ölçeği hayatta kalma sayılarıyla aynı |
| Yay ve ok | 7DTD ilkel yay ve taş ok sayılarıyla (30 hasar, 31,5 m/sn, 100 m, 100 dayanıklılık). Ok tarifinde tüy yerine bitki lifi (1 taş + 1 odun + 1 lif): tüy veren kuş yuvası yok ve yay toplayarak yapılabilmeli. Germe ve yayılma yok, her atış tam gerili ve imlecin gösterdiği yöne; atış aralığı 1 sn (bizim; 7DTD'de germe süresi + ok takma). Ok 7DTD'nin "Gravity −4" değerini 4 m/sn² sayar (bizim okuma). Ok yalnızca zombiye hasar verir, sessizdir, geri alınmaz. Vurulan zombi atanı kovalar | Tek "use" düğmesi (mobil); Gürültü kaynakları listesinde yay yok |
| Kapı | 7DTD ahşap kapı: 1000 can, iki hücre, etkileşim tuşuyla aç / kapa; tarif 5 kereste (7DTD 10 odun = 5 kereste), tamir 5 odun. Kuranın durduğu yüze asılır, kendi hücresine açılır. Açıkken zombi geçer; kapalıyken duvardır; zombi kapı açmaz. Aralıkta biri varken kapanmaz. Kilit yok | İnşa parçaları kereste ister (Toplama ve crafting satırı); kilit sahiplik ve parti sistemi ister, o gelince |
| Kazı | Bir kazı 4 stud'luk sütunun tepesinden bir voksel alır (7DTD bloğu 1 m, bizimki 1,4 m), 7DTD can ve verimiyle. Tünel yok: yalnızca sütun tepesi kazılır. Bir sütun yan komşusundan en çok 2 voksel aşağı iner; derin çukur geniş kazılır. Yol, kaldırım, bina ayak izi + 4 stud, su ve çevresi, ağaç / eşya / blok altı ve en alttaki voksel kazılmaz. Dirt (16 kil) yalnızca kazılmış yeri eski yüksekliğine kadar doldurur (7DTD'de her yere konur). Zombiler çukura iner ve çıkar | Roblox arazisi 4 stud'dan dar ve iki vokselden dik çukuru yuvarlayıp kapatıyor (ölçüldü); tünel ve keyfi toprak kulesi aynı nedenle görünmez ve takılma yaratır; yol bulma şimdilik değişmez |
| Sırt çantası tuşu | I (gamepad Y, mobilde Bag); Tab değil | Roblox oyuncu listesi Tab'ı oyundan önce alıyor (Play'de denendi) |

## Kaynaklar

- [Roblox — Data store error codes and limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits.md)
- [Roblox — Content maturity and compliance](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)
- [Roblox — Content Maturity (etiket tanımları)](https://create.roblox.com/docs/production/promotion/content-maturity)
- [Roblox DevForum — Subscriptions in Robux](https://devforum.roblox.com/t/let-your-players-pay-for-subscriptions-within-experiences-in-robux/4552995)
