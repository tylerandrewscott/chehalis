
library(qpdf)

fls <- list.files("data/raw/_contracts/",full.names = T)
newloc <- 'data/raw/_firstpage/'
library(pdftools)
basefls <- basename(fls)
still_need <- !basefls %in% list.files(newloc)

for(f in rev(fls[still_need])){
    print(f)
    err = F
  while(!file.exists(paste0(newloc,basename(f))) | err == F){
    err = tryCatch(pdf_subset(input = f, pages = 1, output = paste0(newloc,basename(f))),error = function(e) TRUE)
    }
  }

