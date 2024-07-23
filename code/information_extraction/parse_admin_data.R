library(data.table)
library(jsonlite)
js = jsonlite::read_json('data/raw/indiana_contracts.json')
jdf = fromJSON('data/raw/indiana_contracts.json')
psf = fromJSON('data/raw/indiana_prof_services_contracts.json')
jdf <- data.table(jdf)
psf <- data.table(psf)
#Aggregate contracts by EDS number: Field 1 on the first page of the agreements.
jdf$EDS <- toupper(jdf$id)
psf$EDS <- toupper(psf$id)

jdf <- jdf[EDS %in% psf$EDS,]

### a lot of unknown tags are actually new contracts
### we assume that any case ID where we see 0 new contracts and 1 unknown, the 1 unknown is actually a new contract
type_count = dcast(jdf[,.N,by=.(EDS,actionType)],EDS ~ actionType,fill = 0)
new_candidates <- type_count[New==0&Unknown==1,]$EDS
jdf$actionType[jdf$actionType=='Unknown'&jdf$EDS %in% new_candidates] <- 'New'

jdf <- jdf[!jdf$EDS %in% jdf$EDS[jdf$actionType=='Unknown'],]

# This will give us an idea of how many times contracts get renewed.
# the average number of amendments is #
eds <- dcast(jdf[,.N,by=.(EDS,actionType)],EDS ~ actionType,fill = 0)
eds <- eds[New>0,]

jdf <- jdf[jdf$EDS %in% eds$EDS,]


nrow(jdf)
length(unique(jdf$id))
length(unique(jdf$vendorName))

# the proportion w/ at least one amendment is #
table(eds$Amendment>0)/nrow(eds)
# the proportion w/ at least one renewal is #
table(eds$Renewal>0)/nrow(eds)
# the average number of amendments is #
# the average number of renewals is #
eds[,list(mean(Amendment),mean(Renewal))]
jdf[,median(amount),by=.(actionType)]
library(lubridate)
jdf$years_length = decimal_date(ymd_hms(jdf$endDate)) - decimal_date(ymd_hms(jdf$startDate))

outcomes = dcast(jdf[,.N,by=.(EDS,actionType)],EDS ~ actionType,fill = 0)

new = jdf[actionType=='New',]
new$Amendment = outcomes$Amendment[match(new$EDS,outcomes$EDS)]
new$Renewal = outcomes$Renewal[match(new$EDS,outcomes$EDS)]
new[,Vendor_Contracts:=.N,by=.(vendorName)] 

library(rpart)
library(tidyverse)
# amendment categories: reduced, same, minor increase, major increase

jdf[,sum(amount),by=.(actionType,EDS)][order(-V1),][actionType=='New',][V1<10,]


jdf[grepl("6629-003",jdf$EDS),]
amendment %>% mutate(amend_outcomes = )
new$amendment


#Summary of Field 37 on first page: this explains what the contract is for, 
#based on everything I have seen these are very brief – a couple of sentences.

#Potentially check how the language of the original document (EDS number), changes with amendments for the same EDS number?

#Aggregate by agency Field 14  and Field 16 on first page.

#Aggregate by vendor ID (Field 23) and vendor name (Field 24) on first page.
# We can then see if certain vendors are contracting with multiple agencies.

#Summarize Field 29, Field 30, Field 31, Field 32.
These are all vendor characteristics, minority owned, vendor status etc. 
#Potentially explore which vendors get renewed, etc. 
#One of the fields is specific to subcontractors so potentially see which services/contracts require more complex arrangements.
#Summarize Field 33.
#This is the presence/absence of renewal language.



table(jdf$actionType)
summary(jdf$amount)

length(js)
