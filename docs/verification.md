# GoldAutoScalp v2.00 — bukti verifikasi, 20 September 2026

## Lulus di workspace ini

- Konsistensi distribusi utama GoldAutoScalp dan distribusi lama GoldTrendSweep dengan modul yang diuji.
- Lima Python distribution/preset tests.
- C++ risk tests, termasuk 4.995 kasus sizing.
- C++ signal tests untuk strategi lama.
- C++ pipeline GoldAutoScalp: buy/sell, SL/TP minimal 2R, pemicu 1R, penolakan broker, permission, spread, minimum lot, dan lot turun sesuai margin.
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

## Kompilasi MetaEditor dan backtest MT5 belum terverifikasi

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
