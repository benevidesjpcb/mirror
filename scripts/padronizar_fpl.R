#!/usr/bin/env Rscript
# Padroniza os dados de plano de voo (FPL) do sistema SIGMA/DECEA, que vem
# em data/fpl/*.csv: um arquivo separado por ";" com UMA LINHA POR MENSAGEM
# (nao por voo). Cada voo (agrupado pelo campo "id") pode ter varias
# mensagens ao longo da vida do plano: FPL (plano original), CHG
# (alteracao), DLA (atraso), CNL (cancelado), DEP (decolagem), ARR (pouso).
# Essas alteracoes (CHG/DLA/CNL) so acontecem ANTES da decolagem.
#
# Descobertas sobre o formato (confirmadas inspecionando o arquivo real):
#   - eobd/atod trazem a DATA certa; eobt/atot trazem a HORA certa "colada"
#     numa data fixa fictacia (1980-02-01). O valor real e' data(eobd/atod)
#     + hora(eobt/atot).
#   - eobd/eobt nao mudam entre as mensagens de um mesmo id (mesmo com
#     DLA no meio) — e' so um valor por voo.
#   - Nao existe campo de horario real de POUSO. O melhor proxy e' o
#     receipt_application da mensagem ARR (horario que o sistema recebeu o
#     aviso de pouso) — bate quase exatamente com atot (horario real de
#     decolagem) quando comparado ao receipt_application da mensagem DEP,
#     confirmando que esses horarios estao em UTC (padrao ICAO).
#   - "indicative" e' ou um indicativo de companhia (ex: GLO1130 = Gol voo
#     1130) ou uma matricula de aeronave (ex: PTSGM = PT-SGM, aviacao
#     geral/privada).
#   - Para voos de companhia, a matricula da aeronave fica dentro do campo
#     other_info como "REG/XXXXX" (nem todo voo declara isso).
#
# Uso interativo:
#   source("scripts/padronizar_fpl.R")
#   fpl <- padronizar_fpl("data/fpl/sigma_flight_plan_2025_12_10.csv")

library(dplyr)

#' Combina a data (primeiros 10 caracteres de `campo_data`) com a hora
#' (caracteres 12-19 de `campo_hora`, que vem "colada" na data fixa
#' 1980-02-01) num unico POSIXct em UTC. Retorna NA quando um dos dois
#' campos esta vazio.
combinar_data_hora <- function(campo_data, campo_hora) {
  valido <- nzchar(trimws(campo_data)) & nzchar(trimws(campo_hora))
  data <- ifelse(valido, substr(campo_data, 1, 10), NA)
  hora <- ifelse(valido, substr(campo_hora, 12, 19), NA)
  as.POSIXct(paste(data, hora), format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
}

#' Extrai o valor de "REG/XXXXX" de dentro do texto livre de other_info.
#' Retorna NA quando nao encontra.
extrair_registro <- function(other_info) {
  tem_reg <- grepl("REG/", other_info)
  registro <- rep(NA_character_, length(other_info))
  registro[tem_reg] <- sub(".*REG/([A-Za-z0-9]+).*", "\\1", other_info[tem_reg])
  registro
}

#' Primeiro valor nao-NA de um vetor, ou NA se todos forem NA (sem warning).
primeiro_nao_na <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) NA else x[1]
}

#' Le o CSV bruto do FPL (uma linha por mensagem) e devolve uma linha por
#' voo (agrupado por id), com a "historia" do voo e os horarios em UTC.
padronizar_fpl <- function(caminho_csv) {
  bruto <- read.csv(caminho_csv, sep = ";", quote = "\"", fileEncoding = "UTF-8", stringsAsFactors = FALSE)

  padrao_indicativo_empresa <- "^[A-Z]{2,3}[0-9]{1,4}[A-Z]?$"

  mensagens <- bruto %>%
    mutate(
      eh_empresa = grepl(padrao_indicativo_empresa, indicative),
      tipo_voo = ifelse(eh_empresa, "empresa", "geral"),
      empresa_icao = ifelse(eh_empresa, sub("[0-9].*$", "", indicative), NA_character_),
      numero_voo = ifelse(eh_empresa, sub("^[A-Za-z]+", "", indicative), NA_character_),
      aircraft_registration = ifelse(eh_empresa, extrair_registro(other_info), indicative),
      partida_prevista_utc = combinar_data_hora(eobd, eobt),
      partida_real_utc = combinar_data_hora(atod, atot),
      receipt_application_utc = as.POSIXct(receipt_application, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")
    )

  mensagens %>%
    group_by(id) %>%
    summarise(
      gufi = first(gufi),
      indicative = first(indicative),
      tipo_voo = first(tipo_voo),
      empresa_icao = first(empresa_icao),
      numero_voo = first(numero_voo),
      aircraft_registration = primeiro_nao_na(aircraft_registration),
      adep = first(adep),
      ades = first(ades),
      aircraft_model = first(aircraft_model),
      flight_rule = first(flight_rule),
      airline = first(airline),
      estado_final = first(state),
      tem_fpl = any(msg_type == "FPL"),
      tem_chg = any(msg_type == "CHG"),
      tem_dla = any(msg_type == "DLA"),
      tem_cnl = any(msg_type == "CNL"),
      decolou = any(msg_type == "DEP"),
      pousou = any(msg_type == "ARR"),
      partida_prevista_utc = primeiro_nao_na(partida_prevista_utc),
      partida_real_utc = primeiro_nao_na(partida_real_utc),
      chegada_real_utc = primeiro_nao_na(receipt_application_utc[msg_type == "ARR"]),
      .groups = "drop"
    )
}
