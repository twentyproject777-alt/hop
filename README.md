# GoldAutoScalp v2.10 — trend scalping MT5, tanpa preset

**Gunakan file baru `mt5/Experts/GoldAutoScalp.mq5`, bukan GoldTrendSweep.** Satu file, tidak perlu `.set` atau header custom. Pengaturan bawaan lengkap; akun real diblokir secara default. Ini EA eksperimental, bukan jaminan profit, win rate >50%, atau drawdown pasti di bawah10%.

## Perbaikan v2.10

Pengguna melaporkan v2.00 sudah entry, tetapi equity curve menurun dan frekuensi rendah. Grafik tanpa report/deals tidak menunjukkan win rate, penyebab setiap exit, spread aktual, atau apakah loss guard menghentikan entry. Karena itu v2.10 adalah **kandidat perbaikan yang perlu diuji**, bukan strategi yang sudah terbukti profitable.

| Komponen | v2.00 | v2.10 |
| --- | --- | --- |
| Trend M15 | Posisi EMA20/50 dan close terhadap EMA50 | Close searah EMA20/50, slope EMA20, minimum jarak EMA relatif ATR |
| Peluang M5 | Pullback EMA20/pemulihan RSI50 | Pullback dangkal EMA9/20 **atau breakout continuation**, tetap searah trend |
| Batas harian | 3 filled entry order | **12**; batas kesempatan, bukan target wajib |
| Sizing normal | Mendekati plafon 2% | Target separuh budget tersedia, normalnya **1%**, plafon tetap 2% |
| Stop | ATR saja | Di luar wick dua candle + buffer, dengan ATR sebagai jarak minimum |
| Evaluasi | Summary order/risk | Tambahan tipe setup, alasan blok, win rate/PF/DD dari statistik tester |

Trend filter yang lebih ketat dapat menolak kandidat lama. Tambahan setup dan cap lebih besar **tidak menjamin jumlah fill lebih banyak** pada setiap periode. Menambah entry pada strategi dengan expectancy negatif justru mempercepat rugi. Tidak ada martingale, penurunan RR untuk mempercantik win rate, atau penghapusan lock DD.

Market executor v2.00 dipertahankan. Tidak ada preset/profile, jam server tetap, H1EMA200, sweep wajib, pending-limit retest, atau ketergantungan expiration broker. SMC/ICT bukan syarat wajib strategi ini.

## Cara memakai — tidak perlu mengubah Inputs

1. Unduh **raw** `mt5/Experts/GoldAutoScalp.mq5` dari GitHub. MT5 → **File → Open Data Folder** → simpan di `MQL5/Experts/`.
2. Buka **GoldAutoScalp.mq5** di MetaEditor dan compile **F7**. Pastikan file yang dipilih bernama **GoldAutoScalp**, bukan GoldTrendSweep/GoldRiskMath.
3. Strategy Tester → pilih **GoldAutoScalp**, simbol XAUUSD/GOLD broker, timeframe M5, deposit **500 USD**, dan **Every tick based on real ticks**. Pilih leverage broker tujuan.
4. **Jangan Load preset lama.** EA baru memakai semua default di kode. Jika pernah mengubah Inputs GoldAutoScalp, gunakan Reset untuk kembali ke default.
5. Start. Journal harus memuat **`GoldAutoScalp v2.10 READY — NO PRESET REQUIRED`**, `risk_preferred=1.00%`, `risk_cap=2.00%`, dan `max_entries_day=12` pada default.

File memakai hanya `Trade/Trade.mqh` bawaan MT5. Semua fungsi custom ditanamkan dalam `.mq5` oleh script build. Nama file dan magic memisahkan EA ini dari GoldTrendSweep v1.x. **Hentikan EA lama sebelum menjalankan EA baru pada simbol yang sama.** Jangan mengoperasikan strategi ini dari dua terminal/VPS sekaligus.

Saat upgrade v2.00 → v2.10, nama file, magic, dan state risiko **sengaja tetap sama**. Lock DD akun demo/live tidak dihapus untuk memaksa entry. Tester memulai pass baru yang terisolasi. Tidak perlu preset; Inputs lama yang pernah diubah dapat dikembalikan lewat Reset.

## Aturan entry

