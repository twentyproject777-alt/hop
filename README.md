# GoldAutoScalp v2.00 — MT5, tanpa preset

**Gunakan file baru `mt5/Experts/GoldAutoScalp.mq5`, bukan GoldTrendSweep.** Satu file, tidak perlu `.set` atau header custom. Pengaturan bawaan lengkap; akun real diblokir secara default. Ini EA eksperimental, bukan jaminan profit, win rate >50%, atau drawdown pasti di bawah10%.

## Mengapa dibuat ulang

Journal v1.30 menunjukkan 24 sweep dan 10 konfirmasi, tetapi enam kandidat ditolak filter ruang RR dan satu oleh sizing; tidak ada order terkirim. Versi2 mengganti kombinasi SMC/pivot/retracement tersebut dengan **trend-pullback + RSI8**, mengirim **market order** setelah sinyal candle tertutup. RR2 berarti target dua kali jarak SL, bukan veto berdasarkan setiap pivot historis. **SMC/ICT bukan lagi syarat wajib** pada strategi baru ini.

Tidak ada preset/profile, jam server08–18, H1EMA200, sweep/zone wajib, pending limit yang harus retest, atau ketergantungan expiration broker. Ini perubahan strategi yang nyata, bukan klaim bahwa filter lama adalah kesalahan eksekusi MT5.

## Cara memakai — tidak perlu mengubah Inputs

1. Unduh **raw** `mt5/Experts/GoldAutoScalp.mq5` dari GitHub. MT5 → **File → Open Data Folder** → simpan di `MQL5/Experts/`.
2. Buka **GoldAutoScalp.mq5** di MetaEditor dan compile **F7**. Pastikan file yang dipilih bernama **GoldAutoScalp**, bukan GoldTrendSweep/GoldRiskMath.
3. Strategy Tester → pilih **GoldAutoScalp**, simbol XAUUSD/GOLD broker, timeframe M5, deposit **500 USD**, dan **Every tick based on real ticks**. Pilih leverage broker tujuan.
4. **Jangan Load preset lama.** EA baru memakai semua default di kode. Jika pernah mengubah Inputs GoldAutoScalp, gunakan Reset untuk kembali ke default.
5. Start. Journal harus memuat **`GoldAutoScalp v2.00 READY — NO PRESET REQUIRED`**.

File memakai hanya `Trade/Trade.mqh` bawaan MT5. Semua fungsi custom ditanamkan dalam `.mq5` oleh script build. Nama file dan magic baru memisahkan EA ini dari input/state lama. **Hentikan EA lama sebelum menjalankan EA baru pada simbol yang sama.** Jangan mengoperasikan strategi ini dari dua terminal/VPS sekaligus.

## Aturan entry

- **Arah M15:** EMA20 > EMA50 dan close terakhir > EMA50 untuk buy; kebalikannya untuk sell.
- **M5 buy:** candle tertutup bullish, close di atas EMA20, RSI8 >50 dan meningkat. Selain itu minimal salah satu: low menyentuh/melewati EMA20, close sebelumnya berada di bawah/tepat EMA20 sebelumnya, atau RSI sebelumnya≤50.
- **M5 sell:** simetris—candle bearish di bawah EMA20, RSI8 <50 dan menurun, serta pullback EMA atau pemulihan RSI ke bawah50.
- Keputusan hanya pada candle M5 baru menggunakan candle tertutup `[1]`/`[2]`; satu percobaan per bar, tidak mengejar sinyal lama di tengah bar.
- **Market order** langsung setelah sinyal lolos guard. Tidak entry setiap candle dan tidak ada order dummy untuk mempercantik jumlah transaksi.
- SL awal: **1 ATR(14) M5** dari Bid untuk buy / Ask untuk sell, diperlebar bila stop level broker memerlukan. Lot dihitung setelah SL, bukan SL dipersempit agar lot besar muat.
- TP awal minimal **2R**. Setelah fill, TP disesuaikan terhadap harga fill aktual bila broker mengizinkan jarak modifikasinya. SL tidak diperlebar setelah entry. BE menggunakan initialR aktual tersebut.

Sinyal yang valid dapat tetap ditolak ketika broker tidak mengizinkan trade, minimum lot terlalu besar, margin tidak cukup, spread melebar, atau guard aktif. **Tidak mungkin menjamin entry pada semua data/broker tanpa mengabaikan pembatas risiko.**

## Money management bawaan untuk pengujian $500

| Komponen | Default |
| --- | --- |
| Risiko | Maksimal **2% ekuitas** ($10 saat ekuitas$500), dibatasi juga sisa budget harian/mingguan/DD |
| Volume | Auto-lot, dibulatkan turun sesuai step; maksimal0,10 lot. Tidak memaksakan0,05/0,10 |
| Komisi/slippage | Estimasi7 unit mata uang akun/lot round-trip dan cadangan slippage30 point pada **entry serta exit** |
| Spread | Maksimal0,25ATR M5; tidak lagi mensyaratkan seluruh biaya≤10% risiko SL |
| Margin | Maksimal25% free margin; lot diturunkan bila perlu, bukan otomatis menolak semua ukuran |
| TP / BE | TP2R; pada executable quote1R, SL menuju BE berbuffer estimasi komisi/swap+2tick |
| Eksposur | Satu posisi/order pada simbol; tidak menambah posisi manual/EA lain pada simbol yang sama |
| Frekuensi | Maksimal3 order entry terisi/hari server, partial fill satu order tidak dihitung berulang |
| Batas posisi | Tutup setelah60menit atau jika proteksi awal hilang/tidak dapat dipulihkan |
| Harian/mingguan | Kerugian ekuitas3%/6% → upayakan tutup eksposur EA dan kunci sampai periode berikutnya |
| Drawdown | DD5% → risiko separuh; DD8% → pause entry permanen; DD10% → upayakan tutup dan kunci |

Risiko2% cukup agresif untuk akun kecil. Jika SL minimum membuat0,01lot melebihi budget, EA **tetap tidak entry** dan menampilkan `GAS_RISK` beserta risiko minimum lot. Stop bisa tereksekusi lebih buruk saat gap/slippage; BE dan cap drawdown bukan jaminan kerugian nol atau batas absolut. Estimasi komisi7 adalah placeholder mata uang akun, bukan selalu USD dan bukan spesifikasi semua broker. Untuk live, verifikasi biaya, contract size, digit, leverage, dan gunakan demo dahulu.

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
- `GAS_NO_SIGNAL`: candle belum memenuhi trend/pullback/RSI, bukan error broker.
- `GAS_RISK`, `GAS_MARGIN`, `GAS_SPREAD`, `GAS_NOT_ALLOWED`, `GAS_BAD_DATA`, `GAS_REJECTED`: alasan gate/penolakan yang berbeda, bukan semuanya dilabeli gagal entry.
- `GAS2 SUMMARY`: jumlah bar/sinyal/order terkirim/fill dan penolakan. `response_deals` hanya deal langsung dalam respons OrderSend; `filled_entry_orders` menghitung history dan deduplikasi partial fill.

## Verifikasi yang tersedia

**Status saat ini:** unit/pipeline tests lulus; kompilasi MetaEditor dan fill Strategy Tester belum terverifikasi. Wine 9/11 gagal pada runtime sandbox sebelum compiler dapat dijalankan. [Perintah uji dan batasan lengkap](docs/verification.md).

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
