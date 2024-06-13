library(pdftools)
library(stringr)
fls <- list.files("data/raw/_firstpage",full.names = T)
stor <- "data/raw/_firstjpeg/"
jpgs <- list.files(stor,full.names = T)

basefls <- str_replace(basename(fls),'pdf$','jpeg')
still_need <- !basefls %in% basename(jpgs)

for(f in fls[still_need]){
  fb = basename(f)
  j = str_replace(fb,'pdf$','jpeg')
  pdftools::pdf_convert(f,format = 'jpeg',dpi = 150,filenames = paste0(stor,j))
}
