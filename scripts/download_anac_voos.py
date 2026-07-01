#!/usr/bin/env python3
"""
Baixa dados de voos da API SIROS/SAS da ANAC.

API docs (pagina oficial):
  - Voos (um dia):      https://sas.anac.gov.br/sas/siros_api/voos?dataReferencia=ddMMaaaa
  - Voos (periodo):     https://sas.anac.gov.br/sas/siros_api/api/voosPeriodo?dataReferenciaInicio=ddMMaaaa&dataReferenciaFinal=ddMMaaaa
  - Registros vigentes: https://siros.anac.gov.br/siros/registros/registros/registros.csv
  - SSimFile (IATA):    https://sas.anac.gov.br/sas/siros_api/ssimfile?ds_temporada=S26

Uso:
  python3 download_anac_voos.py --data 10-12-2025
  python3 download_anac_voos.py --inicio 01-12-2025 --fim 10-12-2025
  python3 download_anac_voos.py --registros
"""
import argparse
import datetime
import pathlib
import sys

import requests

BASE = "https://sas.anac.gov.br/sas/siros_api"
DATA_DIR = pathlib.Path(__file__).resolve().parent.parent / "data" / "anac"


def fmt_data(data_str: str) -> str:
    """Converte 'dd-MM-aaaa' (ou 'aaaa-MM-dd') para o formato ddMMaaaa exigido pela API."""
    for fmt in ("%d-%m-%Y", "%Y-%m-%d"):
        try:
            d = datetime.datetime.strptime(data_str, fmt)
            return d.strftime("%d%m%Y")
        except ValueError:
            continue
    raise ValueError(f"Data invalida: {data_str}. Use dd-MM-aaaa.")


def baixar(url: str, destino: pathlib.Path) -> None:
    print(f"Baixando: {url}")
    resp = requests.get(url, timeout=60)
    resp.raise_for_status()
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_bytes(resp.content)
    print(f"Salvo em: {destino} ({len(resp.content)} bytes)")


def baixar_voos_dia(data_str: str) -> None:
    ref = fmt_data(data_str)
    url = f"{BASE}/voos?dataReferencia={ref}"
    destino = DATA_DIR / "voos" / f"voos_{ref}.json"
    baixar(url, destino)


def baixar_voos_periodo(inicio_str: str, fim_str: str) -> None:
    ini = fmt_data(inicio_str)
    fim = fmt_data(fim_str)
    url = f"{BASE}/api/voosPeriodo?dataReferenciaInicio={ini}&dataReferenciaFinal={fim}"
    destino = DATA_DIR / "voos" / f"voos_periodo_{ini}_a_{fim}.json"
    baixar(url, destino)


def baixar_registros() -> None:
    url = "https://siros.anac.gov.br/siros/registros/registros/registros.csv"
    destino = DATA_DIR / "registros" / "registros.csv"
    baixar(url, destino)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", help="Data de referencia unica, formato dd-MM-aaaa (ex: 10-12-2025)")
    parser.add_argument("--inicio", help="Data inicial do periodo, formato dd-MM-aaaa")
    parser.add_argument("--fim", help="Data final do periodo, formato dd-MM-aaaa")
    parser.add_argument("--registros", action="store_true", help="Baixa o CSV de registros vigentes")
    args = parser.parse_args()

    if not any([args.data, (args.inicio and args.fim), args.registros]):
        parser.print_help()
        return 1

    if args.data:
        baixar_voos_dia(args.data)
    if args.inicio and args.fim:
        baixar_voos_periodo(args.inicio, args.fim)
    if args.registros:
        baixar_registros()
    return 0


if __name__ == "__main__":
    sys.exit(main())
