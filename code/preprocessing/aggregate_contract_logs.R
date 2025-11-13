library(data.table)
library(tidyverse)
library(lubridate)


fls_csv <- list.files('data/raw/indiana_records/',recursive = T,full.names = T,pattern = 'csv')
fls_xlsx <- list.files('data/raw/indiana_records/',recursive = T,full.names = T,pattern = 'xls')

xl_file <- readxl::read_excel(fls_xlsx)

xl_file <- xl_file |> select(-Source.Name) |> mutate(`Journal Date` = ymd(`Journal Date`))
csv_list <- lapply(fls_csv,function(x) {temp = fread(x);temp$`Journal Date` <- mdy(temp$`Journal Date`); return(temp)})
csv_dt <- rbindlist(csv_list,use.names = T,fill = T)
csv_dt <- rbind(csv_dt,xl_file,use.names = T,fill = T)


saveRDS(object = csv_dt,file = 'data/raw/indiana_quarterly_log.rds')

corrections_contracts <- csv_dt[`Expenditure Category`=="Contractual Services" & `Agency Name`=='Correction',]
fwrite(x = corrections_contracts,file = 'data/raw/indiana_quarterly_log_corrections_contractservices.csv')
