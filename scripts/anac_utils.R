# Funcoes utilitarias compartilhadas pelos scripts de download da ANAC
# (ANAC_SIROS_voo.R e ANAC_VRA_voo.R). Nao roda standalone — e' sourced.

for (pkg in c("httr", "jsonlite")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}
library(httr)

#' Converte 'dd-MM-aaaa' (ou 'aaaa-MM-dd') para o formato ddMMaaaa (API SIROS)
fmt_data <- function(data_str) {
  formatos <- c("%d-%m-%Y", "%Y-%m-%d")
  for (f in formatos) {
    d <- as.Date(data_str, format = f)
    if (!is.na(d)) return(format(d, "%d%m%Y"))
  }
  stop(sprintf("Data invalida: %s. Use dd-MM-aaaa.", data_str))
}

#' Converte 'dd-MM-aaaa' (ou 'aaaa-MM-dd') para o formato aaaa-MM-dd (API VRA)
fmt_data_iso <- function(data_str) {
  formatos <- c("%d-%m-%Y", "%Y-%m-%d")
  for (f in formatos) {
    d <- as.Date(data_str, format = f)
    if (!is.na(d)) return(format(d, "%Y-%m-%d"))
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

#' Converte o JSON baixado em uma tabela (data.frame). Lida com respostas
#' ja tabulares, com um nivel extra de aninhamento, ou com o corpo inteiro
#' vindo como uma string contendo JSON ("JSON dobrado").
converter_para_tabela <- function(caminho_json) {
  dados <- jsonlite::fromJSON(caminho_json, flatten = TRUE)

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

#' Baixa o JSON de `url`, converte para tabela e salva CSV/Parquet ao lado
#' do JSON, todos com o mesmo nome base (`base_sem_extensao`).
baixar_e_tabular <- function(url, base_sem_extensao) {
  destino_json <- paste0(base_sem_extensao, ".json")
  baixar(url, destino_json)
  tabela <- converter_para_tabela(destino_json)
  salvar_tabela(tabela, base_sem_extensao)
  invisible(tabela)
}

#' Descobre a raiz do projeto a partir do caminho do script Rscript em
#' execucao (assume que o script esta em <raiz>/scripts/*.R). Se nao for
#' possivel detectar (ex.: codigo colado no console), assume que o
#' diretorio de trabalho atual JA E a raiz do projeto.
detectar_project_root <- function() {
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(script_arg) == 1) {
    script_path <- normalizePath(sub("^--file=", "", script_arg))
    return(dirname(dirname(script_path)))
  }
  "."
}
