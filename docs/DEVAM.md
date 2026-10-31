# Devam notu

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

Yeni bir oturum için tek sayfalık özet. Durum 1 Kasım 2026 itibarıyla. Ayrıntılar:
[HANDOFF.md](HANDOFF.md) (geçmiş, ölçümler, tuzaklar), [NEXT_STEPS.md](NEXT_STEPS.md) (sıradaki işler,
kullanıcı soruları), [PLAN.md](PLAN.md) (tasarım kararları; kodla çelişirse PLAN geçerli).

## Bir bakışta

- **Proje:** Roblox co-op zombi survival. Ana referans 7 Days to Die (7DTD). Rojo dosya yapısı,
  Luau `--!strict`. Kodu Claude yazar; kullanıcı test eder ve son kararı verir.
- **Aşama:** PLAN yol haritasının 1. aşaması (prototip). Telefon FPS kapısı kullanıcı kararıyla ertelendi.
- **Testler:** 90 test, hepsi geçiyor (Studio'da `H.test`).
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
2. **Ölüm** test edilmedi.
3. **Telefon:** ateş istasyonunun üç istemi (E / R / F) dokunmatikte denenmedi.

## Kullanıcı kararı bekleyenler (NEXT_STEPS, 1–8)

1. Taş kazma ve kereste 7DTD'de yok: kalsın mı?
2. Telefon testi: ertelendi.
3. Edit modunda harita önizlemesi silinsin mi?
4. GitHub özel deposu açılsın mı? Dışarıya açık adım; onay şart.
5. Kaynaklar yeniden çıksın mı?
6. Sesler: kullanıcı seçecek; kimlikler Config'deki kancalara yazılır.
7. Ateş tasarımı (bizim): çakmak, lif, odun kömürü, ocağın yalnızca kömür yakması.
8. Eksik malzemelerin yerine geçenler: deri ve koli bandı yerine kumaş ve tutkal; ham demir yerine
   hurda demir; tamir kiti yerine dövme demir.

## Sıradaki işler (sırayla)

Kullanıcı "7DTD'nin bütün özellikleri kapsamlı ve oynanabilir" istedi. Hafızadaki kural: her adım
bitince sıradaki eksik sistemi sormadan başlat, sonunda raporla. Ayrıntı: NEXT_STEPS 24. madde.

1. **Tezgâh (workbench):** tamir kiti, koli bandı; jeneratör ve ileri tarifler tezgâha.
2. **Meşale:** elde taşınan ve duvara konan; gece görünürlüğü.
3. **Kömür ve nitrat kayaları, yanık ağaç.**
4. **Kimya istasyonu:** barut ve cephane üretimi.
5. **Zırh ve giysi.**
6. **Perk ve tarif kitapları:** şimdilik bütün tarifler açık.
7. **Zombi türleri:** Normal, Hızlı, Ses-duyarlı ve 7DTD özel zombileri.
8. **Tüccar ve para:** önce kullanıcıya sor (gelir modeliyle çakışabilir).
9. **Crafting araması;** beton ve demir inşa kademeleri.

Bekleyen diğer işler:
- UI cilası.
- Kalıcılık: kayıt yok; kuyruk, bloklar ve dünya değişiklikleri oturum sonunda kaybolur.
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
