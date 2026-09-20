# GoldTrendSweep — versi lama v1.x (arsip)

Untuk versi baru tanpa preset, gunakan `mt5/Experts/GoldAutoScalp.mq5` dan panduan di README utama. Dokumen ini menyimpan aturan dan hasil diagnosis versi lama; jangan memakai preset lama untuk EA baru.

EA eksperimental: tren H1/M15, liquidity sweep M5, konfirmasi harga dan RSI(8), entry retracement, TP awal **2R**, serta **break-even berbuffer biaya setelah mencapai 1R**. Bukan jaminan profit, win rate >50%, atau drawdown maksimal tertentu. Screenshot pengguna menunjukkan v1.20 menghasilkan nol transaksi; v1.30 belum diuji melalui MT5 di workspace ini.

## v1.30 — revisi sinyal berdasarkan Journal pengguna

Journal v1.20 menunjukkan **1.666 bar dievaluasi, 479 aligned, 3 sweep, 1 structure break, dan 1 skip RR**, dengan skip biaya/sizing/margin semuanya 0. Artinya bottleneck run tersebut berada di pembentukan setup dan ruang target, **bukan penolakan lot atau margin**. Pesan di luar sesi pada akhir hari tidak menjelaskan seluruh run: 1.666 bar sudah lolos gate tersebut. Jam 08:00–18:00 server tetap dipertahankan, bukan diubah menjadi trading sembarang waktu.

Karena itu v1.30 menyediakan profil **Balanced** sebagai default dan tetap mempertahankan **Strict** untuk perbandingan. Ini **perubahan definisi strategi**, bukan klaim bahwa aturan sebelumnya mengalami kegagalan eksekusi MT5.

| Aturan | Strict (`InpSignalProfile=0`) | Balanced (`InpSignalProfile=1`, default baru) |
| --- | --- | --- |
| Arah H1 | Close vs EMA200 dan arah EMA | Sama |
| Arah M15 | Dua pivot high/low sama-sama naik atau turun | Close vs EMA50 dan slope EMA50 selaras H1 |
| Zona ekstrem/wick sweep M5 | Pivot support/resistance M15 ±0,5 ATR **M5** | EMA50 M15 ±1 ATR **M15** |
| Likuiditas yang disapu | Pivot M5 yang sudah terkonfirmasi sebelum sweep | Sama, cukup pivot terbaru pada sisi yang disapu |
| Konfirmasi sesudah sweep | Close menembus pivot minor berlawanan yang dibekukan saat sweep | Close melewati **high candle sweep untuk buy / low untuk sell**; ini konfirmasi lokal, bukan pivot BOS yang sama dengan Strict |
| Body candle konfirmasi | Minimal 0,8 ATR M5 | Minimal 0,4 ATR M5 |
| RSI8 | Buy >50 dan naik; sell <50 dan turun | Sama |
| Entry limit | Midpoint body candle konfirmasi | Mulai midpoint; bila RR terhalang, coba retracement lebih dalam **di dalam range candle konfirmasi** |

Balanced tetap menunggu candle tertutup, maksimal 3 candle konfirmasi, ekstrem sweep tidak boleh ditembus ulang, SL di luar sweep, TP minimal2R, expiry3 candle, biaya/margin/sizing/guard risiko, dan BE1R. **Tidak ada order dummy, entry setiap candle, martingale, atau market order paksa.**

### Entry yang menyesuaikan ruang RR, bukan menurunkan target

Pada Balanced, jika target2R dari midpoint terhalang pivot M15, EA menghitung harga limit lebih dalam agar target tetap2R sebelum penghalang. SL struktural tidak diubah. Harga entry harus tetap berada di range candle konfirmasi dan di sisi yang benar dari SL. Setiap perpindahan memeriksa ulang pivot terdekat karena pivot yang tadinya di belakang entry bisa menjadi penghalang baru. Pembulatan tick dan buffer spread tetap dihitung.

