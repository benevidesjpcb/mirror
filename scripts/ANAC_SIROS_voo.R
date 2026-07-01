#!/usr/bin/env Rscript
# Baixa dados de voos da API SIROS/SAS da ANAC.
#
# API docs (pagina oficial):
#   - Voos (um dia):      https://sas.anac.gov.br/sas/siros_api/voos?dataReferencia=ddMMaaaa
#   - Voos (periodo):     https://sas.anac.gov.br/sas/siros_api/api/voosPeriodo?dataReferenciaInicio=ddMMaaaa&dataReferenciaFinal=ddMMaaaa
#   - Registros vigentes: https://siros.anac.gov.br/siros/registros/registros/registros.csv
#   - SSimFile (IATA):    https://sas.anac.gov.br/sas/siros_api/ssimfile?ds_temporada=S26
#
# Uso via linha de comando:
#   Rscript scripts/ANAC_SIROS_voo.R --data 10-12-2025
#   Rscript scripts/ANAC_SIROS_voo.R --inicio 01-12-2025 --fim 10-12-2025
#   Rscript scripts/ANAC_SIROS_voo.R --registros
#
# Uso interativo (RStudio): defina as variaveis abaixo e chame as funcoes
# baixar_voos_dia(), baixar_voos_periodo() ou baixar_registros() direto.
#
# Cada download de voos (--data / --inicio+--fim) salva 3 arquivos com o
# mesmo nome base, prefixado com "voos_siros_": o .json bruto, um .csv
# (sempre) e um .parquet (se o pacote 'arrow' estiver instalado:
# install.packages("arrow")).

PROJECT_ROOT <- local({
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(script_arg) == 1) {
    dirname(dirname(normalizePath(sub("^--file=", "", script_arg))))
  } else {
    "."
  }
})
source(file.path(PROJECT_ROOT, "scripts", "anac_utils.R"))

BASE <- "https://sas.anac.gov.br/sas/siros_api"
DATA_DIR <- file.path(PROJECT_ROOT, "data", "anac")

baixar_voos_dia <- function(data_str) {
  ref <- fmt_data(data_str)
  url <- sprintf("%s/voos?dataReferencia=%s", BASE, ref)
  base_sem_ext <- file.path(DATA_DIR, "voos", sprintf("voos_siros_%s", ref))
  baixar_e_tabular(url, base_sem_ext)
}

baixar_voos_periodo <- function(inicio_str, fim_str) {
  ini <- fmt_data(inicio_str)
  fim <- fmt_data(fim_str)
  url <- sprintf("%s/api/voosPeriodo?dataReferenciaInicio=%s&dataReferenciaFinal=%s", BASE, ini, fim)
  base_sem_ext <- file.path(DATA_DIR, "voos", sprintf("voos_siros_periodo_%s_a_%s", ini, fim))
  baixar_e_tabular(url, base_sem_ext)
}

baixar_registros <- function() {
  url <- "https://siros.anac.gov.br/siros/registros/registros/registros.csv"
  destino <- file.path(DATA_DIR, "registros", "registros.csv")
  baixar(url, destino)
}

.main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    cat("Uso:\n")
    cat("  Rscript scripts/ANAC_SIROS_voo.R --data dd-MM-aaaa\n")
    cat("  Rscript scripts/ANAC_SIROS_voo.R --inicio dd-MM-aaaa --fim dd-MM-aaaa\n")
    cat("  Rscript scripts/ANAC_SIROS_voo.R --registros\n")
    return(invisible(NULL))
  }

  get_arg <- function(flag) {
    idx <- which(args == flag)
    if (length(idx) == 0) return(NULL)
    args[idx + 1]
  }

  data_arg <- get_arg("--data")
  inicio_arg <- get_arg("--inicio")
  fim_arg <- get_arg("--fim")
  registros_arg <- "--registros" %in% args

  if (!is.null(data_arg)) baixar_voos_dia(data_arg)
  if (!is.null(inicio_arg) && !is.null(fim_arg)) baixar_voos_periodo(inicio_arg, fim_arg)
  if (registros_arg) baixar_registros()
}

if (identical(environment(), globalenv()) && !interactive()) {
  .main()
}
