# Silah ve alet kullanımı — 1 Kasım 2026

Kullanıcı isteğiyle 7 Days to Die referanslı elde tutuş, nişan, doldurma ve geri bildirim yenilendi.
Mevcut hasar, menzil, şarjör kapasitesi ve doldurma süreleri korundu.

## Oynanış

- Yeni silah boş gelir. **R** / gamepad **B** / dokunmatik **Reload** ile doldurulur.
  Boşken ateşe basmak ve son mermiyi atmak da yedek varsa doldurmayı başlatır.
- Mermi her silahın kendi envanter yığınındadır (`loadedRounds`, `loadedAmmo`). Aynı tür iki
  tabancanın mermileri ayrıdır; taşıma, sandık, yere atma/loot ve tamir iadesi bu bilgiyi korur.
- Sunucu doldurma bitince yalnızca eksik miktarı yedekten alır. Yarım şarjör doldurulabilir.
  Silah değişimi ve ölüm doldurmayı iptal eder; doldururken ateş kabul edilmez.
- Makineli silah basılı tutulunca otomatik ateş eder. Tabanca, tüfek ve pompalı her basışta tek atar.
- **RMB** / **L2** nişan alır. Görüş açısı yumuşakça 70'ten 50'ye iner; yürüyüş hızı 16'dan
  10,4 stud/sn'ye düşer ve koşu durur. Hareket ve havada olma sunucuda saçılmayı artırır.
- Mermi paneli gerçek şarjör / yedek miktarını, cephane türünü, AUTO/SEMI, doldurma süresini ve
  ilerlemeyi gösterir. Toolbelt sayıları da sunucu envanterini kullanır.
- Silah değiştirince 0,32 sn hazırlık süresi vardır. Geri tepme silaha göre değişir; nişangâh
  açılıp kapanır, doğrulanan zombi isabetinde kısa işaret gösterilir. Namlu parlaması eldeki namludadır.
- **V** kamera modlarını değiştirir. Kilitli farede sistem imleci gizlenir; çanta/Alt ile geri gelir.
- Yakıt ekleme **T**'ye taşındı; **F** ateşi yakıp söndürür. Böylece R doldurmayla çakışmaz.

## Görsel uygulama

`WeaponController` güvenilir `WeaponState` paketlerini, doldurma girdilerini, HUD'u, nişan geçişini
ve sönümlenen kamera tepmesini yönetir. Sunucu `RangedService` mühimmatı ve tüm zaman sınırlarını yönetir.

`HeldItems` ortak SupportGrip, Sight ve Muzzle işaretleri ile açık arka gez/ön arpacık üretir.
`ViewmodelController` inceltilmiş kollara, kumaş kolluklara, eldiven parmaklarına, destek eline,
silaha göre doldurma el hareketine, daha az nişan salınımına ve koşarken/duvar yakınında silah
indirme-kaldırmaya sahiptir. Üçüncü şahıs `EquipmentPoseController`, R15 kol ölçülerinden iki
kemikli çözüm hesaplar; Motor6D ve AnimationConstraint eklemlerini destekler ve yakın dövüş
animasyonuna geçerken kendi pozunu kaldırır.

## Studio doğrulaması

- **90 test geçti, 0 hata.** Beş yeni test: kısmi doldurma, zaman sınırları, iki ayrı silahın mermisi,
  sandık transferi ve kaldırma/iade sırasında mermilerin korunması.
- Gerçek R girdisi: boş tabanca 6/4'e doldu. Tetik 1,3 sn basılıyken yalnızca bir atış: 5/4.
- Yarım tabanca şarjöründe 3/4 → doldurma → 6/1; bir atış → 5/1. Aynı tür diğer tabancaya
  doldururken geçiş ilk tabancanın mermisini ve yedeği korudu.
- Makineli: R sonrası 15/10, basılı ateşle 8 kabul edilmiş atış sonrası 7/10. Slot taşıma ve
  doldurmayı iptal etme normal sunucu Script'i üzerinden assert edildi: 7 mermi ve 10 yedek korundu.
- Pompalı bir fişek karşılığında 10 saçma üretti; ikinci fişek otomatik dolduruldu.
- Geçersiz doldurma istekleri ve doldurma esnasında atış mühimmat üretmedi/tüketmedi.
- Doldurma başlarken sunucu karakteri öldürdüğünde 2,5 sn sonra şarjör 0, yedek 10, doldurma
  zamanı 0 kaldı. 20 yoğun AimIntent isteği sonrası bırakma: nişan false ve hız 16.
- Nişanda FOV 50, hız 10,4; bırakınca FOV 70, hız 16 ölçüldü.
- 812×675 test görünümünde makineli Sight noktası (405,34; 337,49), ekran merkezi (406; 337,5):
  sabit nişanda 1 pikselden az sapma. Mermi paneli görev panelinin 12 piksel altında.
- Test avatarında destek eli hedef hatası tabancada 0,000011, makineli ve baltada 0,000031 stud'dan
  az. Balta savruluşu sonrası destek pozuna dönüş denetlendi. Son oynanış turunun istemci konsolunda
  çalışma zamanı hatası yoktu.

## Sınırlar ve sonraki kontrol

Bu, kodla üretilen bir animasyon katmanıdır. Mesh içindeki silindir, sürgü ve şarjör ayrı mekanik
parçalara ayrılmadı; birebir mekanik sökme/takma animasyonu henüz yok. Sesler önceki kullanıcı kararı
gereği seçilmedi; atış ses kancaları hazır. R6 üçüncü şahıs kol çözümünü kullanmaz. Mobil ve farklı
avatar oranları için fiziksel cihaz testi, çok oyunculu/gecikmeli bağlantı testi ve 80 zombili telefon
FPS kapısı yapılmadı. StyLua/Selene yürütücüleri bu ortamda bulunmadı; Studio derleme ve oynanış
testleri kullanıldı. Verinoda bu Luau dosyalarında sembol çözümleyemedi; güvenlik onayı olarak alınmadı.

Kullanıcı testi: Studio **Play** → debug **Give test items** → silahı seç → **V** ile birinci şahıs →
**R** ile doldur → **RMB** ile nişan al → ateş et → eksik şarjörde tekrar R → doldururken başka
slota geç → ilk silaha dön ve sayacı kontrol et. Makineliyi basılı, tabancayı tek tek dene.
Ardından balta/kazma/küreği seçip savruluşu ve iki el tutuşunu kontrol et.
