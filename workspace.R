library(BiocManager)
library(tercen)
library(dplyr)
library(flowCore)

# http://127.0.0.1:5402/admin/w/4133245f38c1411c543ef25ea3020c41/ds/f3a1ea03-d4e3-4678-8a7b-f1fffc50cab8
# Set appropriate options
# options("tercen.serviceUri"="http://tercen:5400/api/v1/")
options("tercen.workflowId"= "4133245f38c1411c543ef25ea3020c41")
options("tercen.stepId"= "f3a1ea03-d4e3-4678-8a7b-f1fffc50cab8")
options("tercen.username"= "admin")
options("tercen.password"= "admin")

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

if (!any(ctx$cnames == "documentId")) stop("Column factor documentId is required") 

#1. extract files
df <- ctx$cselect()

docId = df$documentId[1]
doc = ctx$client$fileService$get(docId)
filename = tempfile()
writeBin(ctx$client$fileService$download(docId), filename)
on.exit(unlink(filename))

# unzip if archive
if(length(grep(".zip", doc$name)) > 0) {
  tmpdir <- tempfile()
  unzip(filename, exdir = tmpdir)
  f.names <- list.files(tmpdir, full.names = TRUE)
} else {
  f.names <- filename
}

# check FCS
if(any(!isFCSfile(f.names))) stop("Not all imported files are FCS files.")

assign("actual", 0, envir = .GlobalEnv)
task = ctx$task


#2. convert them to FCS files
f.names %>%
  lapply(function(filename){
    data = fcs_to_data(filename)
    if (!is.null(task)) {
      # task is null when run from RStudio
      actual = get("actual",  envir = .GlobalEnv) + 1
      assign("actual", actual, envir = .GlobalEnv)
      evt = TaskProgressEvent$new()
      evt$taskId = task$id
      evt$total = length(f.names)
      evt$actual = actual
      evt$message = paste0('processing FCS file ' , filename)
      ctx$client$eventService$sendChannel(task$channelId, evt)
    } else {
      cat('processing FCS file ' , filename)
    }
    data
  }) %>%
  bind_rows() %>%
  ctx$addNamespace() %>%
  ctx$save()