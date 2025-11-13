library(data.table)
floc <- 'data/raw/All vendors all agencies all transactions/'
flist <- list.files(floc)
frist <- lapply(flist,function(x) fread(paste0(floc,x)))

dt <- rbindlist(frist,use.names = T,fill = T)

fwrite(dt,'data/raw/aggregate_transactions_Q1_2015_Q4_2025.csv')
saveRDS(dt,'data/raw/aggregate_transactions_Q1_2015_Q4_2025.rds')

