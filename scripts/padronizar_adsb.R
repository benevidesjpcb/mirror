#!/usr/bin/env Rscript
# Padroniza dados brutos de ADS-B e enriquece com a matricula da aeronave
# usando a base publica da OpenSky Network. Ver processo_adsb.qmd pro
# relato completo da investigacao por tras de cada decisao abaixo.
#
# Descobertas (confirmadas com dados reais antes de escrever este script):
#   - O arquivo usa ";" como separador de coluna e "." como marcador
#     decimal. read_csv2() (que assume decimal ",") corrompe colunas
#     numericas com casas decimais -- os digitos ficam "grudados" sem o
#     ponto (ex: 35.4913330078125 vira 354913330078125). Usar
#     read_delim(..., delim=";", locale=locale(decimal_mark=".")).
#   - dt_point ja e' o timestamp completo (data+hora) em UTC. daily_epoch
#     e' aproximadamente o mesmo instante (mais impreciso, quantizado no
#     ciclo de varredura do radar, ~4s) -- nao precisa somar os dois, so
#     confunde (soma duplicada de horario gerava datas erradas, "vazando"
#     pro dia seguinte).
#   - taddr e' o endereco ICAO24/Mode-S da aeronave, gravado como numero
#     decimal -- precisa converter pra hex (6 digitos, minusculo) pra
#     bater com o formato usado nas bases publicas de aeronaves.
#   - Nao existe formula publica documentada pra calcular o ICAO24 a
#     partir da matricula brasileira (PP/PT/PR/PS/PU). Tentamos reverter
#     com 2 pares reais (PR-GUV/E48B01 e PR-GXV/E48FB6) e a estrutura
#     assumida (base-26 nas 3 ultimas letras + offset fixo por prefixo)
#     nao bateu no segundo caso -- abandonado.
#   - A base de aeronaves da OpenSky Network
#     (https://opensky-network.org/data/aircraft) cobre aeronaves
#     brasileiras e serve como fonte pronta de
#     icao24 -> matricula/fabricante/modelo/operador, sem precisar de
#     formula. Os snapshots "complete" usam aspas simples (') pra
#     demarcar texto -- ler com read_csv(..., quote = "'"). Cobertura
#     medida: ~92,6% dos pontos de ADS-B casaram com o snapshot de
#     2025-08 (vs. 69,6% com a amostra pequena da OpenSky).
#
# Uso interativo:
#   source("scripts/padronizar_adsb.R")
#   adsb <- padronizar_adsb(
#     caminho_adsb = "./data-src/adsb_2026_03_15.csv",
#     caminho_aircraft_db = "./data-src/aircraft-database-complete-2025-08.csv"
#   )
#
# Os arquivos de entrada (ADS-B bruto, base de aeronaves) e a saida ficam
# em data-src/, que e' local e ignorado pelo git (arquivos grandes demais
# pra versionar).

library(dplyr)
library(readr)

PROJECT_ROOT <- local({
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(script_arg) == 1) {
    dirname(dirname(normalizePath(sub("^--file=", "", script_arg))))
  } else {
    "."
  }
})
source(file.path(PROJECT_ROOT, "scripts", "anac_utils.R"))

#' Le o CSV bruto de ADS-B com o separador (;) e decimal (.) corretos, e
#' monta o icao24 (hex) de cada ponto a partir do taddr (decimal).
#' dt_point ja vem como o timestamp completo em UTC, sem necessidade de
#' combinar com daily_epoch.
ler_adsb <- function(caminho_adsb) {
  bruto <- read_delim(caminho_adsb, delim = ";", locale = locale(decimal_mark = "."), show_col_types = FALSE)

  bruto %>%
    mutate(
      tid = trimws(tid),
      timestamp_utc = dt_point,
      icao24 = sprintf("%06x", taddr)
    )
}

#' Le um snapshot "complete" da base de aeronaves da OpenSky Network, que
#' usa aspas simples como delimitador de texto.
ler_aircraft_db <- function(caminho_aircraft_db) {
  read_csv(caminho_aircraft_db, quote = "'", show_col_types = FALSE)
}

#' Junta os pontos de ADS-B com matricula/fabricante/modelo/operador da
#' aeronave, casando por icao24.
enriquecer_com_matricula <- function(adsb, aircraft_db) {
  adsb %>%
    left_join(
      aircraft_db %>% select(icao24, registration, manufacturerName, model, operator),
      by = "icao24"
    )
}

#' Le o ADS-B e a base de aeronaves, junta os dois e salva o resultado
#' (CSV sempre, Parquet se o pacote arrow estiver instalado) ao lado do
#' arquivo de ADS-B original.
padronizar_adsb <- function(caminho_adsb, caminho_aircraft_db, caminho_saida = NULL) {
  adsb <- ler_adsb(caminho_adsb)
  aircraft_db <- ler_aircraft_db(caminho_aircraft_db)
  resultado <- enriquecer_com_matricula(adsb, aircraft_db)

  if (is.null(caminho_saida)) {
    caminho_saida <- sub("\\.csv$", "_com_matricula", caminho_adsb)
  }
  salvar_tabela(resultado, caminho_saida)
  invisible(resultado)
}
