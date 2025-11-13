library(data.table)
raw <- readRDS('data/raw/indiana_quarterly_log.rds')
class(raw)
raw <- raw[`Expenditure Category` %in% c('Contractual Services') & grepl("Prof",`Account Name`),]
raw <- raw[`Agency Name` == 'Correction',]

library(htmlTable)


any(duplicated(raw$`Journal ID`))
duplicated(paste(raw$`Voucher ID`,raw$`Vendor ID`))

raw$`Fiscal Year`
summary(raw[,.N,by=.(`Vendor Name`)]$N)

dim(raw[Amount<0,])

dim(raw[`Vendor Name` =='GUIDESOFT INC' & Amount >= 0,])

ggplot(raw[`Vendor Name` =='OAKLAND CITY UNIV'& Amount > 0,]) + 
  geom_jitter(aes(y = Amount+1,x = `Fiscal Year`)) + 
  scale_y_log10(limits = c(1e3,NA)) + theme_bw() + 
  ggtitle('Oakland City Univ. mgmt consulting invoices')


ggplot(raw[`Vendor Name` =='GUIDESOFT INC' & Amount > 0,]) + 
  geom_jitter(aes(y = Amount+1,x = `Fiscal Year`)) + 
  scale_y_log10() + theme_bw() + 
  ggtitle('GUIDESOFT IN mgmt consulting + IT invoices')


vendor_year <- raw[,.N,by=.(`Vendor Name`,`Fiscal Year`)]

vendor_year[order(-N),]
library(tidyverse)
ggplot() + geom_path(data = vendor_year,aes(x = `Fiscal Year`,y = log(N),group = `Vendor Name`)) + 
  theme_bw() + ggtitle('# of invoices by vendor and FY')



vendor_year_amount <- raw[,sum(Amount),by=.(`Vendor Name`,`Fiscal Year`)]
raw$Amount
vendor_year[order(-N),]
library(tidyverse)
ggplot() + geom_path(data = vendor_year_amount,aes(x = `Fiscal Year`,y = log(V1),group = `Vendor Name`)) + 
  theme_bw() + ggtitle('total $ amount vendor and FY')

table(raw$Amount<0)


summary(raw$Amount)

raw$`Journal Date`



raw[,.N,by=.(`Vendor Name`)][order(-N),]


raw$`Vendor Name`
htmlTable(raw[,.N,by=.(`Account Name`)][order(-N),])



unique(raw$`Agency Name`)


unique(raw$`Account Name`[raw$`Expenditure Category`=='Contractual Services'])
unique(raw$`Account Name`[raw$`Expenditure Category`=='Personal Services and Fringe Benefits'])


table(grepl('Prof',raw$`Account Name`),raw$`Expenditure Category`)

head(raw)


dim(raw)
unique(raw$`Expenditure Category`)