Jika tidak ada entry yang memenuhi syarat dalam range tersebut, setup tetap dilewati. Lot, biaya dan margin dihitung ulang dari **entry akhir**; retracement lebih dalam bisa gagal filter biaya dan tidak otomatis menghasilkan transaksi. Limit order juga tetap harus tersentuh harga agar terisi. `RR_adjusted` menghitung kandidat yang lolos penyesuaian harga sebelum gate biaya/sizing, bukan jumlah fill.

Gunakan **`500USD_v130_Balanced.set`** untuk pengujian baru. Semua preset lama kini menyetel `InpSignalProfile=0` secara eksplisit agar perbandingan Strict tidak diam-diam memakai aturan Balanced. Bandingkan keduanya pada periode/data/biaya yang sama, lalu uji Balanced di periode lain; jangan menganggap perubahan ini sudah meningkatkan win rate atau expectancy.

## Instalasi

**Kedua file `.mq5` v1.30 di `Experts` dan `Standalone` sudah satu file lengkap**, tidak memerlukan header custom di terminal. Tetap memerlukan Standard Library `Trade/Trade.mqh` bawaan MT5. Gunakan satu versi EA saja; timpa versi lama dan compile ulang, jangan menjalankan dua instance. Jangan menyimpan halaman HTML GitHub sebagai `.mq5`.

1. MT5 → **File → Open Data Folder**.
2. Salin `mt5/Experts/GoldTrendSweep.mq5` ke `MQL5/Experts/`.
3. Tidak perlu menyalin header tambahan. `mt5/Include/GoldRiskMath.mqh` dan `GoldSignalMath.mqh` di repository menjadi sumber modul untuk pengembangan dan tes; script build menanamkannya dalam kedua `.mq5`.
4. Buka `.mq5` di MetaEditor, tekan **F7**. Pastikan tidak ada error maupun warning sebelum menguji.
5. Jalankan dahulu di Strategy Tester, kemudian akun demo. Gunakan **XAUUSD M5**; nama simbol yang mengandung `XAU` atau `GOLD` didukung tanpa membedakan huruf besar/kecil. Periode chart lain tidak lagi menggagalkan startup, tetapi sinyal internal tetap **M5/M15/H1**, bukan berubah mengikuti chart.
6. Sesuaikan komisi, jam server, dan mode berita sebelum mengaktifkan Algo Trading. Akun real **diblokir secara default** (`InpAllowRealTrading=false`).

Hanya satu instance untuk kombinasi akun/magic dalam terminal. Jangan menjalankan magic yang sama dari terminal/VPS lain. Gunakan akun khusus EA ini, terutama untuk akun netting: order manual/EA lain bisa mengubah posisi gabungan dan mengacaukan pengukuran risiko. EA menolak entry jika sudah ada posisi/order pada simbol tersebut atau magic yang sama.

## Backtest dengan modal $500 dan pilihan lot

Versi sebelumnya memang menolak startup Strategy Tester jika mode kalender default dipakai. Selain itu, risiko 0,25% pada $500 hanya **$1,25**: banyak setup tidak bisa memenuhi minimum lot 0,01. Ini berbeda dari tidak adanya sinyal; memperbesar lot tidak menyelesaikan startup atau memastikan entry.

1. Compile **versi v1.30**. Pilih EA yang baru dikompilasi dalam tester. Journal harus menampilkan **`GoldTrendSweep v1.30 initialized. SINGLE-FILE BUILD. Profile=SIGNAL_BALANCED`** untuk profil baru; jika tidak, jangan menilai hasilnya sebagai versi terbaru/Balanced.
2. Atur **deposit 500, currency USD, XAUUSD, M5**, dan **Every tick based on real ticks**. Gunakan leverage serta spesifikasi simbol broker tujuan, bukan leverage yang dinaikkan hanya agar lolos margin.
3. Tab **Inputs → Reset**, lalu **Load** salah satu preset di `mt5/Presets/`. Preset hanya mengubah input EA, **tidak mengatur deposit, leverage, atau tanggal tester**. Input lain seperti komisi/jam server masih perlu disesuaikan.

