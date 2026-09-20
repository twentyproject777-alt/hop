# GoldTrendSweep — EA MT5 untuk XAUUSD

EA eksperimental: tren H1/M15, liquidity sweep M5, konfirmasi struktur dan RSI(8), entry retracement, TP awal **2R**, serta **break-even berbuffer biaya setelah mencapai 1R**. Bukan jaminan profit, win rate >50%, atau drawdown maksimal tertentu. Belum ada hasil backtest maupun forward test MT5.

## Instalasi

**Pilihan paling mudah (v1.10):** unduh raw `mt5/Standalone/GoldTrendSweep.mq5`, taruh di `MQL5/Experts/`, lalu compile F7. File ini sudah menggabungkan modul risiko, jadi **tidak perlu menyalin `GoldRiskMath.mqh`**. Tetap memerlukan Standard Library `Trade/Trade.mqh` bawaan MT5. Gunakan satu versi EA saja; timpa versi lama dan compile ulang, jangan menjalankan dua instance. Jangan menyimpan halaman HTML GitHub sebagai `.mq5`.

Alternatif versi modular untuk pengembangan:

1. MT5 → **File → Open Data Folder**.
2. Salin `mt5/Experts/GoldTrendSweep.mq5` ke `MQL5/Experts/`.
3. Salin `mt5/Include/GoldRiskMath.mqh` ke `MQL5/Include/`.
4. Buka `.mq5` di MetaEditor, tekan **F7**. Pastikan tidak ada error maupun warning sebelum menguji.
5. Jalankan dahulu di Strategy Tester, kemudian akun demo. Gunakan **XAUUSD M5**; nama simbol yang mengandung `XAU` atau `GOLD` didukung tanpa membedakan huruf besar/kecil. Periode chart lain tidak lagi menggagalkan startup, tetapi sinyal internal tetap **M5/M15/H1**, bukan berubah mengikuti chart.
6. Sesuaikan komisi, jam server, dan mode berita sebelum mengaktifkan Algo Trading. Akun real **diblokir secara default** (`InpAllowRealTrading=false`).

Hanya satu instance untuk kombinasi akun/magic dalam terminal. Jangan menjalankan magic yang sama dari terminal/VPS lain. Gunakan akun khusus EA ini, terutama untuk akun netting: order manual/EA lain bisa mengubah posisi gabungan dan mengacaukan pengukuran risiko. EA menolak entry jika sudah ada posisi/order pada simbol tersebut atau magic yang sama.

## Backtest dengan modal $500 dan pilihan lot

Versi sebelumnya memang menolak startup Strategy Tester jika mode kalender default dipakai. Selain itu, risiko 0,25% pada $500 hanya **$1,25**: banyak setup tidak bisa memenuhi minimum lot 0,01. Ini berbeda dari tidak adanya sinyal; memperbesar lot tidak menyelesaikan startup atau memastikan entry.

1. Compile **versi v1.10** (disarankan standalone di atas). Pilih EA yang baru dikompilasi dalam tester.
2. Atur **deposit 500, currency USD, XAUUSD, M5**, dan **Every tick based on real ticks**. Gunakan leverage serta spesifikasi simbol broker tujuan, bukan leverage yang dinaikkan hanya agar lolos margin.
3. Tab **Inputs → Reset**, lalu **Load** salah satu preset di `mt5/Presets/`. Preset hanya mengubah input EA, **tidak mengatur deposit, leverage, atau tanggal tester**. Input lain seperti komisi/jam server masih perlu disesuaikan.

| Preset | Perilaku pada ekuitas awal $500 |
| --- | --- |
| `500USD_AutoRisk.set` | Pilihan awal yang lebih konservatif: risiko **1% ($5)**; lot dihitung dari SL dan biaya, maksimal 0,10. Bisa lebih kecil dari 0,05 atau skip jika min lot masih terlalu besar. |
| `500USD_Fixed005_Capped.set` | Minta tepat **0,05 lot**, tetapi hanya entry jika risiko estimasi SL+biaya **≤2% ($10)** dan sisa budget cukup. |
| `500USD_Fixed010_Capped.set` | Minta tepat **0,10 lot**, dengan batas risiko yang sama **≤2% ($10)**; lebih sering skip karena kebutuhan risikonya lebih besar. |

