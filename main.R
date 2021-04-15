library(BiocManager)
library(tercen)
library(dplyr)
library(flowCore)
library(properties)

fcs_to_data = function(filename) {
  data_fcs = read.FCS(filename, transformation = FALSE)
  names_parameters = data_fcs@parameters@data$desc
  data = as.data.frame(exprs(data_fcs))
  col_names = colnames(data)
  names_parameters = ifelse(is.na(names_parameters),col_names,names_parameters)
  colnames(data) = names_parameters
  data %>%
    mutate_if(is.logical, as.character) %>%
    mutate_if(is.integer, as.double) %>%
    mutate(.ci = rep_len(0, nrow(.))) %>%
    mutate(filename = rep_len(basename(filename), nrow(.)))
}
 
ctx = tercenCtx()

# TODO create fcs file
fcs_filename <- "BM2_cct_normalized_01_non-Neutrophils.fcs"
# write.FCS()
# create fcsFileList.txt
write.table(fcs_filename, file = "fcsFileList.txt", col.names = FALSE, row.names = FALSE, quote = FALSE)
# create importConfig.txt
write.properties(file = file("importConfig.txt"),
                 properties = list(clustering_columns         = "4,5,6,7,8,9,10", 
                                   limit_events_per_file      = "100", 
                                   transformation             = "ASINH",
                                   scaling_factor             = "5",
                                   noise_threshold            = "1.0",
                                   euclidian_length_threshold = "0.0",
                                   rescale                    = "NONE",
                                   quantile                   = "0.95",
                                   rescale_separately         = "false"))

system("java -Xmx32G -cp VorteX.jar -Djava.awt.headless=true standalone.Xshift")

# read output and write to tercen
read.FCS(file.path("out", fcs_filename)) %>%
  bind_rows() %>%
  ctx$addNamespace() %>%
  ctx$save()