| Preset | Perilaku pada ekuitas awal $500 |
| --- | --- |
| `500USD_v130_Balanced.set` | Profil **Balanced baru**, auto-lot risiko maksimal **2% ($10)**, maksimum0,10 lot. Gunakan ini untuk menguji perubahan sinyal v1.30. |
| `500USD_v120_AutoRisk2.set` | Pembanding **Strict**: auto-lot risiko maksimal **2% ($10)**, maksimum0,10 lot. |
| `500USD_AutoRisk.set` | Pilihan awal yang lebih konservatif: risiko **1% ($5)**; lot dihitung dari SL dan biaya, maksimal 0,10. Bisa lebih kecil dari 0,05 atau skip jika min lot masih terlalu besar. |
| `500USD_Fixed005_Capped.set` | Minta tepat **0,05 lot**, tetapi hanya entry jika risiko estimasi SL+biaya **≤2% ($10)** dan sisa budget cukup. |
| `500USD_Fixed010_Capped.set` | Minta tepat **0,10 lot**, dengan batas risiko yang sama **≤2% ($10)**; lebih sering skip karena kebutuhan risikonya lebih besar. |

Semua preset mempertahankan TP2R, BE1R, margin cap20%, DD reduction/pause/hard5/8/10%. Batas harian/mingguan **3%/6%** dan risiko default kode **2%** tetap sama sejak v1.20. Risiko2% lebih agresif daripada default awal0,25%, bukan hanya perubahan teknis. Akun real tetap diblokir. Tidak ada klaim bahwa preset Balanced sudah menghasilkan entry/profit di tester.

**Fixed lot bukan izin melewati batas risiko.** Mode `LOT_FIXED_CAPPED` tidak diam-diam menurunkan/menaikkan lot: broker min/max/step, budget, atau margin yang tidak cocok membuat setup dilewati dan alasannya dicetak. Setelah DD5%, budget dipotong separuh; fixed lot tetap sama dan hanya lolos jika cocok dengan budget yang lebih kecil. Tidak mempersempit SL struktural untuk memaksakan lot besar.

Contoh **jika kontrak broker 100 oz/lot**: pada SL berjarak $5, 0,05 lot berisiko sekitar **$25 (5%)**, dan 0,10 lot **$50 (10%)**, sebelum biaya. Keduanya ditolak oleh preset capped, bukan bug. Lot besar tersebut tidak konsisten dengan target drawdown rendah jika dipaksakan untuk setiap setup.

### Mengapa mengganti lot saja bisa tetap menghasilkan nol order

Filter biaya dan cap risiko harus sama-sama terpenuhi. Contoh **ilustrasi, bukan spesifikasi broker pengguna**: kontrak 100 oz/lot, spread $0,30, cadangan slippage $0,30, komisi $7/lot round-trip. Biaya estimasi per lot = $30+$30+$7=$67. Dengan batas biaya 10% dari risiko harga, risiko harga harus minimal $670/lot; setelah cadangan slippage+komisi, risiko sizing minimal $707/lot. Maka:

- Lot minimum 0,01 membutuhkan budget sedikitnya **$7,07**. Budget lama $1,25, bahkan preset 1% ($5), tidak bisa lolos pada biaya tersebut.
- Lot 0,05 membutuhkan sedikitnya **$35,35**. Meminta lot lebih besar justru memperparah konflik dengan cap $10.
- Auto-lot 2% ($10) memungkinkan sebagian setup 0,01 lot, tetapi **bukan jaminan entry**: SL struktural, margin, sinyal, dan quote broker harus tetap memenuhi aturan.

v1.20 mencetak **`GTS COST/RISK CHECK`** dari quote dan spesifikasi broker saat run. Angka ini estimasi batas bawah pada spread saat itu; spread berikutnya atau SL struktural bisa membutuhkan budget lebih besar. Jangan mempersempit SL struktural atau melepas cap risiko untuk menipu pemeriksaan ini.

### Perbaikan filter RR v1.20

Versi sebelumnya membandingkan target terhadap pivot M15 terakhir tanpa mengecek apakah level tersebut masih **di depan entry**. Contoh buy entry 2500, SL2495, TP2510 dan pivot terakhir2498: kode lama menolak, padahal2498 bukan resistance di jalur target. v1.20 mengabaikan level di belakang entry dan mencari pivot terkonfirmasi **terdekat di depan entry** dalam lookback. Jika ada pivot lain2508, trade tetap ditolak; filter ruang RR tidak dihapus. Jika tidak ada penghalang terkonfirmasi di depan dalam lookback, filter RR ini lolos. Ini tidak berarti tidak ada resistance di luar lookback.