Ketiga preset mempertahankan TP2R, BE1R, filter strategi, margin cap 20%, DD reduction/pause/hard 5/8/10%. Batas harian/mingguan preset adalah **3%/6%**, bukan default kode 1%/3%. Tidak ada klaim bahwa preset tersebut sudah menghasilkan entry/profit di tester.

**Fixed lot bukan izin melewati batas risiko.** Mode `LOT_FIXED_CAPPED` tidak diam-diam menurunkan/menaikkan lot: broker min/max/step, budget, atau margin yang tidak cocok membuat setup dilewati dan alasannya dicetak. Setelah DD5%, budget dipotong separuh; fixed lot tetap sama dan hanya lolos jika cocok dengan budget yang lebih kecil. Tidak mempersempit SL struktural untuk memaksakan lot besar.

Contoh **jika kontrak broker 100 oz/lot**: pada SL berjarak $5, 0,05 lot berisiko sekitar **$25 (5%)**, dan 0,10 lot **$50 (10%)**, sebelum biaya. Keduanya ditolak oleh preset capped, bukan bug. Lot besar tersebut tidak konsisten dengan target drawdown rendah jika dipaksakan untuk setiap setup.

### Membaca alasan tidak entry

Dengan `InpDiagnostics=true`, buka tab **Journal** Strategy Tester. EA mencetak konfigurasi awal, status kalender, lalu alasan seperti:

- `Waiting: H1 EMA / M15 ...` → data belum cukup atau tren/struktur belum selaras.
- `Waiting: no liquidity sweep` / `sweep outside M15 zone` → belum ada setup yang memenuhi aturan.
- `Skip: ... RSI8`, `... target RR`, `... cost fraction` → setup gagal filter; bukan kegagalan startup.
- `Skip sizing: budget=..., minimum-lot loss=..., requested-fixed loss=...` → lot tidak sesuai budget/spesifikasi. Angka biaya dalam mata uang akun.
- `Skip margin` → kebutuhan margin terlalu besar; cek leverage tester dan kontrak broker.
- `Blocked: ... session/news/drawdown` → batas operasional aktif.
- `Pending placed` → order berhasil dibuat; **belum berarti terisi**. Retracement harus menyentuh entry sebelum kedaluwarsa.
- `Place retracement limit failed: ...` → retcode dan deskripsi penolakan broker tercatat.

Jika tidak ada transaksi, kirim baris Journal mulai inisialisasi hingga beberapa alasan skip, nama simbol/broker, tanggal tes, leverage, dan preset. Tanpa log/tick broker, penyebab spesifik kasus pengguna belum dapat dipastikan. Jangan melonggarkan seluruh filter hanya untuk memunculkan trade.

## Default money management

