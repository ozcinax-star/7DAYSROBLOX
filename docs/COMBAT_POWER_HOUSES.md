# Silahlar, dövüş, zombiler, elektrik ve evler — 1 Kasım 2026

Kullanıcı isteği:
- Silah modellerindeki hatalar düzeltilsin ve boyutlar eleştirel gözle incelensin.
- Şeffaf bloklar düzeltilsin.
- Zombiler daha özgün görünsün.
- Kafa vuruşu ve dövüş geliştirilsin.
- Evler yıkılabilir ve güçlendirilebilir olsun.
- Taret, elektrik ve jeneratör eklensin.

Her adım ayrı commit'lendi. Studio'da Play ile doğrulandı. Sayılar 7DTD v3.2 XML dosyalarından
(blocks, recipes, buffs, entityclasses) alındı; uyarlananlar `Config` içinde gerekçesiyle yazıyor.

## 1. Silahların eleştirisi ve düzeltmeler (`1df1714`, `4884551`)

Ölçek: karakter 5,46 stud ≈ 1,75 m, yani 1 m ≈ 3,1 stud. Ölçüm, mesh köşe noktalarından
(EditableMesh) tutuş uzayında yapıldı.

| Eşya | Önce | Gerçek | Karar | Sonra |
| --- | ---: | ---: | --- | ---: |
| Pipe Pistol | 1,65 (0,53 m) | ~0,3 m | Gerçeğin iki katı; en aykırı | 1,25 (okunabilirlik için biraz büyük) |
| Pipe Rifle | 4,28 (1,38 m) | ~1,1 m | Fazla uzun | 3,60 |
| Pipe Shotgun | 3,25 | ~1,0 m | Uygun; el dipçikteydi, tetikten 1,1 stud geride | 3,10, el bileğe alındı |
| Pipe MG | 3,20 | ~0,9 m | Uygun | değişmedi |
| Wooden Club | 1,98 | ~0,75 m | Kısa; kalın silindir başıyla el fenerine benziyordu | 2,3, konik sopa |
| Bow, Spear, aletler | — | — | Makul | değişmedi |

Bulunan hatalar:
- **Havada asılı gez/arpacık:** Tüfekte gez gövdenin 0,5 stud üstündeydi, pompalıda da yüksekti.
  Nişan hattı ve arpacık artık ölçülen yüzeye oturuyor (`FrontBase`). Makinelinin mesh'inde kendi
  gezi var; ikinci set eklenmiyor (`MeshSights`).
- **Taş başlıklar** soluk buz camı gibi görünüyordu; çakmaktaşı tonlarına koyulaştırıldı.
- **Mızrak:** sap mesh'inin içinde 0,68 stud genişliğinde bir "yıldız" çıkıntısı vardı. Mızrak
  tamamen elle çizilen modele geçti.
- **Sopa:** mesh'teki beyaz, kırık kemik gibi tutamak kaldırıldı.
- **Demir kazma:** başlıktan kopuk görünen uç parçası birleştirildi.

Studio ölçümleri:
- Dört silahta ADS nişan hattı ekran merkezinde, 0 piksel sapma.
- Tüfek ve pompalıda dipçik nişanda alt yarıyı kapladığı için nişan mesafesi uzatıldı (−2,7 / −2,8).

Eleştiri, yapılmayanlar:
- Tabanca hâlâ fabrika yapımı bir revolver, makineli de AK benzeri; ikisi de el yapımı "pipe" silaha
  benzemiyor.
- Studio Mesh Generation ile dört silah yeniden üretildi. Pompalıda namlu gövdeden kopuktu, tüfek
  kütleşti, tabanca yine revolver çıktı. Mevcutlardan iyi olmadığı için kullanılmadı.
- Bu dört üretim kullanıcının envanterinde yayımlanmış varlık olarak duruyor (silinmedi).

## 2. Şeffaf bloklar (`f938652`)

Kök neden: `WoodFrame` düz bir kutuydu ve `Transparency = 0.25` idi; cam gibi görünüyordu. Şimdi:
- Kutu görünmez ama çarpışır.
- Üstünde 12 kenar kirişi ve her yüzde çapraz destek var (7DTD çerçevesi).
- Yükseltmede süsler temizleniyor.

Play'de çerçevede 16 kiriş ölçüldü. Taş baltayla 3 vuruşta 500 canlı, opak, süssüz ahşap bloğa döndü.
Debug çantasına çerçeve, kereste, kablo aleti, iki taret ve dört çit direği eklendi. Çanta 55 yuvayı
tam dolduruyor; röle tarifle yapılır.

## 3. Dövüş (`4884551`)

`Shared/Combat` saf ve testli:
- **Bölge:** kafa küresi, kökün 1 stud altından aşağısı bacak, gerisi gövde. Kafaya ×2 zaten vardı.
- **Diz çökme / yere serilme:** tek vuruş max canın %40'ı → diz çöker, %50'si → yere serilir.
  0,5–1,8 sn boyunca yürümez ve vurmaz.