### Membaca alasan tidak entry

Dengan `InpDiagnostics=true`, buka tab **Journal** Strategy Tester. EA mencetak konfigurasi awal, status kalender, lalu alasan seperti:

- `Waiting: H1/M15 history ... warming up` → data indikator belum siap; dipisahkan dari `H1 trend and M15 profile filter disagree` yang berarti arah tren belum selaras.
- `Waiting: no liquidity sweep` / `sweep outside M15 zone` → belum ada setup yang memenuhi aturan.
- `Skip: ... RSI8`, `... target RR`, `... cost fraction` → setup gagal filter; bukan kegagalan startup.
- `Skip sizing: budget=..., minimum-lot loss=..., requested-fixed loss=...` → lot tidak sesuai budget/spesifikasi. Angka biaya dalam mata uang akun.
- `Skip margin` → kebutuhan margin terlalu besar; cek leverage tester dan kontrak broker.
- `Blocked: ... session/news/drawdown` → batas operasional aktif.
- `Pending placed` → order berhasil dibuat; **belum berarti terisi**. Retracement harus menyentuh entry sebelum kedaluwarsa.
- `Place retracement limit failed: ...` → retcode dan deskripsi penolakan broker tercatat.

Saat test berakhir (bukan optimasi), Journal juga mencetak ringkasan walaupun `InpDiagnostics=false`:

```text
GTS v1.30 SUMMARY: evaluated_M5_bars=... aligned=... sweeps=... structure_breaks=... order_attempts=... accepted_pending=... filled_entry_orders=...
GTS SKIPS: price=... RR=... costs=... sizing=... margin=... expiry=...
GTS SIGNALS: warmup=... trend_disagree=... raw_sweeps=... zone_rejected=... momentum_rejected=... expired_or_invalidated=... RR_adjusted=...
```

`evaluated_M5_bars` menghitung candle yang sampai ke evaluasi strategi setelah gate sesi/berita/risiko, bukan seluruh candle tester. `structure_breaks` menghitung konfirmasi sesuai profil dan masih harus lolos RSI/body. `raw_sweeps` belum difilter zona; `sweeps` sudah lolos zona. `expired_or_invalidated` menghitung setup aktif yang gagal pemeriksaan umur/arah/ekstrem pada candle berikutnya, bukan seluruh jenis pembatalan. `accepted_pending>0` dengan `filled_entry_orders=0` berarti order dibuat tetapi tidak terisi sebelum dibatalkan/kedaluwarsa. Ringkasan dan `GTS COST/RISK CHECK` lebih berguna untuk debugging daripada laporan profit nol saja. Optimasi non-visual MT5 dapat menekan `Print`; gunakan satu backtest normal.

Jika tidak ada transaksi, kirim baris Journal mulai inisialisasi hingga beberapa alasan skip, nama simbol/broker, tanggal tes, leverage, dan preset. Tanpa log/tick broker, penyebab spesifik kasus pengguna belum dapat dipastikan. Jangan melonggarkan seluruh filter hanya untuk memunculkan trade.

## Default money management