| Pengaturan | Default dan perilaku |
| --- | --- |
| Risiko per transaksi | **0,25% ekuitas**, input dibatasi maksimal 2%; default mode auto risk |
| Pilihan fixed lot | `InpLotMode=LOT_FIXED_CAPPED`, `InpFixedLots=0.05` (boleh 0.10), tetap dibatasi budget risiko; tidak aktif pada mode auto |
| Lot | Dibulatkan **turun** menurut volume step broker; jika minimum lot melampaui budget, setup dilewati |
| Biaya sizing | Estimasi komisi round-trip + cadangan slippage ikut diperhitungkan |
| Sisa budget | Risiko entry juga dibatasi oleh sisa ruang menuju batas rugi harian, mingguan, dan hard DD |
| TP | **2 × jarak entry–SL**, dapat disetel antara 2R–5R; RR harga, bukan RR bersih biaya |
| Break-even | Saat Bid buy / Ask sell mencapai **1R dari harga fill aktual**, SL dipindah ke entry + buffer biaya untuk buy, entry − buffer biaya untuk sell |
| BE buffer | Maksimum estimasi komisi round-trip atau 2 × biaya entry tercatat, ditambah swap negatif dan 2 tick ekstra |
| Kerugian harian | **1%** dari ekuitas awal hari server: batalkan order, tutup posisi EA, kunci sampai hari berikutnya |
| Kerugian mingguan | **3%** dari ekuitas awal minggu server (Senin): tindakan yang sama, terkunci sampai minggu berikutnya |
| DD 5% | Risiko per entry dipotong separuh, menjadi **0,125%** |
| DD 8% | **Kunci permanen entry baru**, batalkan pending; posisi berjalan tetap dikelola |
| DD 10% | Kunci permanen, batalkan pending dan **upayakan menutup posisi EA** |
| Batas entry | Maksimal **3 order entry terisi/hari**, partial fill order yang sama dihitung sekali |
| Eksposur | Satu posisi/order; **tanpa martingale, grid, averaging down, atau partial TP** |
| Margin | Kebutuhan order baru maksimal **20% free margin**; lot juga dibatasi maksimal 1 lot |
| Waktu posisi | Tutup setelah **60 menit** jika belum SL/TP; tidak membiarkan scalp berubah menjadi posisi tanpa batas |

**Contoh:** ekuitas 10.000 → budget risiko 25 dalam mata uang akun. Jika kerugian estimasi per 1 lot termasuk biaya adalah 507 dan volume step 0,01, EA memilih **0,04 lot**, bukan membulatkan ke 0,05.

SL/TP awal disertakan dalam pending order. SL tidak pernah sengaja diperlebar. Setelah pemicu 1R tercapai, status BE disimpan dan modifikasi dicoba lagi bila broker menolak atau stop/freeze level belum memungkinkan. Harga pemicu menggunakan sisi quote yang dapat dieksekusi, bukan sekadar harga chart. BE di sisi server baru aktif **setelah modifikasi diterima broker**.

**Batas perlindungan:** gap, spread mendadak, slippage, market tutup, kegagalan koneksi, AutoTrading nonaktif, atau terminal mati dapat membuat kerugian melampaui budget/batas DD. Buffer BE adalah estimasi, bukan jaminan hasil bersih nol/positif. BE, penutupan berbasis waktu, dan equity guard memerlukan EA tetap berjalan; SL/TP yang sudah diterima broker tetap berada di server. Biaya setelah penutupan dapat berbeda dari perkiraan.

### State risiko dan restart

Peak equity, baseline harian/mingguan, lock, dan pemicu BE disimpan dalam **Terminal Global Variables**, dengan prefix `GTS.<login>.<magic>.`. Restart biasa tidak meresetnya. Tester membersihkan state per pass supaya hasil tidak terkontaminasi pass sebelumnya.

- DD diukur dari **puncak ekuitas yang teramati sejak EA pertama dipasang**, bukan seluruh riwayat akun. Floating P/L ikut dihitung. Baseline hari/minggu diperbarui pada event pertama periode baru; terminal yang mati tidak dapat merekonstruksi ekuitas historis yang terlewat.
- Guard mengukur **ekuitas seluruh akun**, tetapi hanya menutup posisi/order **milik EA pada simbolnya**. Kerugian dari trading lain tetap memengaruhi guard dan tidak ditutup EA.
- Tidak ada penyesuaian otomatis untuk deposit/withdrawal. Jangan melakukan arus dana atau trading lain saat pengujian/pengoperasian; rekonsiliasi baseline dalam keadaan flat terlebih dahulu.
- Lock DD 8%/10% tidak otomatis pulih. Setelah evaluasi, **flat-kan akun, hapus EA, dan catat statistik terlebih dahulu**. Reset state dengan menghapus Global Variables berprefix EA melalui F3 hanya jika sengaja memulai periode risiko baru. Jangan menghapus state untuk menyembunyikan drawdown. State terminal tidak berpindah otomatis ke VPS/terminal baru dan bisa kedaluwarsa setelah lama tidak dipakai.
- Menghapus/reconfigure EA berupaya membatalkan pending, tetapi **tidak menutup posisi terbuka**. Posisi tersebut hanya memiliki SL/TP server sampai EA kembali aktif. Jangan mengandalkan pembatalan saat koneksi terputus.