- **Bacak sakatlama:** şans = hasar oranı × 2. Sakat zombi ömrü boyunca %40 hızla sürünür.
- **Kafa koparma:** öldüren ve max canın en az %20'si olan kafa vuruşu, %30 tabanla kafayı koparır.
  Ceset başsız çizilir.
- **Güçlü vuruş (sağ tık, yakın dövüş):**
  - Hasar ×2 (yumruk, sopa, mızrak, kazma) ya da ×2,25 (kürek, yangın baltası); bloklara da işler.
  - 1,6× stamina harcar ve stamina yenilenmesini 1,5 sn durdurur.
  - Savruluş daha yavaş ve geriye çekişli; mızrak 3,6 m'ye ulaşır.
  - Taş baltada güçlü vuruş yok (tamir aleti).
  - Serbest fare kamerasında (V) sağ tık kamerayı da döndürdüğü için yalnızca kısa (0,25 sn) ve
    sürüklemesiz tık güçlü vuruştur. Play'de sürükleme stamina harcamadı (100); kısa tık 100 → 72,2.
  - Dokunmatikte yakın dövüş aletiyle Aim düğmesi "Power" olur. Gamepad: L2. Telefonda denenmedi.
- Can çubuğunun üstünde başlık çıkar: **Headshot**, **Knocked down**, **Crippled**, **Decapitated**.
- Kazık tuzağı bacağı vurur (sakatlayabilir).
- Duruş ve sakatlık snapshot'taki durum baytının boş bitlerinde taşınır; paket boyutu değişmedi.
  Diz çöken, yatan ve sürünen zombinin sunucu vuruş hacmi alçalır; kafa vuruşu çizilen kafada kalır.

Play ölçümleri:
- Güçlü baltayla kafaya 68/133 hasar → snapshot'ta duruş 2, yaklaşık 1,5 sn, sonra kovalama.
- Bacağa güçlü vuruş → "Crippled".
- Bozuk tipler, NaN ve 200'lük istek seli sunucuda hata üretmedi.

## 4. Zombi görünümü (`893947e`)

- İki özgün üretilmiş kafa mesh'i var: kel, yanağı yırtık olan ve saçı keçeleşmiş, gözü bulanık olan.
  Her zombi kimliğine göre birini alır; doku, zombinin ten rengine doğru ısıtılır.
- Kalabalığın yarısı yırtık ekose gömlek gövde alır; diğer yarısı renkli kutu gövdede kalır.
  Kapüşonlu gövde üretimi moderasyondan geçmedi.
- Kollar ve bacaklar kutu yerine silindir.
- Zombi başına parça sayısı 17'de kaldı.
- Play: 80 zombi, 70'i çizilirken Studio masaüstünde 60 FPS. Telefon kapısı değildir.

## 5. Elektrik, taret, çit (`bd4e7fd`)

Jeneratör artık yarıçaptaki lambaları kendiliğinden yakmıyor. 7DTD'deki gibi **kablo aleti** var.
**Kablo aleti nasıl kullanılır:**
1. Jeneratöre ya da röleye kullan: kablo başlar.
2. Hedefe kullan: kablo bağlanır.
3. Röle ya da çit direğine giren kablo oradan devam eder; zincir kurulabilir.
4. Seçili bloğa tekrar kullanırsan girişi kesilir.

Kurallar: her bloğun tek girişi olur, döngü olmaz, kablo en fazla 60 stud. Her saniye ağ çözülür;
jeneratör 50 W'ı bitene kadar besler. İstem metni yükü gösterir (ör. 15/50 W).

**Watt tüketimi:** lamba 5 W, röle 1 W, çit direği 5 W, taret 15 W.

**Otomatik taret:**
- Mermi: 9mm; menzil 30 m; mermi başına 32 hasar; atışlar arası 0,15 sn; dönüş yayı ±45°.
- Mermi elde tutulup tarete "kullan" ile yüklenir; kapasite 300.

**Pompalı taret:**
- Mermi: saçma fişeği; menzil 15 m; atış başına 8 × 9 saçma; atışlar arası 0,61 sn.

**İkisi için de:**
- Yayı ve görüş hattı içindeki en yakın zombiyi vurur; başlığını ona çevirir (özgün üretilmiş mesh).
- Silah sesi Gürültü olarak sayılır.
- E tuşuyla kapatılır; kapalı taret watt çekmez.

**Elektrikli çit:**
- Kabloyla birbirine bağlı iki çalışan direk arasındaki tele değen zombi 4 sn sersemler ve saniyede
  5 hasar alır (buffShocked).
- Her şok direkleri 2 aşındırır.

Tarifler eksik malzemeyi ikame eder:
- Dövme çelik yerine dövme demir.
- Yağ ve polimer yerine tutkal.
- Hareket sensörü yerine elektronik parça.
- Silah parçaları yerine boru silahın kendisi.