| Pengaturan | Default dan perilaku |
| --- | --- |
| Risiko per transaksi | **2% ekuitas** (juga batas input maksimum); default mode auto risk |
| Pilihan fixed lot | `InpLotMode=LOT_FIXED_CAPPED`, `InpFixedLots=0.05` (boleh 0.10), tetap dibatasi budget risiko; tidak aktif pada mode auto |
| Lot | Dibulatkan **turun** menurut volume step broker; jika minimum lot melampaui budget, setup dilewati |
| Biaya sizing | Estimasi komisi round-trip + cadangan slippage ikut diperhitungkan |
| Sisa budget | Risiko entry juga dibatasi oleh sisa ruang menuju batas rugi harian, mingguan, dan hard DD |
| TP | **2 × jarak entry–SL**, dapat disetel antara 2R–5R; RR harga, bukan RR bersih biaya |
| Break-even | Saat Bid buy / Ask sell mencapai **1R dari harga fill aktual**, SL dipindah ke entry + buffer biaya untuk buy, entry − buffer biaya untuk sell |
| BE buffer | Maksimum estimasi komisi round-trip atau 2 × biaya entry tercatat, ditambah swap negatif dan 2 tick ekstra |
| Kerugian harian | **3%** dari ekuitas awal hari server: batalkan order, tutup posisi EA, kunci sampai hari berikutnya |
| Kerugian mingguan | **6%** dari ekuitas awal minggu server (Senin): tindakan yang sama, terkunci sampai minggu berikutnya |
| DD 5% | Risiko per entry dipotong separuh, menjadi **1%** dengan input default |
| DD 8% | **Kunci permanen entry baru**, batalkan pending; posisi berjalan tetap dikelola |
| DD 10% | Kunci permanen, batalkan pending dan **upayakan menutup posisi EA** |
| Batas entry | Maksimal **3 order entry terisi/hari**, partial fill order yang sama dihitung sekali |
| Eksposur | Satu posisi/order; **tanpa martingale, grid, averaging down, atau partial TP** |
| Margin | Kebutuhan order baru maksimal **20% free margin**; lot juga dibatasi maksimal 0,10 lot |
| Waktu posisi | Tutup setelah **60 menit** jika belum SL/TP; tidak membiarkan scalp berubah menjadi posisi tanpa batas |

**Contoh:** ekuitas $500 dengan risiko 2% → budget $10. Jika kerugian estimasi per 1 lot termasuk biaya adalah $507 dan volume step 0,01, EA memilih **0,01 lot**, bukan membulatkan ke 0,02 (risiko $10,14). Ini contoh sizing terpisah; filter strategi/biaya tetap harus lolos.

SL/TP awal disertakan dalam pending order. SL tidak pernah sengaja diperlebar. Setelah pemicu 1R tercapai, status BE disimpan dan modifikasi dicoba lagi bila broker menolak atau stop/freeze level belum memungkinkan. Harga pemicu menggunakan sisi quote yang dapat dieksekusi, bukan sekadar harga chart. BE di sisi server baru aktif **setelah modifikasi diterima broker**.

**Batas perlindungan:** gap, spread mendadak, slippage, market tutup, kegagalan koneksi, AutoTrading nonaktif, atau terminal mati dapat membuat kerugian melampaui budget/batas DD. Buffer BE adalah estimasi, bukan jaminan hasil bersih nol/positif. BE, penutupan berbasis waktu, dan equity guard memerlukan EA tetap berjalan; SL/TP yang sudah diterima broker tetap berada di server. Biaya setelah penutupan dapat berbeda dari perkiraan.

### State risiko dan restart

Peak equity, baseline harian/mingguan, lock, dan pemicu BE disimpan dalam **Terminal Global Variables**, dengan prefix `GTS.<login>.<magic>.`. Restart biasa tidak meresetnya. Tester membersihkan state per pass supaya hasil tidak terkontaminasi pass sebelumnya.

- DD diukur dari **puncak ekuitas yang teramati sejak EA pertama dipasang**, bukan seluruh riwayat akun. Floating P/L ikut dihitung. Baseline hari/minggu diperbarui pada event pertama periode baru; terminal yang mati tidak dapat merekonstruksi ekuitas historis yang terlewat.
- Guard mengukur **ekuitas seluruh akun**, tetapi hanya menutup posisi/order **milik EA pada simbolnya**. Kerugian dari trading lain tetap memengaruhi guard dan tidak ditutup EA.
- Tidak ada penyesuaian otomatis untuk deposit/withdrawal. Jangan melakukan arus dana atau trading lain saat pengujian/pengoperasian; rekonsiliasi baseline dalam keadaan flat terlebih dahulu.
- Lock DD 8%/10% tidak otomatis pulih. Setelah evaluasi, **flat-kan akun, hapus EA, dan catat statistik terlebih dahulu**. Reset state dengan menghapus Global Variables berprefix EA melalui F3 hanya jika sengaja memulai periode risiko baru. Jangan menghapus state untuk menyembunyikan drawdown. State terminal tidak berpindah otomatis ke VPS/terminal baru dan bisa kedaluwarsa setelah lama tidak dipakai.
- Menghapus/reconfigure EA berupaya membatalkan pending, tetapi **tidak menutup posisi terbuka**. Posisi tersebut hanya memiliki SL/TP server sampai EA kembali aktif. Jangan mengandalkan pembatalan saat koneksi terputus.

