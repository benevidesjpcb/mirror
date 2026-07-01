#!/usr/bin/env Rscript
# Padroniza e cruza os dados de voos da API SIROS e da API VRA da ANAC.
#
# Fuso horario confirmado empiricamente (voo TAP 0009 LPPT->SBSG em
# 10/12/2025): o SIROS reporta horarios em UTC (ja fica explicito no nome
# da coluna, "_utc"). O VRA reporta em horario de Brasilia (UTC-3, fixo,
# independente do fuso real do aeroporto de origem/destino) — por isso
# somamos 3 horas aos horarios do VRA para converter para UTC e permitir
# a comparacao/cruzamento com o SIROS.
#
# Uso via linha de comando:
#   Rscript scripts/cruzar_siros_vra.R --data 10-12-2025
#
# Uso interativo (RStudio):
#   source("scripts/cruzar_siros_vra.R")
#   cruzamento <- cruzar_data("10-12-2025")
#
# Le voos_siros_<ref>.csv e voos_vra_<ref>.csv de data/anac/voos/ (ja
# baixados com ANAC_SIROS_voo.R e ANAC_VRA_voo.R) e salva o cruzamento em
# data/anac/cruzamento/cruzamento_<ref>.{csv,parquet}.

PROJECT_ROOT <- local({
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(script_arg) == 1) {
    dirname(dirname(normalizePath(sub("^--file=", "", script_arg))))
  } else {
    "."
  }
})
source(file.path(PROJECT_ROOT, "scripts", "anac_utils.R"))

DATA_DIR <- file.path(PROJECT_ROOT, "data", "anac")

#' Converte string "dd/MM/aaaa HH:MM" (formato das duas APIs) em POSIXct.
parse_dt <- function(x) {
  as.POSIXct(x, format = "%d/%m/%Y %H:%M", tz = "UTC")
}

#' Renomeia/seleciona as colunas do SIROS para o esquema padrao.
padronizar_siros <- function(df) {
  data.frame(
    empresa = df$sg_empresa_icao,
    numero_voo = df$nr_voo,
    origem = df$sg_icao_origem,
    destino = df$sg_icao_destino,
    dt_referencia = df$dt_referencia,
    partida_prevista_utc = parse_dt(df$dt_partida_prevista_utc),
    chegada_prevista_utc = parse_dt(df$dt_chegada_prevista_utc),
    stringsAsFactors = FALSE
  )
}

#' Renomeia/seleciona as colunas do VRA para o esquema padrao, convertendo
#' os horarios (horario de Brasilia) para UTC.
padronizar_vra <- function(df) {
  tres_horas <- as.difftime(3, units = "hours")
  data.frame(
    empresa = df$sg_empresa_icao,
    numero_voo = df$nr_voo,
    origem = df$sg_icao_origem,
    destino = df$sg_icao_destino,
    dt_referencia = df$dt_referencia,
    partida_prevista_utc = parse_dt(df$dt_partida_prevista) + tres_horas,
    chegada_prevista_utc = parse_dt(df$dt_chegada_prevista) + tres_horas,
    partida_real_utc = parse_dt(df$dt_partida_real) + tres_horas,
    chegada_real_utc = parse_dt(df$dt_chegada_real) + tres_horas,
    situacao_voo = df$ds_situacao_voo,
    justificativa = df$ds_justificativa,
    stringsAsFactors = FALSE
  )
}

#' Cruza os dois conjuntos padronizados por empresa + numero de voo +
#' origem + destino + data de referencia. Mantem voos que aparecem so em
#' um dos lados (full outer join).
cruzar_siros_vra <- function(siros_padronizado, vra_padronizado) {
  merge(
    siros_padronizado, vra_padronizado,
    by = c("empresa", "numero_voo", "origem", "destino", "dt_referencia"),
    all = TRUE, suffixes = c("_siros", "_vra")
  )
}

#' Le os CSVs ja baixados para uma data (dd-MM-aaaa), padroniza, cruza e
#' salva o resultado.
cruzar_data <- function(data_str) {
  ref <- fmt_data(data_str)

  siros <- read.csv(file.path(DATA_DIR, "voos", sprintf("voos_siros_%s.csv", ref)), stringsAsFactors = FALSE)
  vra <- read.csv(file.path(DATA_DIR, "voos", sprintf("voos_vra_%s.csv", ref)), stringsAsFactors = FALSE)

  cruzamento <- cruzar_siros_vra(padronizar_siros(siros), padronizar_vra(vra))

  base_sem_ext <- file.path(DATA_DIR, "cruzamento", sprintf("cruzamento_%s", ref))
  dir.create(dirname(base_sem_ext), recursive = TRUE, showWarnings = FALSE)
  salvar_tabela(cruzamento, base_sem_ext)
  invisible(cruzamento)
}

.main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  get_arg <- function(flag) {
    idx <- which(args == flag)
    if (length(idx) == 0) return(NULL)
    args[idx + 1]
  }
  data_arg <- get_arg("--data")
  if (is.null(data_arg)) {
    cat("Uso:\n  Rscript scripts/cruzar_siros_vra.R --data dd-MM-aaaa\n")
    return(invisible(NULL))
  }
  cruzar_data(data_arg)
}

if (identical(environment(), globalenv()) && !interactive()) {
  .main()
}
