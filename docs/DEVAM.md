# Devam notu

## Güncel ek: ekran kontrolü ve öz eleştiri turu (2 Kasım 2026, Claude)

Kullanıcı: "kendi tercihlerinle otonom devam et, kendi ürününü her seferinde eleştir". Studio görüntüsü
düzeldi; ekran görüntüleriyle eleştirip düzelttiklerim (ayrı commit'ler):
- **İlk ekran kontrolü** (`84cf54c`): perk paneli imleci serbest bırakıyor, XP çubuğu koyu zeminde
  okunuyor, kapılar mermer değil tahta, tabelalar gece parlamıyor, meşalenin kendi ikonu var.
- **Zombi görünüşü** (`edfb703`, `537c1b3`): oval kafatası, el ve ayak, çökük göz, açık ağız; ölürken
  önce dizleri bükülüyor, sonra devriliyor.
- **Ruh hali** (`69de7fa`): bulutlu gökyüzü, solmuş çimen, daha çürük ten (kırmızı kan yok, PLAN);
  türler gözden okunuyor: Hızlı turuncu parlayan göz, Dinleyici büyük soluk göz ve şiş ten.
- **Doğma** (`eafdfdb`, `6eb8a63`): zombiler yalnızca oyuncuların çevresinde ve görünmeyen yerde doğuyor;
  spawn karosu ve mavi kalkan kaldırıldı. Ölçüm: en yakın zombi 71–85 stud, can 100'de kaldı.
- **HUD** (`7259a23`): toolbelt'te yalnızca ikonlar, tutulan eşyanın adı üstte.
- **Arabalar** (`c2dd138`): 9 araba ve kamyon 4 sn'lik loot konteyneri (araba parçaları, benzin, boru,
  bant, hurda; 2 zar, %30 boş) ve kırılabilir (vurdukça hurda demir). Ölçüm: 2000 zarda %20,3 boş
  (eski tek zar), hurda 3–8; taş kazmayla vuruş başına 1 hurda.
- **Konteyner kaydı** (`45440af`): aranmış konteynerlerde kalanlar dünya kaydında. Önceden özel sunucudan
  çıkıp girince bütün kasaba yeniden doluyordu.
