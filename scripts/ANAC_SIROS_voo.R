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
# mesmo nome base: o .json bruto, um .csv (sempre) e um .parquet (se o
# pacote 'arrow' estiver instalado: install.packages("arrow")).

for (pkg in c("httr", "jsonlite")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}
library(httr)

BASE <- "https://sas.anac.gov.br/sas/siros_api"

# Descobre a raiz do projeto (pasta que contem scripts/ANAC_SIROS_voo.R).
# Se nao conseguir (ex.: rodando o codigo colado no console), assume que o
# diretorio de trabalho atual JA E a raiz do projeto.
.script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(.script_arg) == 1) {
  .script_path <- normalizePath(sub("^--file=", "", .script_arg))
  PROJECT_ROOT <- dirname(dirname(.script_path))
} else {
  PROJECT_ROOT <- "."
}
DATA_DIR <- file.path(PROJECT_ROOT, "data", "anac")

#' Converte 'dd-MM-aaaa' (ou 'aaaa-MM-dd') para o formato ddMMaaaa exigido pela API
fmt_data <- function(data_str) {
  formatos <- c("%d-%m-%Y", "%Y-%m-%d")
  for (f in formatos) {
    d <- as.Date(data_str, format = f)
    if (!is.na(d)) {
      return(format(d, "%d%m%Y"))
    }
  }
  stop(sprintf("Data invalida: %s. Use dd-MM-aaaa.", data_str))
}

baixar <- function(url, destino) {
  cat(sprintf("Baixando: %s\n", url))
  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)
  resp <- httr::GET(url, httr::timeout(60))
  httr::stop_for_status(resp)
  writeBin(httr::content(resp, as = "raw"), destino)
  cat(sprintf("Salvo em: %s (%d bytes)\n", destino, file.info(destino)$size))
}

#' Converte o JSON baixado em uma tabela (data.frame), tentando lidar com
#' respostas ja tabulares ou com um nivel extra de aninhamento.
converter_para_tabela <- function(caminho_json) {
  dados <- jsonlite::fromJSON(caminho_json, flatten = TRUE)

  # A API retorna o corpo como uma string contendo JSON (JSON "dobrado").
  # Reparseia enquanto o resultado ainda for uma unica string.
  while (is.character(dados) && length(dados) == 1) {
    dados <- jsonlite::fromJSON(dados, flatten = TRUE)
  }

  if (is.data.frame(dados)) {
    return(dados)
  }

  if (is.list(dados)) {
    candidatos <- Filter(function(x) is.data.frame(x) || (is.list(x) && length(x) > 0), dados)
    if (length(candidatos) > 0) {
      primeiro <- candidatos[[1]]
      if (is.data.frame(primeiro)) return(primeiro)
      return(jsonlite::fromJSON(jsonlite::toJSON(primeiro), flatten = TRUE))
    }
  }

  stop("Nao foi possivel identificar uma tabela dentro do JSON retornado.")
}

#' Salva a tabela em CSV (sempre) e em Parquet (se o pacote 'arrow' estiver
#' instalado). Instale com install.packages("arrow") para habilitar Parquet.
salvar_tabela <- function(tabela, caminho_sem_extensao) {
  caminho_csv <- paste0(caminho_sem_extensao, ".csv")
  utils::write.csv(tabela, caminho_csv, row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("Tabela CSV salva em: %s (%d linhas)\n", caminho_csv, nrow(tabela)))

  if (requireNamespace("arrow", quietly = TRUE)) {
    caminho_parquet <- paste0(caminho_sem_extensao, ".parquet")
    arrow::write_parquet(tabela, caminho_parquet)
    cat(sprintf("Tabela Parquet salva em: %s\n", caminho_parquet))
  } else {
    cat("Pacote 'arrow' nao encontrado — Parquet nao gerado. Instale com install.packages(\"arrow\") para habilitar.\n")
  }
}

baixar_voos_dia <- function(data_str) {
  ref <- fmt_data(data_str)
  url <- sprintf("%s/voos?dataReferencia=%s", BASE, ref)
  destino_json <- file.path(DATA_DIR, "voos", sprintf("voos_%s.json", ref))
  baixar(url, destino_json)

  tabela <- converter_para_tabela(destino_json)
  base_sem_ext <- file.path(DATA_DIR, "voos", sprintf("voos_%s", ref))
  salvar_tabela(tabela, base_sem_ext)
  invisible(tabela)
}

baixar_voos_periodo <- function(inicio_str, fim_str) {
  ini <- fmt_data(inicio_str)
  fim <- fmt_data(fim_str)
  url <- sprintf("%s/api/voosPeriodo?dataReferenciaInicio=%s&dataReferenciaFinal=%s", BASE, ini, fim)
  destino_json <- file.path(DATA_DIR, "voos", sprintf("voos_periodo_%s_a_%s.json", ini, fim))
  baixar(url, destino_json)

  tabela <- converter_para_tabela(destino_json)
  base_sem_ext <- file.path(DATA_DIR, "voos", sprintf("voos_periodo_%s_a_%s", ini, fim))
  salvar_tabela(tabela, base_sem_ext)
  invisible(tabela)
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
