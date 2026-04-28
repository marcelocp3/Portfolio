#!/usr/bin/env python3
import csv
import json
import sys
import time
from datetime import date
from pathlib import Path
from urllib.request import urlopen


TICKERS = [
    "AAPL", "AMGN", "AMZN", "AXP", "BA", "CAT", "CRM", "CSCO", "CVX", "DIS",
    "GS", "HD", "HON", "IBM", "JNJ", "JPM", "KO", "MCD", "MMM", "MRK",
    "MSFT", "NKE", "NVDA", "PG", "SHW", "TRV", "UNH", "V", "VZ", "WMT",
]

START = date.fromisoformat("2025-07-01")
END = date.fromisoformat("2025-12-31")
API_URL = "https://www.pocketportfolio.app/api/tickers/{ticker}/json"
OUTPUT = Path("data/dow30_prices_2025H2.csv")
SOURCE_NOTE = Path("data/dow30_prices_2025H2.source.txt")


def fetch_ticker(ticker):
    with urlopen(API_URL.format(ticker=ticker), timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))
    rows = payload.get("data", [])
    prices = {}
    for row in rows:
        row_date = date.fromisoformat(row["date"])
        if START <= row_date <= END and row.get("close") is not None:
            prices[row["date"]] = row["close"]
    if not prices:
        raise RuntimeError(f"sem dados para {ticker}")
    return prices


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    by_ticker = {}
    for ticker in TICKERS:
        print(f"baixando {ticker}...", file=sys.stderr)
        by_ticker[ticker] = fetch_ticker(ticker)
        time.sleep(0.15)

    common_dates = sorted(set.intersection(*(set(prices) for prices in by_ticker.values())))
    if not common_dates:
        raise RuntimeError("nenhuma data comum encontrada entre os 30 ativos")

    with OUTPUT.open("w", newline="") as output_file:
        writer = csv.writer(output_file, lineterminator="\n")
        writer.writerow(["Date", *TICKERS])
        for day in common_dates:
            writer.writerow([day, *[by_ticker[ticker][day] for ticker in TICKERS]])

    SOURCE_NOTE.write_text(
        "Fonte: Pocket Portfolio JSON endpoint, um endpoint publico sem chave.\n"
        "Endpoint: https://www.pocketportfolio.app/api/tickers/{TICKER}/json\n"
        "Campo usado: close\n"
        "Periodo filtrado: 2025-07-01 a 2025-12-31\n"
        f"Ativos: {', '.join(TICKERS)}\n"
        f"Datas comuns geradas: {len(common_dates)}\n",
        encoding="utf-8",
    )
    print(f"gerado {OUTPUT} com {len(common_dates)} datas comuns")


if __name__ == "__main__":
    main()