## Aturan entry Strict (profil lama, untuk pembanding)

1. **H1:** candle tertutup di atas EMA200 dan EMA meningkat dibanding 3 candle sebelumnya untuk buy; kebalikannya untuk sell.
2. **M15:** dua pivot high dan dua pivot low terakhir sama-sama meningkat untuk buy, menurun untuk sell. Pivot default memerlukan 2 candle tertutup di setiap sisi; tidak memakai candle masa depan sebelum tersedia.
3. **M5:** sweep pivot low/high yang **sudah terkonfirmasi sebelum candle sweep**, lalu close kembali di sisi level sebelumnya. Ekstrem sweep harus berada dalam 0,5 ATR M5 dari pivot support/resistance M15 terakhir.
4. Dalam maksimal 3 candle berikutnya, close harus menembus pivot minor berlawanan yang dibekukan pada saat sweep. Candle harus searah tren dan body minimal 0,8 ATR. Setup batal jika ekstrem sweep ditembus lagi atau arah tren berubah.
5. **RSI8 M5:** buy memerlukan RSI >50 dan meningkat; sell <50 dan menurun. Semua memakai candle tertutup. Bisa dinonaktifkan untuk perbandingan A/B.
6. Entry limit pada **titik tengah body candle konfirmasi**, bukan midpoint seluruh wick. SL di luar ekstrem sweep + buffer 0,2 ATR. ATR memakai candle sebelum candle sinyal.
7. TP 2R harus berada sebelum pivot penghalang M15 terdekat **di depan entry** dengan buffer spread. Jika ruang tidak cukup, tidak entry; pivot di belakang entry tidak dianggap penghalang.
8. Pending kedaluwarsa setelah 3 candle M5 di **server broker**. Broker yang tidak mendukung expiration timestamp akan dilewati; tidak diturunkan menjadi GTC yang bisa terisi tanpa pengawasan.
9. Tidak entry ketika range candle >3 ATR, estimasi spread + komisi + slippage >10% risiko harga, di luar sesi, saat blackout berita, atau guard risiko aktif. Pending juga dibatalkan saat kondisi biaya/risiko tidak lagi memenuhi syarat atau tren berubah.

Filter Strict ini sengaja ketat dan bisa menghasilkan **sedikit atau tidak ada transaksi**, seperti Journal pengguna. Aturan Balanced dijelaskan di bagian v1.30 di atas. Keduanya tidak memakai FVG/order block/divergence subjektif. Parameter belum dioptimasi; nama “SMC/ICT” tidak membuktikan keunggulan statistik.

## Pengaturan broker yang wajib diperiksa

- `InpCommissionPerLotRoundTurn=7.0` adalah **placeholder 7 unit mata uang akun per lot pulang-pergi**, bukan angka universal dan bukan otomatis USD. Sesuaikan akun IDR/cent/komisi berbeda. Isi 0 hanya untuk akun yang memang tanpa komisi. Swap/fee lain bisa membuat biaya aktual berbeda.
- `InpSlippageReservePoints=30` dalam **point broker**, bukan dolar/pip; broker 2 digit dan 3 digit berbeda. Ini cadangan perhitungan dan deviasi permintaan, bukan batas kerugian yang dijamin broker.
- `InpSessionStartHour=8`, `InpSessionEndHour=18` adalah **waktu server broker**, hanya Senin–Jumat. Sesuaikan jika ingin fokus London/awal New York; DST tidak dipetakan otomatis. Sesi melintasi tengah malam didukung bila start > end.
- Cek contract size, tick size, tick value, minimum lot, volume step, stop/freeze level, dan batas pending broker. Sizing menggunakan `OrderCalcProfit` dalam mata uang akun, bukan asumsi semua broker emas memiliki nilai tick sama.