- **Katı zombiler** (`5f8f2f4`, `caa4374`): oyuncu artık zombilerin içinden geçemiyor; kalabalık köşeye
  sıkıştırır. Ölçüm: çarpışma kapalıyken 0,05 stud, açıkken 1,34 stud (temas); 80 zombiyle 59,5 FPS.
  Zombinin kafasına çıkan oyuncu vurulamıyordu (10 sn can 84'te kaldı). Şimdi alttaki ya da dipteki
  zombiler bir gövde boyu yukarı uzanıyor: can 92→37.
- **Ölüm cezası** Play'de doğrulandı (aşağıda, "Doğrulanmamış" 2).
- **Zırh** (`e239c07`): 4 yuva; ilkel set (8 puan/parça, lif + odun) ve demir set (18, tezgâh). Elde
  tutup tıklayınca giyilir, çantanın yanındaki panelden çıkar; ölümde kalır ve kaydedilir; uzuvlarda
  kabuk olarak görünür. Ölçüm: kapüşon + demir yelek (26) 8'lik vuruşu 5,92'ye indirdi, parçalar
  250→246 aşındı. Kayıt yükleme birebir aynı, kötü girdi testinde hata yok. Eksikler: ağır zırhın
  hareket ve ses cezası, kalite, set bonusu.

98 test geçiyor. Doğrulanmayanlar: gerçek yeniden başlatmada kayıt (Studio'da sahte depo Play durunca
silinir), telefon FPS'i, seslerin kulakla ayarı.

## Güncel ek: silah kullanımı (1 Kasım 2026, Codex)

Silah başına gerçek şarjör, R/B/touch doldurma, kısmi doldurma ve iptal, güvenilir mermi HUD'u,
silaha göre tepme, yumuşak ADS, hareket saçılması, ortak gez/arpacık ve iki el tutuşu eklendi.
R15 kolları gerçek eklem ölçülerinden çözülür; yakıt tuşu artık T. 90 test geçti. Studio'da
tekli/otomatik ateş, pompalı, sayımlar, nişan hızı/FOV ve balta savruluşu kontrol edildi.
Ayrıntı, ölçümler, sınırlar ve kullanıcı test adımları: [WEAPON_HANDLING.md](WEAPON_HANDLING.md).
Ses seçimi ve fiziksel telefon FPS kapısı hâlâ bekliyor.

## Güncel ek: alet ve silah görselleri (31 Ekim 2026, Codex)

Kullanıcı önceliğiyle 13 alet/silahın modelleri yenilendi; 7DTD ana görsel referans.
Dokulu özgün meshler ve elle çizilen profiller `Shared/EquipmentAssets`, `EquipmentMeshes` ve
`EquipmentModels` içinde; `HeldItems` hem sunucu hem birinci şahıs için ortak fabrika.
Debug GiveKit artık demir balta ve demir kürek de verir. Ayrıntı ve test adımları:
[EQUIPMENT_ART.md](EQUIPMENT_ART.md). 85 saf mantık testi geçti; 13 eşyanın karakter ve gerçek
birinci şahıs kopyaları Play'de denetlendi; makineliyle 3 atış sunucudan doğrulandı. Mobil FPS ölçülmedi.
Önceki oturumların oynanış doğrulamaları ve aşağıdaki yol haritası devam ediyor.

## Güncel ek: bina kapıları (2 Kasım 2026, Claude)

Kullanıcı: "kapılar açık geliyor, açılıp kapanabilmeli". Haritadaki 134 kapı artık gerçek. Başta kapalılar
ve E ile açılıp kapanıyorlar. Zombiler kapı açamıyor, kapalı kapıyı kırıyor. Açık ve kırık kapılar dünya
kaydında. Debug: `"SpawnHorde"` oyuncuyu bilen tek horde zombisi doğurur (kapı ve duvar testleri için).

## Güncel ek: otonom sistem turu (2 Kasım 2026, Claude)

Kullanıcı "sormadan geliştirmeye devam et" dedi. Kayıttan sonra şunlar eklendi (ayrı commit'ler):
- **Tezgâh:** koli bandı, çivi, tamir kiti; jeneratör ve lamba tezgâhta.
- **Meşale:** elde ışık; konan meşale sürekli yanar; başlangıçta bir tane.
- **Kömür ve nitrat kayaları.**
- **Barut ve mermi:** barut sırt çantasında (oran doğrulanmadı), mermi tezgâhta.
- **Deneyim, seviye ve 3 perk:** K ile açılır; profilde kayıtlı.

97 test geçiyor. Görsel işler (zırh, modeller) Studio görüntüsü düzelene kadar bekliyor.

## Güncel ek: kayıt sistemi (2 Kasım 2026, Claude)

Kullanıcı onayıyla kayıt eklendi (ProfileStore, oturum kilitli):
- **Private sunucu dünyası kalıcı:** bloklar, sandıklar, kazı, ekinler, ateşler, jeneratörler, kesilen
  ağaçlar, saat, İz ve her oyuncunun o dünyadaki envanteri ile değerleri.
- **Profil:** görev ilerlemesi.
- **Public sunucu:** geçici dünya (PLAN).

Studio'da sahte depoyla geri okuma ve yükleme yolları doğrulandı. Gerçek mağazada çok oturumlu test
ve PLAN 3. aşama kapısı henüz yapılmadı. Ayrıntı ve test: [SAVE.md](SAVE.md).

## Güncel ek: inceleme ve düzeltme turu (1 Kasım 2026, Claude)

Tam kod ve oyun incelemesi [REVIEW_2026-11-01.md](REVIEW_2026-11-01.md) içinde. Ardından kullanıcı
"otonom devam et" dedi ve şunlar yapıldı (her biri ayrı commit'te):

- **Tepme:** kamera artık geri dönüyor.
  - Eskiden her atış kalıcı +1,24° bırakıyordu; şimdi 0,00° (ölçüldü).
  - Kritik sönümlü yay: 40 ms'de tepe.
- **Hasar geri bildirimi:**
  - kırmızı kenar flaşı
  - kamera sarsıntısı
  - %30 canın altında nabız ve renk solması
- **Sesler:** önceden hiç ses yoktu.
  - Silah, yakın dövüş (malzemeye göre), zombi, kapı ve blok, ağaç, eşya, crafting, ortam ve ateş.
  - Hepsi Roblox'un lisanslı Pro Sound Effects kütüphanesinden; kesimler ölçülen ses zarfından.
  - Ayrıntı ve kullanıcı testi: [SOUND.md](SOUND.md).
- **Yakın dövüş:** efekt ve ses bıçağın indiği karede; yakın dövüşte isabet işareti, kafa vuruşu kırmızı.
- **Ağ:**
  - Hayalet zombi düzeltildi (mezar taşı ve bayat görünüm temizliği).
  - Durum değişikliği 3 görüntüde yeniden gönderiliyor.
  - Gece saldırı animasyonu sunucuyla eşleşiyor.
- **Sunucu:**
  - takılan zombi yana kayıyor
  - sonsuz Clay döngüsü kapandı
  - ölümde nişan sıfırlanıyor
  - çanta sınırı doldurulan çantayı silmiyor
- **Silah hissi:**
  - 0,12 sn tıklama tamponu
  - sabit atış aralığı (yumruk 0,850 sn ölçüldü)
  - nişan alırken fare hassasiyeti ölçekleniyor
  - viewmodel vuruşa hızlanarak giriyor
- **Görünüm:** solgun ve hafif sıcak renk düzeltmesi; gündüz tozlu pus, gece soğuk koyu atmosfer.
  **Ekranda doğrulanmadı:** bu oturumda Studio görüntüsü bembeyaz kaldı (Edit modunda bile).
  Studio yeniden başlatılmalı.
- **3 zombi türü:** Normal, Hızlı, Dinleyici (PLAN MVP). Tür kimlikten türetiliyor.

91 test geçiyor. Doğrulanmayanlar: görsel değişiklikler (beyaz görüntü), seslerin kulakla ayarı,
telefon FPS'i.

Yeni bir oturum için tek sayfalık özet. Durum 1 Kasım 2026 itibarıyla. Ayrıntılar:
[HANDOFF.md](HANDOFF.md) (geçmiş, ölçümler, tuzaklar), [NEXT_STEPS.md](NEXT_STEPS.md) (sıradaki işler,
kullanıcı soruları), [PLAN.md](PLAN.md) (tasarım kararları; kodla çelişirse PLAN geçerli).

## Bir bakışta

- **Proje:** Roblox co-op zombi survival. Ana referans 7 Days to Die (7DTD). Rojo dosya yapısı,
  Luau `--!strict`. Kodu Claude yazar; kullanıcı test eder ve son kararı verir.
- **Aşama:** PLAN yol haritasının 1. aşaması (prototip). Telefon FPS kapısı kullanıcı kararıyla ertelendi.
- **Testler:** 98 test, hepsi geçiyor (Studio'da `H.test`).
- **Çalışan sistemler:**
  - **Dünya:** 2048×2048 harita, 37 bina, gündüz-gece, tehdit ve horde.
  - **Zombiler:** Humanoid'siz; sarsılarak yürür, eve girer.
  - **Hayatta kalma:** envanter, toplama, kazı, crafting kuyruğu, hayatta kalma değerleri.
  - **İnşa:** çerçeve, ahşap, kırık taş, kapı, parmaklık, kazık, sandık, yatak rulosu.
  - **Ekonomi ve loot:** tarım, jeneratör ve lamba, mobilya kırma, loot.
  - **Silahlar:** yakın dövüş, yay, boru silahlar.
  - **Ateş ve demir:** kamp ateşi ve demirci ocağı (yakıtlı), odun kömürü, çakmak, demir cevheri,
    demir aletler.
  - **Arayüz ve kamera:** omuz ve birinci şahıs kamera, vuruş animasyonları, görev zinciri
    (tutorial), eşya bilgi paneli.

## Son oturumda yapılanlar (1 Kasım, iki kullanıcı testi)

**1. test:** "Envanteri açamadım, odun kıramadım."
- **Kök nedenler:**
  - Tab tuşunu Roblox oyuncu listesi yutuyordu.
  - Türkçe Q klavyedeki "i" tuşu oyunda `Quote` olarak geliyordu.
  - Yumruk vuruşu ekranda hiçbir geri bildirim vermiyordu.
- **Düzeltmeler:**
  - Tab, I ve Bag düğmesi çantayı açıyor.
  - Vuruş can çubuğu ve "Too far away" uyarısı eklendi.
  - Ayrıca: kontrol listesi, görev zinciri, omuz kamerası, vuruş parçacıkları, ölüm ekranı, otlu
    zeminden lif, eşya bilgi paneli. Ayrıntı: HANDOFF 26. bölüm.

**2. test:** "Animasyon yok, birinci şahıs yok, fare kilitli, zombiye vuramıyorum, demir ve ateş yok,
inşa yok."

| Commit | İş |
| --- | --- |
| `08a1031`, `809479f` | Nişangâhın altındaki zombiye isabet; zombinin canı vuruş çubuğunda |
| `64b7345` | Debug panelinde imleci serbest bırakma ipucu (Alt ya da Tab) |
| `0617fa1`, `b7241b7` | Birinci şahısta kol ve alet; vuruş animasyonları (üçüncü şahısta eklem `Transform`'una bindirme) |
| `be63203` | Crafting sekmeleri |
| `eef8033` | Kamp ateşi yakıtı (R), yakma (F), çakmak ya da lif, odun kömürü |
| `2549bc6` | Demirci ocağı, dövme demir, boru, tencere ve ızgara |
| `68256dc` | Demir cevheri kayaları; demir balta, kazma, kürek |
| `b041d82`, `9e4f9fa` | PLAN, NEXT_STEPS ve HANDOFF güncellendi |

**İnşa zaten vardı.** Yol: Resources sekmesinde Lumber → Building sekmesinde Wood Frame → çerçeveyi
toolbelt'e al ve elde tut → hayalet önizleme çıkar, sol tık koyar → çantada 4 kereste varken
**taş baltayla** 3 vuruş ahşap bloğa yükseltir. Demir balta blok kırar, yükseltmez (7DTD gibi).

**Fare:** Omuz modunda fare tasarım gereği kilitli. Alt basılıyken ya da Tab ile çanta açıkken imleç
serbest kalır; V ile serbest fare moduna geçilir.

## Doğrulanmamış (önce bunlar)

1. **Gerçek fareyle zombiye vuruş.** Düzeltme yalnızca sabit test kamerasıyla ölçüldü. Son Play
   testinde karakter kendiliğinden yürüdü (kullanıcı muhtemelen aynı anda oyundaydı). Kullanıcıdan
   istenecek test:
   1. Give test items, God mode, Spawn 1 (zombiyi Make noise ile çağır).
   2. Elde sopa ya da balta, nişangâh zombinin gövdesinde, kol mesafesinde sol tık.
   3. Beklenen: çubukta yaklaşık 125 can azalıyor.
   4. Olmazsa V ile serbest fareyle dene; hangi modda olmadığını öğren.
2. ~~**Ölüm**~~: doğrulandı (2 Kasım). Ham kaynakların yarısı 300 sn'lik çantaya düştü (odun 50→25,
   hurda 60→30, lif 20→10, küçük taş 20→10, kumaş 4→2, kil 20→10). Kereste, çerçeve, yiyecek ve
   aletler kaldı. Ölüm ekranı yazısı ve "Your bag" işareti göründü. Yeniden doğuş 4,8 sn sürdü,
   değerler tam geldi (yiyecek 100, su 99,9, dayanıklılık 100, can 100).
3. **Telefon:** ateş istasyonunun üç istemi (E / R / F) dokunmatikte denenmedi.

## Kullanıcı kararı bekleyenler (NEXT_STEPS, 1–8)

1. Taş kazma ve kereste 7DTD'de yok: kalsın mı?
2. Telefon testi: ertelendi.
3. Edit modunda harita önizlemesi silinsin mi?
4. GitHub özel deposu açılsın mı? Dışarıya açık adım; onay şart.
5. Kaynaklar yeniden çıksın mı?
6. Sesler: eklendi ([SOUND.md](SOUND.md)); kulakla son ayar kullanıcıda.
7. Ateş tasarımı (bizim): çakmak, lif, odun kömürü, ocağın yalnızca kömür yakması.
8. Eksik malzemelerin yerine geçenler: deri ve koli bandı yerine kumaş ve tutkal; ham demir yerine
   hurda demir; tamir kiti yerine dövme demir.

## Sıradaki işler (sırayla)

Kullanıcı "7DTD'nin bütün özellikleri kapsamlı ve oynanabilir" istedi. Hafızadaki kural: her adım
bitince sıradaki eksik sistemi sormadan başlat, sonunda raporla. Ayrıntı: NEXT_STEPS 24. madde.

1. ~~Tezgâh~~: yapıldı (2 Kasım): tezgâh, koli bandı, çivi, tamir kiti; jeneratör ve lamba tezgâhta.
2. ~~Meşale~~: yapıldı (2 Kasım): elde ışık, konan meşale, başlangıçta bir tane.
3. ~~Kömür ve nitrat kayaları~~: yapıldı (2 Kasım). Yanık ağaçlar henüz yok.
4. Kimya istasyonu: barut (sırt çantasında, oranı doğrulanmadı) ve mermi (tezgâhta) yapıldı (2 Kasım); istasyonun kendisi henüz yok.
5. Zırh yapıldı (2 Kasım): 4 yuva, ilkel ve demir set. Hareket cezası, kalite ve set bonusu yok.
6. Perkler yapıldı (2 Kasım): deneyim, seviye, Scavenger / Builder / Combat (3 kademe, K). Tarif kitapları henüz yok; bütün tarifler açık.
7. **Zombi türleri:** Normal, Hızlı, Ses-duyarlı ve 7DTD özel zombileri.
8. **Tüccar ve para:** önce kullanıcıya sor (gelir modeliyle çakışabilir).
9. **Crafting araması;** beton ve demir inşa kademeleri.

Bekleyen diğer işler:
- UI cilası.
- Kalıcılık: kayıt var ([SAVE.md](SAVE.md)); gerçek mağazada çok oturumlu test bekliyor.
- Araç zinciri: `rokit install` ve `rojo plugin install` komutlarını kullanıcı çalıştırır; ardından
  stylua, selene ve lune ilk kez koşulur.
- Telefon FPS testi.
- 3 kişilik prototip oyun testi.

## Yeni oturumda çalışma yöntemi

- **Okuma sırası:** bu dosya → HANDOFF → NEXT_STEPS → PLAN.
- **Studio senkronu** (Rojo kurulu değil; HANDOFF "Rojo yokken senkron"):
  1. `python tools/studio/bundle.py . <scratchpad>/sync`
  2. O klasörde arka planda `python -m http.server 8765 --bind 127.0.0.1`.
  3. Studio Edit modundayken `execute_luau` ile `Harness.luau`'yu yükle, `H.sync()` ve `H.test(false)`
     çalıştır.
- **Play testi:**
  - Debug remote: `Remotes.DebugCommand:FireServer("GiveKit" | "GodMode" | "Spawn", 1 | "Clear")`.
  - Konsol: her veri modelinde `LogService:GetLogHistory()`.
- **Tuzaklar** (hepsi HANDOFF "Bilinen sorunlar"):
  - `execute_luau` ayrı bir VM'de çalışır; `require` servisin yeni bir kopyasını verir.
  - MCP kamerayı Fixed'e alır.
  - Avatar eklemleri `AnimationConstraint`'tir.
  - Bash heredoc'u bazen bozulur: yamaları scratchpad'e dosya olarak yaz, `python` ile çalıştır.
  - Karakter kendiliğinden yürüyorsa önce `GetKeysPressed()` oku.
- **Kurallar** (CLAUDE.md):
  - Kullanıcıyla Türkçe konuş; kod ve UI metni İngilizce.
  - Metinler `Localization`'da, sayılar `Config`'de.
  - Sunucu otoriter.
  - Her adım ayrı commit; mesaj `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ile biter.
  - Her adımdan sonra test adımları yazılır.
- **Oturum sonu:**
  - Studio Edit modunda.
  - Workspace'te yalnızca Camera ve Terrain.
  - HTTP sunucusu kapalı.
  - Her şey commit'li.
  - Bu dosya, HANDOFF ve NEXT_STEPS güncel.
