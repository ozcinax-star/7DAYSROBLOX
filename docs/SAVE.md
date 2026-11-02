# Kayıt sistemi

Kayıt sistemi 2 Kasım 2026'da eklendi, kullanıcı onayıyla. ProfileStore kullanılıyor
(MadStudioRoblox, commit `45c9847`, `src/server/Vendor/ProfileStore.luau`). Kütüphane oturum kilidi
sağlıyor: bir kayıt aynı anda tek bir sunucuda açık olabiliyor.

## İki kayıt

| Kayıt | Anahtar | İçerik |
| --- | --- | --- |
| Dünya (`World_v1`) | `Private_<PrivateServerId>`; Studio'da `Studio` (sahte depo) | O dünyanın her şeyi ve her oyuncunun o dünyadaki karakteri |
| Profil (`Profile_v1`) | `Player_<UserId>` | Dünyalar arası kalan şeyler: şimdilik görev ilerlemesi (ileride perk, kozmetik) |

- **Public sunucu geçici dünyadır** (PLAN lobi kararı): dünya ve karakter kaydedilmez, profil
  kaydedilir.
- **Private sunucu dünyası kalıcıdır.** Lobi ve davet kodu (PLAN 3. aşama) gelince dünyalar
  ReserveServer ile açılacak; anahtar biçimi o zaman kullanıcı onayıyla belirlenecek.

## Kaydedilenler

**Dünya parçaları**, yükleme sırasına göre:

| Parça | İçerik |
| --- | --- |
| Clock | Gün ve saat |
| Threat | İz (tehdit) |
| Harvest | Kesilmiş ağaçlar, kırılmış kayalar ve mobilyalar; yarım kalan hasar |
| Dig | Kazılan ve doldurulan zemin, kesilmiş otlar |
| Blocks | Bütün bloklar (tür, can, yükseltme, yön, açık kapı) ve yatak sahipleri |
| MapDoors | Haritadaki kapılardan açık bırakılanlar ve kırılanlar |
| Crops | Ekin türü ve yaşı |
| Generators | Yakıt ve açık/kapalı |
| Stations | Ateşlerin yakıtı ve yanıp yanmadığı |
| Crates | Sandık içerikleri |

**Karakter (dünya içinde, oyuncu başına):**

| Parça | İçerik |
| --- | --- |
| Inventory | 55 slot ve seçili toolbelt slotu |
| Vitals | Yiyecek, su, dayanıklılık, can |
| Crafting | Kuyruktaki malzemeler ve tamirdeki alet; geri verilir. Önceden oyundan çıkınca kayboluyordu. |

**Profil:** Challenges (izlenen görev, sırası değişse de bozulmasın diye kimliğiyle saklanır).

## Kaydedilmeyenler

Bunlar bilinçli kararlar ya da sonraki işler:

- **Zombiler:** dünya yüklenince yeniden doğarlar.
- **Ölüm çantaları ve loot çantaları** (5 dakikalık).
- **Loot konteynerlerinin aranmış durumu:** yeniden başlatmada dolarlar. Kalıcı kimlikleri yok;
  `furniture:<hücre>` kimliği kullanılarak eklenebilir.
- **Yarım kazılmış bir sütunun hasarı.**
- **Kazılan çukurların üstündeki gevşek ot modelleri:** asıl yüksekliklerinde yeniden çıkar ve
  havada kalabilirler.

## Güvenlik ve doğrulama

- Yüklenen her satır doğrulanır: bilinmeyen eşya, NaN, sınır dışı sayı, dolu slot, sahte kaynak
  reddedilir.
- Envanter satırlarının saf fonksiyonları Lune ile test edilir: gidiş-dönüş ve bozuk kayıt.
- Profil yüklenemezse oyuncu atılır; varsayılan değerlerle oynayıp gerçek kaydın üstüne yazmaz.
- Dünya yüklenemezse oyun geçici dünya olarak sürer ve hiçbir şey yazılmaz. Bu durumda kayıt da
  güvende kalır.
- ProfileStore 300 sn'de bir, oyuncu çıkınca ve sunucu kapanırken kaydeder.

**Studio'da ölçülenler** (2 Kasım, sahte depo):
- Mağazadan geri okunan veri yazılanla aynı. Karşılaştırma derin ve sıradan bağımsız; `JSONEncode` sözlük
  anahtarlarını sıralamadığı için ilk sürümdeki metin karşılaştırması güvenilir değildi.
- Karakter boşaltılıp geri yüklenince aynı.
- Kırılan blok kayıttan aynı canla geri geldi.
- Atlatılan saat kayıttaki saate döndü.
- 93 test geçiyor.

**Henüz yapılmayan:** PLAN 3. aşama kapısı. Bu kapı gerçek mağazada 50 kayıt/yükleme döngüsünde
sıfır veri kaybını ve aynı dünyanın iki sunucuda açılamamasını istiyor. Bunun için private sunucu
ya da `StudioUsesLiveStore` gerekiyor.

## Debug komutları

`Remotes.DebugCommand:FireServer(...)`; yalnızca Studio'da ya da izinli kullanıcılarda çalışır:

- `"SaveReport"`: şimdi kaydeder ve parça boyutlarını, geri okuma eşleşmesini yazdırır.
- `"ReloadCharacter"`: karakteri kaydeder, boşaltır ve geri yükler; aynı mı diye yazdırır.
- `"LoadPart", "<parça>"`: son kaydedilen parçayı çalışan dünyaya yükler; yalnız eksik olanlar
  geri gelir.

## Kullanıcı testi

**Studio'da kayıt oturumlar arasında kalmaz** (sahte depo). Gerçek deneme için:

1. **Seçenek A:** Bir private sunucu açın, oyuna girin:
   - blok koyun,
   - sandığa eşya koyun,
   - bir çukur kazın,
   - envanterinizi değiştirin.
2. Çıkın, sunucu kapansın (herkes çıkınca kapanır); sonra tekrar girin. Hepsi yerinde olmalı.
3. **Seçenek B:**
   - Game Settings → Security → "Enable Studio Access to API Services" açın.
   - `Config.Persistence.StudioUsesLiveStore = true` yapın.
   - Bu durumda Studio gerçek mağazaya `Studio` anahtarıyla yazar.
   - İki Play oturumu arasında aynı adımları deneyin.
   - Bitince değeri `false`'a geri alın.

## Değiştirirken

Mağaza adı ya da anahtar biçimi değişirse eski kayıtlar kaybolur. Şema değişince `WorldVersion` ya
da `ProfileVersion` artırılır ve `PersistenceService`'e bir dönüştürme adımı eklenir; anahtarlar
dönüştürmesiz yeniden adlandırılmaz.
