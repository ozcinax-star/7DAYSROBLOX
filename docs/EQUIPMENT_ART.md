# Alet ve silah görselleri

31 Ekim 2026 — kullanıcı önceliği: önce aletler ve silahlar. Ana görsel referans 7 Days to Die.

13 elde taşınan eşya yenilendi. İnşa parçaları, mobilyalar, binalar ve çevre bu adımın kapsamı değil.
Eskimiş ahşap, taşın yontulmuş kenarı, lif bağları, aşınmış metal, boya ve farklı siluetler kullanıldı.
Görseller özgün üretimdir; 7DTD'nin mesh veya dokuları oyundan çıkarılmadı.

## Yapı

- `src/shared/HeldItems.luau`: elde tutuş, sap uzunluğu ve ortak model fabrikası. Mevcut animasyon
  eksenleri korunur. Envanter sunucusu ve birinci şahıs controller'ı aynı fabrikayı kullanır.
- `src/shared/EquipmentAssets.luau`: incelenen özgün mesh ve doku kimlikleri, kaynak boyutları,
  tutuş noktaları ve görsel ölçek/yön düzeltmeleri. Rojo veya MCP senkronu için ikili model dosyası gerekmez.
- `src/shared/EquipmentMeshes.luau`: dokulu bileşenleri `SpecialMesh` ile kozmetik parçalara kurar;
  çalışma anında InsertService, HTTP veya varlık ekleme servisi kullanmaz.
- `src/shared/EquipmentModels.luau`: elle çizilen bıçak profilleri, kazma uçları, saplar, lif bağları,
  yay ve ayrıntılı prosedürel modeller. Bazı eşyalar dokulu sap + elle çizilmiş başlık kullanır.

Studio Mesh Generation denemelerinde çift başlık, eksen hatası ve yinelenen parçalar görüldü.
Uygun olmayan bileşenler çıkarıldı. Taş balta, taş kürek ve yay elle kurulan modellerdir; kazmalar
ve sopada dokulu sap ile elle çizilen başlık birlikte kullanılır. Jeneratörün ürettiği geniş balta
başlığı kazma yerine kullanılmaz. Yayın gerçek bir kavisli kolu ve düz kirişi vardır.

## Son model sayımları

Sayılar görünmez tutuş kökü dahil BasePart sayısıdır; Weld ve SpecialMesh sayısı değildir.

| Eşya | Parça | Yöntem |
| --- | ---: | --- |
| Stone Axe | 43 | Yontulmuş taş profili, lif bağları, parçalı ahşap sap |
| Stone Pickaxe | 22 | Dokulu sap, elle çizilen iki sivri taş uç |
| Stone Shovel | 43 | Taş bıçak, lif bağları, ahşap sap |
| Iron Fireaxe | 3 | Dokulu sap ve aşınmış kırmızı başlık |
| Iron Pickaxe | 21 | Dokulu sap, elle çizilen iki sivri demir uç |
| Iron Shovel | 4 | Dokulu sap, soket ve metal kürek |
| Wooden Club | 12 | Dokulu tutamak, ağır ahşap başlık ve yarıklar |
| Stone Spear | 3 | Dokulu uzun sap ve bağlanmış taş uç |
| Primitive Bow | 21 | Kavisli kollar, tutamak, düz kiriş ve uç bağları |
| Pipe Pistol | 4 | Dokulu tabanca: ayrı kabza, gövde/tambur ve namlu |
| Pipe Rifle | 4 | Dokulu uzun silah, düzeltilmiş namlu açısı |
| Pipe Shotgun | 2 | İncelenmiş gövde, düzeltilmiş yön ve tutuş |
| Pipe Machine Gun | 4 | Dokulu otomatik silah ve belirgin şarjör |

Tüm parçalar `CanCollide = CanQuery = CanTouch = false`, `Massless = true`; gölge atmaz.
Hasar, menzil, ateş hızı, cephane ve tarifler değiştirilmedi. Debug GiveKit'e demir balta ve demir
kürek eklendi; bütün modeller tek test çantasıyla incelenebilir.

## Doğrulama

- 13 model Edit modunda oluşturuldu; fizik bayrakları, pozitif/sonlu boyutları ve parça bütçeleri denetlendi.
- Studio'daki saf mantık düzeneği: 85 test geçti, 0 başarısız.
- Play'de 13 eşya tek tek seçildi: karakterdeki `HeldItem` ile gerçek `Viewmodel.HeldItem` kimlikleri
  eşleşti. İlk turdaki boş yuva denemesi, eşya adından güncel yuvayı bularak tekrarlandı ve geçti.
- Birinci şahıs görünümü ve Edit modelleri ekran görüntüleriyle incelendi. Kamera, MCP'nin Fixed
  kamera müdahalesi nedeniyle yalnızca test süresince baş hizasında sabitlendi.
- Boru makineliyle gerçek fare tıklaması: sunucunun `ArrowFired` yayınıyla 3 atış doğrulandı;
  birinci şahıs modelinde 3 mesh bileşeni duruyordu. Sunucu konsolunda hata yoktu.
- İstemcide açılış sırasında `WaitForChild("InventoryMove")` için bir gecikme uyarısı görüldü;
  remote daha sonra geldi ve envanter testleri çalıştı. Ayrıca MCP'nin kamera sıfırlama notu vardı.
  Model yükleme/kurma hatası görülmedi.
- Telefonda FPS, gerçek cihazda görüntü ve çok oyunculu performans bu adımda ölçülmedi.
  StyLua, Selene ve Lune bu makinede kurulu olmadığından çalıştırılmadı.

## Kullanıcı testi

1. Studio'da **Play (F5)** başlat; soldaki **Give test items** düğmesine bas.
2. **Tab / I / Bag** ile çantayı aç. Yukarıdaki eşyaları boş toolbelt yuvalarına taşı.
3. **1–0** ile seç; **V** ile omuz / birinci şahıs / serbest kamera arasında geç.
4. Aletlerde sol tıkla vur; başlık sapla birlikte hareket etmeli, elin tutuşu sapta kalmalı.
5. Yay ve boru silahlarıyla ateş et. Tabanca, tüfek, pompalı ve otomatik silah ayrı görünmeli;
   namlu ileri bakmalı, kamera içinden dipçik veya kopuk parça görünmemeli.
6. Çanta açıkken / Alt basılıyken imleç serbesttir. Bitince **Stop (Shift+F5)**.

## Görsel referans

- [7DTD A20 resmi duyuruları](https://store.steampowered.com/news/posts/?appids=251570&enddate=1640061141&feed=steam_community_announcements)
- 7DTD'nin oyun içi alet, boru silah ve birinci şahıs eşya görselleri: malzeme dili ve siluet referansı.

Varlık kimlikleri manifestte sürümlenir. Yayınlanan asıl deneyim bu çalışma sırasında güncellenmedi.
