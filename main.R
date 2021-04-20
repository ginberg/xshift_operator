library(BiocManager)
library(tercen)
library(dplyr)
library(flowCore)
library(properties)

# force disabling scientific notation
options(scipen = 999)

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

# create fcs file
fcs_filename  <- "input.fcs"
clusters      <- ctx$rselect() %>% pull(gs0.variable)
res           <- t(ctx$as.matrix())
colnames(res) <- clusters
frame         <- flowCore::flowFrame(res)
write.FCS(frame, fcs_filename)

# create fcsFileList.txt
write.table(fcs_filename, file = "fcsFileList.txt", col.names = FALSE, row.names = FALSE, quote = FALSE)

limit_events_per_file = ifelse(is.null(ctx$op.value('limit_events_per_file')), 100, as.numeric(ctx$op.value('limit_events_per_file')))
num_nearest_neighbors = ctx$op.value('num_nearest_neighbors')
if (is.null(num_nearest_neighbors)) {
  num_nearest_neighbors <- ""
} else if (num_nearest_neighbors != "") {
    # if it's a string it should be auto
    if (is.na(suppressWarnings(as.numeric(num_nearest_neighbors)))) {
      if (num_nearest_neighbors != "auto") {
        stop("num_nearest_neighbors should be empty, a numeric value or equal to 'auto'.")
      }
    } else {
      num_nearest_neighbors <- as.numeric(num_nearest_neighbors)
    }
}

# create importConfig.txt
write.properties(file = file("importConfig.txt"),
                 properties = list(clustering_columns         = "4,5,6,7,8,9,10",
                                   limit_events_per_file      = as.character(limit_events_per_file),
                                   transformation             = "ASINH",
                                   scaling_factor             = "5",
                                   noise_threshold            = "1.0",
                                   euclidian_length_threshold = "0.0",
                                   rescale                    = "NONE",
                                   quantile                   = "0.95",
                                   rescale_separately         = "false"))

system(paste("java -Xmx32G -cp VorteX.jar -Djava.awt.headless=true standalone.Xshift", num_nearest_neighbors))

# read output and write to tercen
fcs_to_data(file.path("out", fcs_filename)) %>%
  bind_rows() %>%
  ctx$addNamespace() %>%
  ctx$save()