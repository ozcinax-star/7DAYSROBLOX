# Ses efektleri

Ses sistemi 1 Kasım 2026'da eklendi. Önceden oyunda hiç ses yoktu: beş silah ve zombi inlemesi için
kanca vardı, hepsi boştu.

## Yapı

- **`Config.Sounds.Events`:** her olayın kimlik listesi, ses düzeyi, perde aralığı, menzili ve
  gerekiyorsa kesim aralığı (`Region`). Sayılar yalnızca burada.
- **`SoundController` (istemci):**
  - Her çalmada rastgele kimlik ve perde seçer.
  - Bir olay aynı anda en fazla `MaxPerEvent` kopya çalar.
  - Menzil dışındaki konumlu sesler hiç oluşturulmaz.
  - Gündüz rüzgârı ile gece cırcır böcekleri arasında geçiş yapar.
  - Yakındaki yanan ateşler çıtırdar.
- **`WorldSound` (sunucu → herkes, güvenilmez):** kapı açma ve kapama, blok yerleştirme ve kırılma.
  Sunucu karar verir; istemci yalnızca çalar.

## Bağlı olaylar

| Olay | Nerede |
| --- | --- |
| Atış (5 silah) | ArrowController, namluda, bütün oyunculara |
| Doldurma (şarjör / fişek) | WeaponController, doldurma başlayınca |
| Boş tetik | ToolController, mermi kalmayınca |
| Salınım | ToolController `playSwing` (kendi ve diğer oyuncular) |
| Vuruş: et / ahşap / taş / metal | ToolController; vuruş noktasının arkasındaki malzemeye göre, bıçağın indiği anda |
| Ok saplanması, mermi isabeti | ArrowController |
| Zombi inlemesi, saldırı hırlaması, ölüm | ZombieRenderController |
| Horde gecesi kükremesi | DayNightController, gecenin başında bir kez |
| Oyuncu acı sesi | HurtController |
| Ağaç devrilmesi | TreeFallController |
| Eşya alma | PickupFeedController |
| Crafting bitti | CraftingController (iptal olmadan kuyruk küçülünce) |
| Kapı, blok yerleştirme / kırılma | BuildService → WorldSound |
| Ortam ve ateş | SoundController |

## Kaynak ve lisans

Bütün kimlikler Roblox'un lisanslı **Pro Sound Effects** kütüphanesinden (yükleyici `ProSoundEffects`);
deneyimlerde serbestçe kullanılabilir. Yükleyiciler Studio'da `GetProductInfoAsync` ile doğrulandı.
Mağazada başka oyunlardan koparılmış sesler (PvZ, Helldivers, L4D modları) bilerek kullanılmadı.

**Eksik (PSE'de bulunamadı):** yay sesi (yerine perdesi yükseltilmiş salınım sesi kullanılıyor), yeme,
içme, adım sesleri. Adımlarda Roblox'un varsayılan karakter sesleri çalıyor.

## Ölçüm

Her ses Studio'da düşük düzeyde (0,15) çalındı. `PlaybackLoudness` Heartbeat'te örneklendi: başlangıç
tepe değerin %15'ini geçtiği an; ilk olayın sonu, 0,12 s boyunca bu eşiğin altında kalınan an.

| Olay | Uzunluk | Tepe | İlk olay | Karar |
| --- | --- | --- | --- | --- |
| PistolShot #1 | 2,08 s | 279 | 0,04–0,29, 2 olay | Çıkarıldı (iki atış) |
| PistolShot #2 | 2,08 s | 230 | 0,04–0,64 | Kullanılıyor, `Region 0–0,9` |
| Eski pompalı adayı (Gun Live Ammunition 6) | 0,36 s | 5 | – | Atış değil; çıkarıldı |
| 12 Gauge Shotgun 301 / 302 | 2,19 s | 239 / 203 | tepe 0,03 s | Kullanılıyor, `Region 0–1,2` |
| RifleShot | 3,07 s | 125 / 264 | tepe 0,03 s | `Region 0–1,6` |
| MachineGunShot | 1,32 s | 466 | 0,04–0,12 | Ses düzeyi 0,6, `Region 0–0,5` |
| ReloadMagazine (Handling 6) | 1,57 s | 5 | – | Çok sessiz; yerine Handling 3 (tepe 50) |
| HitStone #2 | 0,39 s | 3 | – | Sessiz; yerine Rock Impact Dirt (167) |
| ZombieGroan #4 / #5 | 2,25 / 4,66 s | – | 2 / 5 olay | Çıkarıldı (seri) |
| ZombieAttack #2 | 2,28 s | 40 | 2 olay | Çıkarıldı |
| DoorOpen / DoorClose | 1,76 / 2,87 s | 33 / 21 | başlangıç 0,47 / 0,50 s | `Region 0,4–1,3` / `0,4–1,4`, ses düzeyi 1 |
| TreeFall | 27 s | 355 | sürekli | `Region 0–3` |

Ses düzeyleri ölçülen tepe değerlerine göre dengelendi: tepesi yüksek olan sesin düzeyi düşürüldü,
sessiz olanınki artırıldı. Bunlar başlangıç değerleri; kulakla son ayar kullanıcıya ait.

## Kullanıcı testi

1. Play. Give test items. Tabancayı toolbelt'e al ve seç.
2. Ateş et:
   - atış sesi
   - boşken tıklama (`DryFire`)
   - R ile doldurma sesi
3. Spawn 1:
   - zombinin inlemesini uzaktan duy
   - yaklaşınca saldırı hırlaması
   - Kill nearest zombie ile ölüm sesi
4. Yumruk ya da baltayla:
   - ağaca vur (ahşap)
   - kayaya vur (taş)
   - zombiye vur (et)

   Ses, kol vuruş noktasına indiğinde gelmeli.
5. Kapı aç ve kapat, blok koy, bloğu kır.
6. Skip to next phase ile geceye geç: rüzgâr yerini cırcır böceklerine bırakmalı.
7. Beğenmediğin bir sesin kimliğini `Config.Sounds.Events` içinde değiştir.