- **Trend M15 buy:** close `[1]` > EMA20 `[1]` > EMA50 `[1]`; EMA20 `[1]` > EMA20 `[4]`. Sell simetris. Jarak EMA20–EMA50 harus minimal **0,15 ATR14 M15**. Slope adalah perubahan arah selama tiga candle tertutup, bukan prediksi atau jaminan bebas sideways.
- **Arah lokal M5:** buy membutuhkan EMA9 > EMA20, candle bullish ditutup di atas EMA9, RSI8 >50 dan meningkat. Sell membutuhkan kondisi kebalikan. RSI buy >75 / sell <25 ditolak agar tidak mengejar ekstrem.
- **Pullback:** low buy menyentuh zona EMA9 +0,1 ATR atau close sebelumnya berada di bawah/tepat EMA9 sebelumnya; kemudian close kembali di atas EMA9. Sell simetris. Pada candle sinyal buy, low yang mencapai EMA20 otomatis melewati zona EMA9 ketika EMA9 > EMA20; aturan sell simetris.
- **Breakout continuation:** bila bukan pullback, buy saat close `[1]` melampaui high tertinggi **tiga candle sebelumnya `[2..4]`**; sell di bawah low terendahnya. Candle berjalan tidak dipakai sebagai level breakout.
- **Tidak mengejar harga:** jarak close ke EMA9 maksimal 1 ATR M5; range candle maksimal 2,5 ATR. Bid saat pengiriman tidak boleh bergeser lebih dari 0,25 ATR dari close sinyal, dan harus masih di sisi EMA9 yang sesuai.
- Quote-movement diukur **Bid terhadap close chart Bid** untuk kedua arah; spread dibatasi terpisah maksimal 0,25 ATR. Ini bukan batas total Ask terhadap close: quoted Ask buy dapat berjarak sampai 0,5 ATR saat kedua batas terpenuhi. Risiko/SL/TP buy tetap dihitung dari Ask, sell dari Bid; slippage fill masih dapat memperburuknya.
- Keputusan hanya pada candle M5 baru menggunakan candle tertutup `[1]`/`[2]`; satu percobaan per bar, tidak mengejar sinyal lama di tengah bar.
- **Market order** langsung setelah sinyal lolos guard. Tidak entry setiap candle dan tidak ada order dummy untuk mempercantik jumlah transaksi.
- SL awal buy berada di bawah low minimum candle `[1..2]` −0,1 ATR; sell di atas high maksimum `[1..2]` +spread saat ini +0,1 ATR. Gunakan yang **lebih jauh** antara stop struktural, minimum 1 ATR, dan stop level broker. Bila jarak stop (di luar spread) melebihi **3 ATR +1 tick**, kandidat ditolak; stop tidak dipersempit agar lot muat. Kandidat yang lolos tetap harus memenuhi sizing.
- TP awal minimal **2R**. Setelah fill, TP disesuaikan terhadap harga fill aktual bila broker mengizinkan jarak modifikasinya. SL tidak diperlebar setelah entry. BE menggunakan initialR aktual tersebut.

Sinyal yang valid dapat tetap ditolak ketika broker tidak mengizinkan trade, minimum lot terlalu besar, margin tidak cukup, spread melebar, atau guard aktif. **Tidak mungkin menjamin entry pada semua data/broker tanpa mengabaikan pembatas risiko.**

Threshold di atas adalah default desain, **belum dioptimasi atau dibuktikan memberi edge pada broker pengguna**. Tidak ada cooldown tambahan: setelah flat, EA boleh mengevaluasi sinyal baru pada bar berikutnya, tetap maksimal satu percobaan per bar dan tanpa stacking posisi.

Jika satu candle memenuhi pullback dan breakout sekaligus, **pullback diprioritaskan**. Counter kedua family saling eksklusif supaya kandidat yang sama tidak dihitung dua kali.

## Money management bawaan untuk pengujian $500

| Komponen | Default |
| --- | --- |
| Risiko | `InpRiskPercent` tetap **plafon 2%** ($10 pada $500), dipotong sisa budget harian/mingguan/DD; sizing normal memakai **separuh budget** (biasanya $5 / 1%) |
| Minimum-lot bridge | Hanya minimum lot broker boleh melampaui target separuh budget, **tidak pernah** melebihi plafon yang sudah dipotong seluruh guard; tercatat `minlot_bridge=true` |
| Volume | Auto-lot, dibulatkan turun sesuai step; maksimal0,10 lot. Tidak memaksakan0,05/0,10 |
| Komisi/slippage | Estimasi7 unit mata uang akun/lot round-trip dan cadangan slippage30 point pada **entry serta exit** |
| Spread | Maksimal0,25ATR M5; tidak lagi mensyaratkan seluruh biaya≤10% risiko SL |
| Margin | Maksimal25% free margin; lot diturunkan bila perlu, bukan otomatis menolak semua ukuran |
| TP / BE | TP2R; pada executable quote1R, SL menuju BE berbuffer estimasi komisi/swap+2tick |
| Eksposur | Satu posisi/order pada simbol; tidak menambah posisi manual/EA lain pada simbol yang sama |
| Frekuensi | Default maksimal **12** order entry terisi/hari server (`InpMaxEntriesPerDay`, boleh diturunkan ke1–12), partial fill satu order tidak dihitung berulang; tidak menjamin 12 trade/hari |
| Batas posisi | Tutup setelah60menit atau jika proteksi awal hilang/tidak dapat dipulihkan |
| Harian/mingguan | Kerugian ekuitas3%/6% → upayakan tutup eksposur EA dan kunci sampai periode berikutnya |
| Drawdown | DD5% → risiko separuh; DD8% → pause entry permanen; DD10% → upayakan tutup dan kunci |

