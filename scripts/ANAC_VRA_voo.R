#!/usr/bin/env Rscript
# Baixa dados de voos da API VRA (Voos Regulares Ativos) da ANAC.
#
# API docs (pagina oficial "Lista de endpoints da API do VRA"):
#   - Por periodo:  GET https://sas.anac.gov.br/sas/vra_api/vra?dt_referencia1={dt}&dt_referencia2={dt}
#   - Por dia:      GET https://sas.anac.gov.br/sas/vra_api/vra/data?dt_voo={dt}
#   - Voo especifico: GET https://sas.anac.gov.br/sas/vra_api/vra/voo?dt_voo={dt}&sg_empresa_icao={..}&sg_icao_origem={..}&sg_icao_destino={..}&nr_voo={..}
#   - Aerodromo:    GET https://sas.anac.gov.br/sas/vra_api/aerodromo?sg_aerodromo_icao_ou_iata={..}
#
# Os parametros dt_referencia1/dt_referencia2/dt_voo usam o formato ddmmyyyy
# (mesmo formato do SIROS), conforme a documentacao oficial da API VRA.
#
# Uso via linha de comando:
#   Rscript scripts/ANAC_VRA_voo.R --data 10-12-2025
#   Rscript scripts/ANAC_VRA_voo.R --periodo 01-12-2025 10-12-2025
#   Rscript scripts/ANAC_VRA_voo.R --voo --dia 10-12-2025 --empresa TAP --numero 0009
#   Rscript scripts/ANAC_VRA_voo.R --aerodromo GRU
#
# Uso interativo (RStudio): defina as variaveis abaixo e chame as funcoes
# baixar_vra_dia(), baixar_vra_periodo(), consultar_vra_voo() ou
# consultar_aerodromo() direto.
#
# Cada download salva 3 arquivos com o mesmo nome base, prefixado com
# "voos_vra_": o .json bruto, um .csv (sempre) e um .parquet (se o pacote
# 'arrow' estiver instalado: install.packages("arrow")).

PROJECT_ROOT <- local({
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(script_arg) == 1) {
    dirname(dirname(normalizePath(sub("^--file=", "", script_arg))))
  } else {
    "."
  }
})
source(file.path(PROJECT_ROOT, "scripts", "anac_utils.R"))

BASE <- "https://sas.anac.gov.br/sas/vra_api"
DATA_DIR <- file.path(PROJECT_ROOT, "data", "anac")

baixar_vra_dia <- function(data_str) {
  dt <- fmt_data(data_str)
  url <- sprintf("%s/vra/data?dt_voo=%s", BASE, dt)
  base_sem_ext <- file.path(DATA_DIR, "voos", sprintf("voos_vra_%s", dt))
  baixar_e_tabular(url, base_sem_ext)
}

baixar_vra_periodo <- function(inicio_str, fim_str) {
  ini <- fmt_data(inicio_str)
  fim <- fmt_data(fim_str)
  url <- sprintf("%s/vra?dt_referencia1=%s&dt_referencia2=%s", BASE, ini, fim)
  base_sem_ext <- file.path(DATA_DIR, "voos", sprintf("voos_vra_periodo_%s_a_%s", ini, fim))
  baixar_e_tabular(url, base_sem_ext)
}

consultar_vra_voo <- function(data_str, empresa = NULL, origem = NULL, destino = NULL, numero = NULL) {
  params <- c(dt_voo = fmt_data(data_str))
  if (!is.null(empresa)) params["sg_empresa_icao"] <- empresa
  if (!is.null(origem)) params["sg_icao_origem"] <- origem
  if (!is.null(destino)) params["sg_icao_destino"] <- destino
  if (!is.null(numero)) params["nr_voo"] <- numero

  query <- paste(names(params), params, sep = "=", collapse = "&")
  url <- sprintf("%s/vra/voo?%s", BASE, query)

  nome_partes <- Filter(Negate(is.null), list(fmt_data(data_str), empresa, numero))
  base_sem_ext <- file.path(DATA_DIR, "voos", paste0("voos_vra_voo_", paste(nome_partes, collapse = "_")))
  baixar_e_tabular(url, base_sem_ext)
}

consultar_aerodromo <- function(codigo) {
  url <- sprintf("%s/aerodromo?sg_aerodromo_icao_ou_iata=%s", BASE, codigo)
  base_sem_ext <- file.path(DATA_DIR, "aerodromos", sprintf("aerodromo_%s", toupper(codigo)))
  baixar_e_tabular(url, base_sem_ext)
}

.main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    cat("Uso:\n")
    cat("  Rscript scripts/ANAC_VRA_voo.R --data dd-MM-aaaa\n")
    cat("  Rscript scripts/ANAC_VRA_voo.R --periodo dd-MM-aaaa dd-MM-aaaa\n")
    cat("  Rscript scripts/ANAC_VRA_voo.R --voo --dia dd-MM-aaaa [--empresa ICAO] [--origem ICAO] [--destino ICAO] [--numero NR]\n")
    cat("  Rscript scripts/ANAC_VRA_voo.R --aerodromo CODIGO\n")
    return(invisible(NULL))
  }

  get_arg <- function(flag) {
    idx <- which(args == flag)
    if (length(idx) == 0) return(NULL)
    args[idx + 1]
  }

  data_arg <- get_arg("--data")
  aerodromo_arg <- get_arg("--aerodromo")

  if ("--periodo" %in% args) {
    idx <- which(args == "--periodo")
    baixar_vra_periodo(args[idx + 1], args[idx + 2])
  }
  if (!is.null(data_arg)) baixar_vra_dia(data_arg)
  if ("--voo" %in% args) {
    consultar_vra_voo(
      data_str = get_arg("--dia"),
      empresa = get_arg("--empresa"),
      origem = get_arg("--origem"),
      destino = get_arg("--destino"),
      numero = get_arg("--numero")
    )
  }
  if (!is.null(aerodromo_arg)) consultar_aerodromo(aerodromo_arg)
}

if (identical(environment(), globalenv()) && !interactive()) {
  .main()
}