## Filter berita dan Strategy Tester

Default `NEWS_MT5_CALENDAR` memblokir entry 30 menit sebelum/sesudah berita **USD high impact**. Jika API gagal, EA **fail closed**: tidak membuat entry dan membatalkan pending. Filter tidak menutup posisi yang sudah terbuka hanya karena berita; posisi tetap memakai SL/TP, BE, dan batas waktu. Peristiwa tak terjadwal tidak terdeteksi; pertimbangkan window lebih panjang untuk FOMC.

API kalender MT5 **tidak tersedia dalam Strategy Tester**. Mulai v1.10, `InpTesterSkipCalendar=true` memungkinkan startup default sebagai **baseline tester tanpa filter berita**, dengan **WARNING yang selalu dicetak di Journal**. Pengaturan ini hanya memengaruhi `NEWS_MT5_CALENDAR` dalam tester, tidak menonaktifkan kalender pada demo/live dan tidak mengubah mode manual. Hasil baseline tidak setara pengujian dengan jadwal berita. Untuk pengujian berita yang lebih realistis pilih:

1. **`NEWS_MANUAL_TIMES`** dan masukkan jadwal high-impact lengkap sepanjang periode uji, dipisah titik koma, misalnya `2025.01.10 15:30;2025.01.15 15:30`. Contoh ini hanya format, **bukan kalender valid**. Semua timestamp harus sudah dikonversi ke waktu server broker/DST historis. Mode ini tidak memeriksa kelengkapan daftar.
2. Set **`InpTesterSkipCalendar=false`** agar mode kalender yang tidak tersedia kembali menggagalkan startup, sehingga tidak sengaja menguji tanpa berita. `NEWS_DISABLED` tetap tersedia untuk baseline eksplisit di semua lingkungan.

Mode manual juga dapat digunakan di demo/live apabila kalender broker tidak tersedia, tetapi jadwal harus selalu diperbarui sendiri.

## Rencana verifikasi sebelum akun real

1. **Compile MetaEditor:** F7, target 0 error/0 warning. Kompilasi MQL5 belum dijalankan di workspace Linux ini; MetaEditor/MT5/Wine tidak tersedia. Binary `.ex5` tidak disertakan.
2. **Strategy Tester:** XAUUSD, M5, *Every tick based on real ticks*, data broker tujuan, komisi/leverage/spread yang sesuai. Pastikan data H1 tersedia cukup untuk EMA200. Jangan memakai *Open prices only* untuk menilai BE intrabar.
3. **Visual test buy/sell:** entry terisi, initial SL/TP benar, belum BE di 0,99R, BE pada executable quote 1R, TP tidak berubah, SL tidak mundur; uji juga broker stop/freeze level yang menghambat BE.
4. **Uji keselamatan:** minimum lot terlalu besar → skip; partial fill → sisa pending dibatalkan; spread tinggi/news/session close → cancel pending; expiration server; stop hilang → upayakan close; batas harian/mingguan dan DD; restart sebelum/sesudah 1R; tidak menyentuh posisi magic lain.
5. **Validasi statistik:** train/validation/out-of-sample terpisah; beberapa rezim pasar; walk-forward; Monte Carlo urutan hasil; stres biaya, latensi, dan slippage. Laporkan jumlah win/loss/BE, expectancy bersih, profit factor, equity DD, serta frekuensi trade. Bandingkan dengan/tanpa RSI dan jangan optimasi di data pengujian akhir.
6. **Demo lalu akun kecil:** hasil forward harus mendukung hasil tester sebelum risiko dinaikkan. Jangan mengejar frekuensi trade dengan melonggarkan batas risiko.

**BE pada 1R mengubah distribusi hasil:** sebagian trade yang tadinya mungkin mencapai 2R akan keluar BE. Jadi win rate, average win, dan expectancy perlu diuji ulang; rumus sebelumnya dengan hanya win/loss tidak boleh langsung dipakai. Time exit juga dapat menutup posisi sebelum 2R. Target harga 2R tidak berarti setiap trade untung memperoleh 2R bersih.