Risiko 2% cukup agresif untuk akun kecil. Contoh: target $5, plafon tersisa $10, minimum lot berisiko $6 → hanya minimum lot dapat dipakai; bukan menaikkan volume hingga $10. Bila sisa batas harian tinggal $4, kandidat $6 tersebut **ditolak**. Pada DD5%, plafon nominal turun menjadi 1% dan target normal 0,5%, sebelum pembatas budget lainnya. `GAS_RISK` menampilkan risiko minimum lot, bukan lot yang dipaksakan.

Stop bisa tereksekusi lebih buruk saat gap/slippage; BE dan cap drawdown bukan jaminan kerugian nol atau batas absolut. Estimasi komisi7 adalah placeholder mata uang akun, bukan selalu USD dan bukan spesifikasi semua broker. Untuk live, verifikasi biaya, contract size, digit, leverage, dan gunakan demo dahulu.

Tidak ada grid/martingale/averaging down. Guard memakai ekuitas **seluruh akun**, tetapi hanya menutup posisi/order milik EA ini. Gunakan akun khusus; pada akun netting, transaksi lain di simbol sama dapat mencampur posisi. Hindari deposit/withdrawal saat run karena baseline tidak menyesuaikan arus dana otomatis.

State risiko disimpan dalam Terminal Global Variables `GAS2.<login>.26092002.*`, tidak direset oleh restart biasa. Tester mengisolasi state per pass. Daily/weekly baseline adalah ekuitas saat event pertama periode, peak adalah yang teramati sejak pemasangan. Terminal mati tidak bisa merekonstruksi equity yang terlewat. Lock DD8/10 hanya boleh direset setelah evaluasi dan akun flat; menghapus EA tidak menghapus lock atau otomatis menutup posisi. Pemindahan terminal/VPS tidak membawa state secara otomatis.

SL/TP yang telah diterima broker tetap berada di server. BE, rekalkulasi target terhadap fill, time exit, dan equity guard memerlukan EA berjalan, koneksi, serta izin trading aktif; EA tidak bisa melewati AutoTrading yang dinonaktifkan. Jika proteksi fill hilang, EA mencoba memulihkan SL/TP dari permintaan/history asli, atau menutup darurat bila pemulihan tidak aman/gagal; keduanya bisa gagal saat broker/koneksi bermasalah. Modifikasi gagal dibatasi retry5detik, close2detik. BE memakai estimasi biaya, bukan jaminan hasil net nol.

Permintaan market yang diterima atau berstatus ambigu (timeout/koneksi putus) memblokir entry berikutnya sampai posisi/history mengonfirmasi hasilnya. Jika `awaitRequest` tetap aktif tanpa history yang bisa direkonsiliasi, konfirmasikan status order dengan broker sebelum reset; EA tidak mengirim ulang secara buta. Target2R adalah rasio jarak harga awal, bukan jaminan RR net setelah seluruh biaya/slippage. Trigger BE1R dilatch; modifikasi dapat tertunda oleh stop/freeze level broker.

## Jam dan berita

Tidak ada filter jam tetap: EA mengevaluasi quote broker pada semua sesi yang tersedia, dengan spread/risk guard. Ini tidak berarti broker menerima order ketika pasar tutup. Market permission diperiksa dan `OrderCheck`/retcode broker dilaporkan.

**Tester otomatis menjalankan baseline tanpa berita**, sebab kalender MT5 tidak tersedia di tester. Journal selalu memperingatkan hal ini; hasilnya tidak identik dengan strategi live berfilter berita. Demo/live default memblokir entry ±30menit dari berita USD high impact dan fail-closed jika API kalender gagal. Posisi berjalan tetap dikelola sebelum pemeriksaan berita. Berita tak terjadwal tidak terdeteksi.

## Journal yang perlu diperiksa

