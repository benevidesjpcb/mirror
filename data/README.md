# Dados

Estrutura de dados para analise cruzada entre voos regulares (ANAC/SIROS) e planos de voo (FPL).

## `anac/`

Dados baixados da API SIROS/SAS da ANAC.

- `anac/voos/` — respostas do endpoint de voos (por dia ou por periodo).
- `anac/registros/` — CSV de registros vigentes de empresas/voos.

Endpoints (ver `scripts/download_anac_voos.py`):

- Voos (um dia): `https://sas.anac.gov.br/sas/siros_api/voos?dataReferencia=ddMMaaaa`
- Voos (periodo): `https://sas.anac.gov.br/sas/siros_api/api/voosPeriodo?dataReferenciaInicio=ddMMaaaa&dataReferenciaFinal=ddMMaaaa`
- Registros vigentes (CSV): `https://siros.anac.gov.br/siros/registros/registros/registros.csv`
- SSimFile (IATA, por temporada): `https://sas.anac.gov.br/sas/siros_api/ssimfile?ds_temporada=S26`

Este ambiente de execucao bloqueia acesso direto a `sas.anac.gov.br` (politica de rede). Baixe os
arquivos localmente (fora do sandbox) com o script abaixo e coloque-os aqui, ou ajuste a politica
de rede do ambiente.

```bash
pip install requests
python3 scripts/download_anac_voos.py --data 10-12-2025
```

## `fpl/`

Dados de plano de voo (FPL) do usuario, para cruzamento com os dados de voos da ANAC.
