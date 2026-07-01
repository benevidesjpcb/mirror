# Dados

Estrutura de dados para analise cruzada entre voos regulares (ANAC) e planos de voo (FPL).

## `anac/`

Dados baixados das APIs da ANAC. Cada download gera 3 arquivos com o mesmo nome base: `.json`
(bruto), `.csv` (sempre) e `.parquet` (se o pacote R `arrow` estiver instalado).

- `anac/voos/` — respostas dos endpoints de voos, prefixadas por origem:
  - `voos_siros_*` — API SIROS (`scripts/ANAC_SIROS_voo.R`)
  - `voos_vra_*` — API VRA (`scripts/ANAC_VRA_voo.R`)
- `anac/registros/` — CSV de registros vigentes de empresas/voos (SIROS).
- `anac/aerodromos/` — consultas de aerodromo (VRA).
- `anac/cruzamento/` — `cruzamento_*` gerado por `scripts/cruzar_siros_vra.R`, cruzando
  SIROS e VRA (colunas padronizadas, horarios convertidos para UTC).

### Fuso horario

- **SIROS**: os proprios nomes das colunas dizem (`dt_partida_prevista_utc`,
  `dt_chegada_prevista_utc`) — ja vem em **UTC**.
- **VRA**: confirmado empiricamente (voo TAP 0009 LPPT→SBSG de 10/12/2025) que os horarios
  (`dt_partida_prevista`, `dt_partida_real`, `dt_chegada_prevista`, `dt_chegada_real`) vem em
  **horario de Brasilia (UTC-3), fixo**, independente do fuso real do aeroporto de
  origem/destino. `scripts/cruzar_siros_vra.R` soma 3h a esses campos para converter para UTC.

### API SIROS (`scripts/ANAC_SIROS_voo.R`)

- Voos (um dia): `https://sas.anac.gov.br/sas/siros_api/voos?dataReferencia=ddMMaaaa`
- Voos (periodo): `https://sas.anac.gov.br/sas/siros_api/api/voosPeriodo?dataReferenciaInicio=ddMMaaaa&dataReferenciaFinal=ddMMaaaa`
- Registros vigentes (CSV): `https://siros.anac.gov.br/siros/registros/registros/registros.csv`
- SSimFile (IATA, por temporada): `https://sas.anac.gov.br/sas/siros_api/ssimfile?ds_temporada=S26`

```bash
Rscript scripts/ANAC_SIROS_voo.R --data 10-12-2025
```

### API VRA (`scripts/ANAC_VRA_voo.R`)

- Por periodo: `https://sas.anac.gov.br/sas/vra_api/vra?dt_referencia1={ddmmyyyy}&dt_referencia2={ddmmyyyy}`
- Por dia: `https://sas.anac.gov.br/sas/vra_api/vra/data?dt_voo={ddmmyyyy}`
- Voo especifico: `https://sas.anac.gov.br/sas/vra_api/vra/voo?dt_voo={ddmmyyyy}&sg_empresa_icao={..}&sg_icao_origem={..}&sg_icao_destino={..}&nr_voo={..}`
- Aerodromo: `https://sas.anac.gov.br/sas/vra_api/aerodromo?sg_aerodromo_icao_ou_iata={..}`

```bash
Rscript scripts/ANAC_VRA_voo.R --data 10-12-2025
```

Este ambiente de execucao bloqueia acesso direto a `sas.anac.gov.br` (politica de rede). Baixe os
arquivos localmente (fora do sandbox) com os scripts acima e coloque-os aqui, ou ajuste a politica
de rede do ambiente.

### Cruzamento (`scripts/cruzar_siros_vra.R`)

Depois de baixar SIROS e VRA para a mesma data, cruza os dois por empresa + numero de voo +
origem + destino + data de referencia:

```bash
Rscript scripts/cruzar_siros_vra.R --data 10-12-2025
```

## `fpl/`

Dados de plano de voo (FPL) do usuario, para cruzamento com os dados de voos da ANAC.