- `GAS2 MARKET SEND ... retcode=... deal=... order=...`: permintaan market dikirim; retcode menentukan penerimaan. `PLACED` berarti diterima, belum tentu ada fill.
- `GAS2 ORDER CHECK FAILED`: broker menolak sebelum pengiriman; deskripsi dan kode dicetak.
- `GAS_SENT`: callback pengiriman menerima respons sukses; lihat `filled_entry_orders` untuk bukti history fill.
- `GAS_NO_TREND`: M15 belum searah/slope tidak sesuai/jarak EMA terlalu kecil. `GAS_NO_SIGNAL`: M5 belum memenuhi alignment, momentum atau pola entry. Bukan error broker.
- `GAS_QUALITY`: candle/ekstensi/RSI melewati guard; `GAS_ENTRY_MOVED`: quote sudah terlalu bergeser atau tidak lagi searah EMA9.
- `GAS_WIDE_STOP`: wick/stop level broker membuat stop terlalu jauh untuk batas scalping; tidak diakali dengan stop di dalam wick.
- `GAS_RISK`, `GAS_MARGIN`, `GAS_SPREAD`, `GAS_NOT_ALLOWED`, `GAS_BAD_DATA`, `GAS_REJECTED`: alasan gate/penolakan yang berbeda, bukan semuanya dilabeli gagal entry.
- `GAS2 SUMMARY`: jumlah bar/sinyal/order terkirim/fill dan penolakan. `response_deals` hanya deal langsung dalam respons OrderSend; `filled_entry_orders` menghitung history dan deduplikasi partial fill.
- `GAS2 SIGNALS`: kandidat pullback/breakout, no-trend/no-setup, quality, quote-moved, dan entry minimum-lot bridge.
- `GAS2 BLOCKS`: jumlah bar tertahan daily/weekly/hard lock, DD pause, cap harian, exposure, request ambigu, news dan permission. **Flat di akhir grafik belum tentu sinyal habis**; periksa apakah guard aktif sebelum mengubah strategi.
- `GAS2 RISK STATE`: peak/equity/DD saat ini dan flag day/week/DD-pause/hard lock (0/1), bukan jumlah trade.
- `GAS2 TESTER`: jumlah trade, win/loss, win rate, net profit, PF dan maximum equity DD dari **statistik MT5**, bukan nilai simulasi atau target. `PF=n/a` bila belum ada losing trade.

## Verifikasi yang tersedia

**Status saat ini:** pengguna mengonfirmasi entry v2.00; hasilnya belum layak dianggap profitable. Unit/pipeline tests v2.10 lulus, tetapi compile/fill/performance v2.10 di MT5 belum terverifikasi. Wine 9/11 gagal pada runtime sandbox sebelum compiler dapat dijalankan. [Perintah uji, status dan rencana A/B](docs/verification.md).

Logika sinyal → harga SL/TP → sizing risiko/margin → **pemanggilan market order** berada dalam `GoldAutoScalpCore.mqh` yang digunakan langsung oleh EA. Native test menjalankannya dengan test-broker, termasuk jalur buy/sell, broker reject, permission, spread, minimum lot, penurunan lot karena margin, serta RR/BE.

Pada replay **sintetis** 300 bar, pipeline menghasilkan20 pengiriman/fill di test-broker (10buy/10sell). **Ini bukan data broker pengguna, bukan backtest MT5, bukan 20 trade nyata, dan bukan bukti profit.** Test-broker tidak memodelkan tick, delay, latensi, trade lifecycle lengkap, atau persaingan event terminal.

```sh
python3 scripts/build_auto_scalp.py --check
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py' -v
mkdir -p /tmp/goldtrend-tests
g++ -std=c++17 -Wall -Wextra -Werror -pedantic -fsanitize=address,undefined \
  tests/auto_scalp_test.cpp -o /tmp/goldtrend-tests/auto_scalp_test
/tmp/goldtrend-tests/auto_scalp_test
```

Sebelum live: compile MetaEditor, visual backtest real ticks, verifikasi broker fill+SL/TP, BE sebelum/sesudah1R, restart, freeze/stop level, partial fill/reject, serta guard drawdown. Lanjutkan out-of-sample dan forward demo. Bertambahnya jumlah trade tidak membuktikan strategi menguntungkan. Status kompilasi/native test dicatat terpisah dari unit test; jangan menyamakan lulus C++ dengan lulus MQL5.

## Pengembangan dan arsip

- Edit `GoldAutoScalpCore.mqh`/`GoldRiskMath.mqh`, lalu jalankan `python3 scripts/build_auto_scalp.py` untuk menanamkan perubahan ke file EA.
- [GoldTrendSweep v1.x dan preset lamanya](docs/GoldTrendSweep-legacy.md) disimpan sebagai pembanding/arsip, bukan bagian instalasi GoldAutoScalp.
- API resmi: [OrderSend](https://www.mql5.com/en/docs/trading/ordersend), [OrderCheck](https://www.mql5.com/en/docs/trading/ordercheck), [OrderCalcProfit](https://www.mql5.com/en/docs/trading/ordercalcprofit), [kalender dan batas tester](https://www.mql5.com/en/book/advanced/calendar).
