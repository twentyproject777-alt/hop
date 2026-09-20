# GoldAutoScalp v2.10 — bukti verifikasi, 20 September 2026

Pengguna telah melaporkan bahwa **v2.00 berhasil entry**, disertai equity curve yang menurun. Itu mengonfirmasi kemajuan eksekusi versi sebelumnya, bukan profitabilitas atau verifikasi versi2.10. Report HTML dan daftar deals belum tersedia; jumlah trade, win rate, dan penyebab loss tidak dapat dipastikan dari gambar grafik saja.

## Lulus di workspace ini

- Konsistensi distribusi utama GoldAutoScalp dan distribusi lama GoldTrendSweep dengan modul yang diuji.
- Tujuh Python distribution/preset/data-shift/guard tests.
- C++ risk tests, termasuk 4.995 kasus sizing.
- C++ signal tests untuk strategi lama.
- C++ pipeline GoldAutoScalp: buy/sell, SL/TP minimal 2R, pemicu 1R, penolakan broker, permission, spread, minimum lot, dan lot turun sesuai margin.
- Regresi v2.10: pullback EMA9 dan breakout continuation yang tidak lolos syarat pullback v2.00; penolakan slope M15 berlawanan, close salah sisi EMA20, EMA gap kecil, M5 berlawanan, RSI ekstrem, candle spike, dan quote bergeser.
- SL di luar wick, minimum-lot bridge yang tidak boleh melampaui sisa budget harian, **400 kombinasi budget/volatilitas**, dan batas filled-entry12/hari.
- Replay 300 candle sintetis melalui **fungsi produksi `GASProcess`**: 20 panggilan market order yang diterima test-double (10 buy, 10 sell). Broker test-double langsung mencatat fill; tidak mensimulasikan terminal MT5, indikator asli, account lifecycle, atau harga historis.
- Semua C++ suites dijalankan dengan `-Wall -Wextra -Werror -pedantic -fsanitize=address,undefined`.

Jalankan ulang dari root repository:

```sh
python3 scripts/build_auto_scalp.py --check
python3 scripts/build_standalone.py --check
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py' -v
mkdir -p /tmp/goldtrend-tests
for name in risk_math signal_math auto_scalp; do
  g++ -std=c++17 -Wall -Wextra -Werror -pedantic -fsanitize=address,undefined \
    "tests/${name}_test.cpp" -o "/tmp/goldtrend-tests/${name}_test" || exit 1
  "/tmp/goldtrend-tests/${name}_test" || exit 1
done
git diff --check
```

## Kompilasi MetaEditor dan backtest MT5 v2.10 belum terverifikasi

Workspace Ubuntu 24.04 ini berjalan pada kernel `4.19.0-gvisor`. Wine 9 dari Ubuntu, Xvfb, dan kemudian WineHQ 11 dicoba dengan prefix terisolasi. Installer MetaQuotes resmi diunduh, tetapi Wine gagal bahkan pada startup/command Windows dasar, sebelum MetaEditor tersedia:

```text
err:seh:segv_handler Got unexpected trap 0
err:virtual:virtual_setup_exception stack overflow
```

Ini kegagalan runtime verifikasi, **bukan hasil kompilasi EA**. Tidak ada `.ex5` yang berhasil dibuat atau hasil Strategy Tester broker yang dapat diklaim dari workspace ini. Tidak ada akun broker dibuat, kredensial diminta, atau transaksi dikirim ke broker. Tidak ada runtime/kernel yang dipatch untuk melewati isolasi sandbox. Instalasi Wine yang gagal tidak dijadikan setup default proyek.

Gunakan MetaEditor bawaan MT5 di Windows: buka `GoldAutoScalp.mq5`, lalu **F7**. Untuk runner Windows yang sudah mempunyai MetaEditor dan standard library, [CLI resmi](https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide) mendukung:

```text
metaeditor64.exe /compile:"C:\path\MQL5\Experts\GoldAutoScalp.mq5" /include:"C:\path\MQL5" /log
```

Periksa log dan file `.ex5` yang baru dihasilkan; jangan menganggap exit code saja sebagai bukti compile. Kompilasi tidak memerlukan akun broker. Backtest berikutnya memerlukan simbol/specifikasi/history yang benar, deposit $500, real ticks, dan **default Inputs tanpa preset**.

Sebelum menyebut entry MT5 terverifikasi, periksa `GAS2 MARKET SEND` beserta retcode/deal dan `GAS2 SUMMARY filled_entry_orders`, lalu cocokkan tab Deals/Results. Setelah itu verifikasi SL/TP aktual, BE 1R, restart, freeze level, partial fill/reject, time exit, dan loss guard. Uji profitabilitas/out-of-sample/forward demo adalah tahap terpisah.

## Pembandingan hasil — jangan menilai dari kurva saja

1. Simpan report **HTML Strategy Tester** dan daftar deals v2.00, termasuk periode, simbol, leverage, biaya/spread dan Inputs. Versi pembanding ada pada commit `3595ec7`. Jangan mengirim password; identitas akun boleh disamarkan.
2. Jalankan v2.10 pada broker, periode, deposit, model real-tick, leverage dan biaya yang sama. Tanpa preset. Simpan report HTML, deals dan baris `GAS2 TESTER`, `GAS2 SIGNALS`, `GAS2 BLOCKS`.
3. Bandingkan jumlah trade, win rate, profit factor, net expectancy per trade/per unit risiko, serta **maximum equity drawdown**. Risiko normal v2.10 lebih kecil; DD yang turun saja tidak membuktikan signal edge membaik.
4. Jangan hanya memilih periode yang profit. Uji periode yang belum dipakai untuk perubahan desain (out-of-sample) lalu forward demo, termasuk periode trending dan sideways. Jumlah sampel yang kecil tidak cukup untuk klaim win rate stabil.
5. Sasaran pengguna tetap win rate >50%, TP minimal2R, dan DD terkontrol. Ini **kriteria evaluasi**, bukan hasil yang sudah tercapai. Lebih banyak trade dengan PF/expectancy negatif berarti kandidat perlu ditolak atau direvisi berdasarkan trade-level evidence; bukan menaikkan lot atau menghapus guard.

| Bukti | v2.00 | v2.10 |
| --- | --- | --- |
| Entry di MT5 | Dilaporkan berhasil oleh pengguna | Belum diverifikasi |
| Win rate / PF / jumlah trade | Report/deals belum tersedia | Belum tersedia |
| Equity curve | Dilaporkan menurun | Belum tersedia |
| Unit/pipeline tests | Lulus pada revisi sebelumnya | Lulus; tidak mengukur profitabilitas |

Statistik `GAS2 TESTER` menggunakan [TesterStatistics](https://www.mql5.com/en/docs/common/testerstatistics) di `OnDeinit` tester. Tidak mengubah hasil tester, memilih hanya trade menang, atau menetapkan objective optimisasi yang mengabaikan risiko.
