# Devir notu

Bağlamı olmayan yeni bir oturum işe buradan başlar. Sıradaki işler [NEXT_STEPS.md](NEXT_STEPS.md)
dosyasında, tasarım kararları [PLAN.md](PLAN.md) dosyasında, kod yapısı [../README.md](../README.md)
dosyasında. Bu not 30 Ekim 2026 tarihli ilk iki çalışma oturumunu özetler.

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

### 1. Oturum: prototip iskeleti ve zombiler

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

### 2. Oturum: büyük harita ve binalar

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

## Mevcut durum

| Alan | Durum |
| --- | --- |
| Harita (`MapService` + `World/*`) | Çalışıyor. 2048×2048; orman ve küçük kasaba, göl, taş ocağı, telsiz tepesi, çiftlik, kereste atölyesi, hurdalık. Arazi, 37 bina, yollar, sokak eşyaları ve orman sunucu açılışında kodla kuruluyor. |
| Binalar | 15 şablon. Mobilyalı odalar, iki katlılarda merdiven, açılmış kapılar, tabelalar. Her model `Template`, `Loot` (`Food`, `Medical`, `Metal`, `Fabric`…), `Floors` ve `Region` özelliklerini taşıyor; loot sistemi bunları kullanacak. |
| Zombiler (`ZombieService`) | Çalışıyor. Humanoid yok. Akış alanıyla yol bulma, görerek kovalama, ses noktasına gitme, gezinme, oyuncuya saldırı, dalgalı spawn, sunucu LOD'u (yakın 10 Hz, uzak 2 Hz), anlık görüntü yayını. API: `spawn`, `remove`, `clear`, `damage`, `hearSound`, `getStats`, `getNavGrid`. |
| İstemci | `ZombieRenderController`: çizim, interpolasyon, LOD. `DebugOverlayController`: FPS, tick süresi, zombi sayısı; Spawn 80/120, Noise, GodMode ve Clear düğmeleri. |
| Debug | Remote: `DebugCommand`. Yalnızca Studio'da veya `Config.Debug.AllowedUserIds` listesindeki hesaplarla çalışır (`11911303584` test eden hesap). Doğrulanır ve hız sınırlıdır. |
| `DayNightService` | **Boş iskelet.** |
| `ThreatService` | **Boş iskelet.** Config değerleri ve `Types.SoundPoint` hazır. |
| `BuildService` | **Boş iskelet.** `Config.Build` ve `Types.BuildPieceKind` hazır. |
| Kamera (omuz/FPS) | **Yok.** Localization anahtarları (`CameraShoulder`, `CameraFirstPerson`) ve `Config.Camera` hazır. |
| Oyuncunun silahı veya saldırısı | **Yok.** `ZombieService.damage` var ama oyuncu zombiye vuramıyor. |
| Loot, crafting, perk, kayıt, monetizasyon | Bilerek yazılmadı. Yalnızca `Types.ItemSource` ve binaların `Loot` özelliği yer tutuyor. |

### Ölçümler

Ölçümler 30 Ekim 2026'da PC'de, Studio içinde alındı. Telefonda ölçüm yok.

- **Testler:** 18/18 geçiyor (NavGrid 7, HeightField 3, Buildings 5, ZombieProtocol 3). Testler yalnızca
  Studio düzeneğiyle çalıştırıldı; Lune ile hiç çalıştırılmadı.
- **Zombi performansı:** 80 zombiyle sunucu 60 fps, tick ortalaması 0,05 ms, en kötü tick 1,36 ms.
- **Harita kurulumu:** Play'de 2,6 sn, Edit önizlemesinde 4,0–4,4 sn.
- **Parça sayısı:**
  - Haritanın tamamı 22.748 parça.
  - Binalar 11.395 parça: 8.115 süs (çarpışmasız), 3.280 çarpışmalı. Kendi koyduğum yaklaşık 10.000
    hedefinin üstünde.
  - Haritada 114 sokak lambası var.
- **Yol bulma:** 923 zemin hücresi denetlendi, sorun çıkmadı.
- **Bina zemin taraması:** Taban içi her 2 stud'da, dışı 1–12 stud mesafede halka hâlinde tarandı. 37 binanın hiçbirinde arazi
  tabandan çıkmıyor, duvar dibine yükselen yamaç ve alt kısımda boşluk yok, taban altında çimen yok.
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
  üst uç 13,25.
- **Yol bulma ızgarası (NavGrid) 2 boyutlu.** Zemin yüksekliğini 2 stud aşan çarpışmalı her parça
  hücresini kapatır. Süs parçaları çarpışmasızdır.
  - **Zombiler merdiven çıkamaz; üst katlara ulaşamaz.** Bu bilinen bir eksik; NEXT_STEPS'te karar
    bekliyor.
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
- Bu makinede Rojo, StyLua, Selene ve Lune kurulu değil. `rokit install` otomatik modda engellenmişti;
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
   return H.sync() .. "\n" .. H.test(false)   -- beklenen: "18 passed, 0 failed"
   ```
   Düzenek place'e hiçbir şey bırakmaz.
3. Her kod değişikliğinden sonra adım 1'deki bundle komutunu tekrar çalıştır, sonra `H.sync()`.
4. İş bitince HTTP sunucusunu durdur.
5. Studio'daki kopyanın diskle aynı olduğunu doğrulamak için script `Source` uzunluklarını diskteki
   dosyaların CRLF'siz boyutlarıyla karşılaştır.

### Play testi

- Başlat: `start_stop_play(true)`.
- `execute_luau` ile `Server` veri modelinde `workspace.Map` hazır olana kadar bekle.
- Sunucu ve istemci konsolunu `LogService:GetLogHistory()` ile oku. `get_console_output` bazen boş
  döner.
- Bitince `start_stop_play(false)` ile durdur.

### Ekran görüntüsü

- `screen_capture` Play modunda beyaz çıkıyor. Görüntü için haritayı Edit modunda kur:
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

- **Telefonda FPS hiç ölçülmedi.** Aşama 1'in kapısı. Bina parça sayısı hedefin üstünde.
- **Zombiler üst katlara çıkamaz.** Yol bulma ızgarası 2 boyutlu.
- **Araç zinciri hiç çalıştırılmadı.** README'deki `stylua --check`, `selene src` ve `lune run tests/run`
  komutları bu makinede hiç koşmadı. İlk çalıştırmada format ve lint düzeltmeleri çıkabilir.
  `tests/run.luau`'nun gerçek Lune'da da geçtiği doğrulanmalı.
- **MCP sınırları:**
  - Script'ten `StreamingTargetRadius` ayarlanamıyor; yalnızca `default.project.json` içinde.
  - MCP üzerinden `Lighting.Technology` okunamıyor (yetki hatası).
- **Python konsolu cp1254 kodlamasında.** Türkçe veya Unicode yazdıran betiklerde
  `PYTHONIOENCODING=utf-8` kullan.
- **Git yedeği yok.** Uzak depo tanımlı değil. GitHub'a göndermek dışarıya açık bir adım olduğu için
  kullanıcıya sorulmalı.