## Aturan entry yang benar-benar diimplementasikan

1. **H1:** candle tertutup di atas EMA200 dan EMA meningkat dibanding 3 candle sebelumnya untuk buy; kebalikannya untuk sell.
2. **M15:** dua pivot high dan dua pivot low terakhir sama-sama meningkat untuk buy, menurun untuk sell. Pivot default memerlukan 2 candle tertutup di setiap sisi; tidak memakai candle masa depan sebelum tersedia.
3. **M5:** sweep pivot low/high yang **sudah terkonfirmasi sebelum candle sweep**, lalu close kembali di sisi level sebelumnya. Ekstrem sweep harus berada dalam 0,5 ATR M5 dari pivot support/resistance M15 terakhir.
4. Dalam maksimal 3 candle berikutnya, close harus menembus pivot minor berlawanan yang dibekukan pada saat sweep. Candle harus searah tren dan body minimal 0,8 ATR. Setup batal jika ekstrem sweep ditembus lagi atau arah tren berubah.
5. **RSI8 M5:** buy memerlukan RSI >50 dan meningkat; sell <50 dan menurun. Semua memakai candle tertutup. Bisa dinonaktifkan untuk perbandingan A/B.
6. Entry limit pada **titik tengah body candle konfirmasi**, bukan midpoint seluruh wick. SL di luar ekstrem sweep + buffer 0,2 ATR. ATR memakai candle sebelum candle sinyal.
7. TP 2R harus berada sebelum pivot penghalang M15 terakhir dengan buffer spread. Jika ruang tidak cukup, tidak entry.
8. Pending kedaluwarsa setelah 3 candle M5 di **server broker**. Broker yang tidak mendukung expiration timestamp akan dilewati; tidak diturunkan menjadi GTC yang bisa terisi tanpa pengawasan.
9. Tidak entry ketika range candle >3 ATR, estimasi spread + komisi + slippage >10% risiko harga, di luar sesi, saat blackout berita, atau guard risiko aktif. Pending juga dibatalkan saat kondisi biaya/risiko tidak lagi memenuhi syarat atau tren berubah.

Filter ini sengaja ketat dan bisa menghasilkan **sedikit atau tidak ada transaksi** pada periode tertentu. Tidak ada FVG/order block/divergence subjektif. Parameter belum dioptimasi; nama “SMC/ICT” tidak membuktikan keunggulan statistik.

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

Uji manual MT5 yang masih wajib: default tester berhasil init dengan warning tanpa berita; toggle skip false menolak kalender; manual news tetap memblokir sesuai timestamp; input live trading tetap false di demo/real; preset fixed mengirim lot yang diminta hanya jika budget cocok. Mode chart M15 tetap memakai sinyal internal M5, bukan strategi entry M15 terpisah. **Belum diverifikasi melalui MT5 di workspace ini.**

## Referensi API resmi

- [OrderCalcProfit: estimasi profit/loss dalam mata uang akun](https://www.mql5.com/en/docs/trading/ordercalcprofit)
- [OrderCalcMargin](https://www.mql5.com/en/docs/trading/ordercalcmargin)
- [CTrade::BuyLimit dan pemeriksaan retcode](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuylimit)
- [CalendarValueHistory: waktu server](https://www.mql5.com/en/docs/calendar/calendarvaluehistory)
- [Kalender ekonomi dan keterbatasan tester](https://www.mql5.com/en/book/advanced/calendar)
- [Kompilasi melalui MetaEditor](https://www.metatrader5.com/en/metaeditor/help/development/compile)
