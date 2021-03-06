# -*- tab-width:2;indent-tabs-mode:t;show-trailing-whitespace:t;rm-trailing-spaces:t -*-
# vi: set ts=2 noet:

library(plyr)
library(dplyr)
library(stringr)
library(readr)
library(tidyr)
library(magrittr)
library(readxl)
library(googledrive)
googledrive::drive_auth(email='mattjomeara@gmail.com')


source("scripts/apms_prey_id_map.R")

load("intermediate_data/ca_sac_sge_ortholog_physical_ppi_summary.Rdata")
load("intermediate_data/chromosome_features.Rdata")
load("intermediate_data/genes_of_interest.Rdata")


gdrive_path <- "~/Collaborations/Candida Functional Genomics/HSP90 Physical Interactors/Datasets/AP-MS datasets"

# filtered TAP interators for cytoscape figure
googledrive::drive_download(
	file=paste0(gdrive_path, "/Analysis/OMeara_STable1_Hsp90APMSresults.xlsx"),
	path="intermediate_data/OMeara_STable1_Hsp90APMSresults.xlsx")

STable1_HSP90APMSresults <- readxl::read_xlsx(
	"intermediate_data/OMeara_STable1_Hsp90APMSresults.xlsx") %>%
	dplyr::mutate(
		bait_gene = dplyr::case_when(
			Bait == "E36A_HSP90" ~ "HSP90",
			Bait == "Sgt1" ~ "SGT1",
			TRUE ~ Bait),
		prey_gene = PreyGene) %>%
	dplyr::left_join(
		chromosome_features %>%
			dplyr::filter(feature_name %>% stringr::str_detect("A$")) %>%
			dplyr::select(
				bait_feature_name = feature_name,
				bait_gene = gene_name,
				bait_feature_status=feature_status,
				bait_feature_type=feature_type),
			by=c("bait_gene")) %>%
	dplyr::mutate(
		bait_feature_name = dplyr::case_when(
			Bait == "CPR7" ~ "C3_00950C_A",
			TRUE ~ bait_feature_name)) %>%
	prey_id_map()

sac_ppi <- sac_sge_interactions %>%
	dplyr::filter(interaction_type == "Physical") %>%
	dplyr::mutate(
		sac_gene_1 = gene_symbol_1,
		sac_gene_2 = gene_symbol_2,
		feature_name_1 = ca_feature_name_1,
		feature_name_2 = ca_feature_name_2) %>%
	dplyr::mutate(
		sac_phys_ppi = paste(
			experimental_system_abbreviation,
			annotation_abbreviation, sep="_")) %>%
	dplyr::filter(!is.na(feature_name_1), !is.na(feature_name_2)) %>%
	dplyr::group_by(sac_gene_1, sac_gene_2, feature_name_1, feature_name_2, sac_phys_ppi) %>%
	dplyr::summarize(
			n_ppis = paste0(ifelse(n() == 1, "", paste0(n(), "*")), sac_phys_ppi[1])) %>%
	dplyr::summarize(
			interactions = n_ppis %>% paste0(collapse="|")) %>%
	dplyr::ungroup() %>%
	dplyr::group_by(feature_name_1, feature_name_2) %>%
	dplyr::summarize(interactions = paste0(sac_gene_1, "/", sac_gene_2, ":", interactions, collapse=";"))


STable1_HSP90APMSresults <- STable1_HSP90APMSresults %>%
	dplyr::left_join(
		sac_ppi %>%
			dplyr::transmute(
				bait_feature_name = feature_name_1,
				prey_feature_name = feature_name_2,
				sac_interactions = interactions),
		by=c("bait_feature_name", "prey_feature_name"))

STable1_HSP90APMSresults %>%
	dplyr::select(
		-bait_gene,
		-prey_gene,
		-bait_feature_status,
		-bait_feature_type,
		-prey_feature_status,
		-prey_feature_type,
		-feature_name_1) %>%
	readr::write_tsv("product/STable1_HSP90APMSresults_with_sac_ppi_190417.tsv")
