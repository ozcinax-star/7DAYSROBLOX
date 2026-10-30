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
| Kaynaklar | Odun, Taş, Metal hurdası, Kumaş, Yiyecek, Medikal | Elektronik, Mekanik | Nadir askerî parçalar |
| Perkler | Scavenger, Builder, Combat (her biri 3 kademe) | Medic, Engineer | Perk sinerjileri |
| Gece/Horde | Gündüz-gece, horde varsayılan 7. gece (lobi kurulurken 5–10) | Hava olayları (sis = görüş azalır) | Mevsimsel etkinlikler |
| Tehdit | Gürültü + İz, 5 kademe, ortam ipuçları | Karşı önlem eşyaları | Bölge çapında dünya tehdidi |
| Multiplayer | 1–6 kişi, public hızlı giriş + private davet kodu, PvP lobi ayarı; 7–10 kişilik abonelikli sunucu 1.x'te | Public lobi filtreleri (dil, PvP, horde aralığı) | Dünyalar arası ticaret (dikkat: Roblox etiket kuralları) |
| Hikaye | Yok; ortam ipuçları (notlar) | Ana görev hattı, laboratuvar | Sezonluk gizem olayları (kaynak açıklanmaz) |
| Kayıt | Oyuncu profili + dünya kaydı | Dünya yedekleri | Dünya paylaşımı |

Kapsam kuralı: yeni bir sistem MVP'ye ancak bir mevcut sistemi çıkararak girebilir.

## Teknik mimari

Sunucu otoriter, istemci yalnızca görüntüler: hasar, loot, inşa ve tehdit hesabı sunucuda yapılır. Roblox'ta exploit yaygın; istemciye güvenen her RemoteEvent bir açıktır.

**Zombi AI (en büyük performans riski)**

- Humanoid kullanma. Zombiler sunucuda sade veri (konum, durum, hedef, can) olarak tutulur; istemci modeli kendi çizer ve araya yumuşak geçiş (interpolation) uygular.
- Başlangıç bütçesi: sunucu başına aynı anda 60–80 aktif zombi, horde'da 120 tavan. Oyuncu başına 20 zombi formülü 6 kişide tam bu tavana denk geliyor; horde dalgalar hâlinde gelirse aynı anda sahnedeki sayı tavanın altında kalır. Bu sayılar tahmin; stres testiyle doğrulanır.
- Görüş alanı ve LOD: istemci yalnızca kamera görüş alanındaki ve yakındaki zombilerin modelini ve animasyonunu oynatır; görüş dışındakiler animasyonsuz kalır ama sesleri çalmaya devam eder, yoksa arkadan gelen saldırı sessiz olur. Sunucuda uzak zombiler daha seyrek güncellenir (ör. yakın 10 Hz, uzak 2 Hz).
- Yol bulma: PathfindingService pahalı; tek hedefe giden sürü için akış alanı (flow field) veya ortak yol + bireysel sapma kullan.
- Üsse saldırı: zombi en yakın en zayıf yapı parçasını hedefler; bu kural üs tasarımını anlamlı kılar.

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
| Kapsam taşması (konseptin tamamını MVP'ye sokmak) | Yüksek | Proje bitmez | Kapsam tablosu + "bir giren, bir çıkar" kuralı |
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

## Kaynaklar

- [Roblox — Data store error codes and limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits.md)
- [Roblox — Content maturity and compliance](https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md)
- [Roblox — Content Maturity (etiket tanımları)](https://create.roblox.com/docs/production/promotion/content-maturity)
- [Roblox DevForum — Subscriptions in Robux](https://devforum.roblox.com/t/let-your-players-pay-for-subscriptions-within-experiences-in-robux/4552995)