### Pengujian lokal yang tersedia

`GoldRiskMath.mqh` dipakai langsung oleh EA dan tes C++ (wrapper fungsi matematika saja):

```sh
mkdir -p /tmp/goldtrend-tests
g++ -std=c++17 -Wall -Wextra -Werror -pedantic -fsanitize=address,undefined \
  tests/risk_math_test.cpp -o /tmp/goldtrend-tests/risk_math_test
/tmp/goldtrend-tests/risk_math_test
```

Meliputi budget risiko, pengurangan risiko, lot step/min/max dengan 4.995 kombinasi sizing, pembulatan harga tick, pemicu 1R buy/sell, buffer BE dan SL yang hanya membaik. **Tes ini bukan kompilasi MQL5, simulator broker, ataupun backtest strategi.**

Tambahan v1.10: tes lot 0,05/0,10 pada budget akun $500, penolakan risiko berlebihan, step tidak valid, dan pengurangan budget; validasi preset serta kesetaraan distribusi standalone:

```sh
python3 scripts/build_standalone.py
python3 scripts/build_standalone.py --check
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Tambahan v1.20: regression test filter RR buy/sell, level belakang yang tidak boleh memblokir, pivot lebih tua di depan yang tetap harus memblokir, batas buffer target, serta perhitungan konflik biaya/risiko $500. Kedua `.mq5` diperiksa tidak memiliki dependency custom include dan modul tertanamnya identik dengan header yang dites. Pengujian ini belum membuktikan ada fill di data broker pengguna.

Tambahan v1.30: modul sinyal yang **dipakai langsung EA** diuji dengan rangkaian kandidat buy/sell sintetis: arah EMA, sweep/reclaim, zona ATR, invalidasi ekstrem, konfirmasi lokal, RSI/body, penyesuaian retracement2R, deteksi penghalang baru setelah entry bergeser, batas range candle, biaya, dan sizing$500. Tes negatif menolak RSI salah, candle tanpa break, entry di luar range, serta angka invalid. Fixture ini bukan replay data broker atau bukti order terisi di MT5.

```sh
g++ -std=c++17 -Wall -Wextra -Werror -pedantic -fsanitize=address,undefined \
  tests/signal_math_test.cpp -o /tmp/goldtrend-tests/signal_math_test
/tmp/goldtrend-tests/signal_math_test
```

Verifikasi MT5 berikutnya: jalankan preset Balanced baru pada periode yang sama, pastikan banner profil, bandingkan `raw_sweeps`, `sweeps`, `momentum_rejected`, `RR_adjusted`, serta jumlah pending/fill dengan Strict. Periksa visual bahwa entry yang digeser tetap berada di candle konfirmasi, SL tetap di luar sweep, dan TP2R/BE1R sesuai fill aktual. Jangan menilai keberhasilan hanya dari bertambahnya jumlah transaksi.

Uji manual MT5 yang masih wajib: default tester berhasil init dengan warning tanpa berita; toggle skip false menolak kalender; manual news tetap memblokir sesuai timestamp; input live trading tetap false di demo/real; preset fixed mengirim lot yang diminta hanya jika budget cocok. Mode chart M15 tetap memakai sinyal internal M5, bukan strategi entry M15 terpisah. **Belum diverifikasi melalui MT5 di workspace ini.**

## Referensi API resmi

- [OrderCalcProfit: estimasi profit/loss dalam mata uang akun](https://www.mql5.com/en/docs/trading/ordercalcprofit)
- [OrderCalcMargin](https://www.mql5.com/en/docs/trading/ordercalcmargin)
- [CTrade::BuyLimit dan pemeriksaan retcode](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuylimit)
- [CalendarValueHistory: waktu server](https://www.mql5.com/en/docs/calendar/calendarvaluehistory)
- [Kalender ekonomi dan keterbatasan tester](https://www.mql5.com/en/book/advanced/calendar)
- [Kompilasi melalui MetaEditor](https://www.metatrader5.com/en/metaeditor/help/development/compile)