Play ölçümleri:
- Kablolu, yakıtlı, 30 mermili taret yayına giren zombiyi 4 atışta öldürdü.
- Jeneratör dört direği 20 W yükle besledi; B–C teli bir zombiyi şokladı (direkler 200 → 198).
- Sunucu konsolu temizdi.

Sınır:
- Zombi telin 2,1 stud'luk temas mesafesinin hemen dışında durup saldırabiliyor.
- Çit, zombinin içinden geçmek zorunda kalacağı yere kurulmalı (7DTD'de de öyle).

## 6. Evler: kırma, tamir, güçlendirme (`4791d17`)

`BuildingKit` her duvar çekirdeğine ve kaplamasına ortak bir `WallRun` numarası verir. Bir duvar
ilk vurulduğunda o duvar ve kaplamaları 4 stud'luk dilimlere bölünür (tembel bölme). Böylece haritanın
parça sayısı yalnızca oyuncunun çalıştığı yerde artar.

**Malzemeye göre can (bizim, 7DTD kademelerinden):**

| Malzeme | Can |
| --- | ---: |
| Alçıpan (iç bölme) | 300 |
| Ahşap | 500 |
| Tuğla | 1500 |
| Beton | 2500 |
| Metal | 3000 |

**Kırma:**
- Aletler duvarı blok gibi hasarlar.
- Kırılan dilim kırana malzeme bırakır: ahşap, küçük taş ya da hurda demir.
- Zemin kattaysa altındaki hücreler zombi yollarına açılır (`reopenArea`; zombinin delikten geçtiği
  Play'de ölçülmedi).

**Taş baltayla tamir ve güçlendirme:**
- Hasarlı dilimi tamir eder.
- Tam canda 3 vuruşla güçlendirir:
  1. 4 kereste: kalaslar çakılır, can ×2.
  2. 3 dövme demir: iki yüze çelik plaka, can ×3.

Play ölçümleri:
- 10,5 stud'luk ahşap duvar üç adet 500 canlı dilime bölündü.
- 11 yangın baltası vuruşu birini kırdı: temiz bir delik açıldı, havada kaplama kalmadı.
- Başka bir dilim 1000, sonra 1500 cana çıktı; plaka iki yüzde.

**Sınırlar:**
- Zombiler şimdilik ev duvarlarını kırmıyor; kapı boşluklarını kullanıyorlar. Kapı boşluğuna konan
  oyuncu blokları zaten kırılıyor.
- Bina içi navigasyon başlangıçta kurulur; kırılan duvardan yeni bir iç yol öğrenilmez, yalnızca
  dış zemin ızgarası açılır.
- Üst katlarda oyuncu bloğu hâlâ yok (`IndoorCells`).

## Kullanıcı testi

1. Studio'da **Play** → soldaki **Give test items** → **God mode**.
2. **Silahlar:**
   1. Tab ile çantayı aç, boru silahları toolbelt'e al.
   2. V ile birinci şahsa geç, R ile doldur, RMB ile nişan al.
   3. Gez ve arpacık namluya oturmalı, havada parça olmamalı.
3. **Aletler:** taş balta, kürek ve kazma koyu çakmaktaşı gibi görünmeli. Mızrak ucunda yıldız
   olmamalı; sopa konik olmalı.
4. **İnşa:**
   1. Wood Frame'i yerleştir: açık kereste iskeleti görünmeli.
   2. Taş baltayla 3 vur: opak ahşap bloğa dönmeli.
5. **Dövüş:**
   1. **Spawn 1** ve **Make noise**.
   2. Sopa ya da baltayla sol tık: normal vuruş.
   3. Sağ tık: güçlü vuruş; daha yavaş ve daha çok stamina harcar.
   4. Kafaya vur: çubukta kırmızı "Headshot".
   5. Güçlü kafa vuruşu zombiyi yere serer; bacak vuruşu "Crippled" verip zombiyi süründürebilir.
6. **Elektrik:**
   1. Generator yerleştir.
   2. Gas Can elde, jeneratöre sol tık (yakıt), E ile çalıştır.
   3. Auto Turret yerleştir; taret senden uzağa bakar.
   4. Wire Tool elde: önce jeneratöre, sonra tarete sol tık.
   5. 9mm Ammo elde, tarete sol tık (yükle).
   6. Taretin önüne bir zombi getir: ateş etmeli.
7. **Çit:**
   1. İki Electric Fence Post koy.
   2. Kablo aleti: jeneratör → direk A → direk B.
   3. Zombi tele değince durmalı ve can kaybetmeli.
8. **Ev:**
   1. Bir evin dış duvarına yangın baltasıyla vur: dilim kırılır, delik açılır.
   2. Taş balta ve çantada kereste varken sağlam bir dilime 3 vur: kalaslar çakılır.
   3. Dövme demir varken 3 vur daha: çelik plaka.
