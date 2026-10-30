# Proje talimatları

Roblox co-op zombi survival oyunu (Rojo, Luau `--!strict`). Kullanıcı test eder ve son kararı verir;
kodu Claude yazar.

## İlk iş

Yeni oturumda kod yazmadan önce sırayla oku:
1. [docs/HANDOFF.md](docs/HANDOFF.md): geçmiş, mevcut durum, Studio MCP çalışma yöntemi, tuzaklar.
2. [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md): sıradaki işler ve kullanıcı kararı bekleyen sorular.
3. [docs/PLAN.md](docs/PLAN.md): tasarım kararları. Kod ile plan çelişirse plan geçerli.

## Kurallar

- **Dil:** Kullanıcıyla Türkçe konuş. Kod, isimler, yorumlar ve UI metinleri İngilizce.
- **Metin:** UI metni yalnızca `src/shared/Localization.luau` içinden gelir.
- **Sayılar:** Denge sayıları yalnızca `src/shared/Config.luau` içinde tutulur.
- **Güvenlik:** Sunucu otoriterdir. Her client→server remote tip, NaN/sonsuz değer, menzil, sahiplik
  ve hız sınırıyla doğrulanır.
- **Commit:** Her mantıksal adım ayrı commit'lenir. Mesaj şu satırla biter:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- **Test adımları:** Test gereken her adımdan sonra kullanıcıya tam test adımlarını yaz.
- **Doğrulama:** Studio MCP ile yap: testler, Play konsolu, görsel işlerde ekran görüntüsü.
  Ölçmeden "düzeldi" deme.
- **Belirsiz kararlar:** Önce PLAN.md'ye bak; orada yoksa kullanıcıya sor.
- **Creator Store:** Ücretsiz varlıkların içindeki tüm script'leri sil; yalnızca mesh, doku ve ses al.
- **Telefon kapısı:** "80 zombiyle orta seviye telefonda 30 FPS" sağlanmadan yeni sistemlere geçme.
  Kullanıcı ertelemeye karar verebilir; durum NEXT_STEPS.md'de.
- **Oturum sonu:**
  - Studio Edit modunda; Workspace'te yalnızca `Camera` ve `Terrain`.
  - Geçici HTTP sunucusu kapalı.
  - Her şey commit edilmiş.
  - Durum değiştiyse HANDOFF.md ve NEXT_STEPS.md güncellenmiş.
