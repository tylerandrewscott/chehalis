library(RSelenium)
library(rvest)
library(httr)

library(rvest)
base_url <- "https://secure.in.gov/apps/idoa/contractsearch/"
require(RSelenium)
rD <- rsDriver(browser = "firefox")

selenium <- wdman::selenium(port = 4932L)
remDr <- remoteDriver(port = 4932L)
remDr$open(silent = TRUE)

head(remDr$sessionInfo)

.base-date-picker__container input

rseleniumClientObj$navigate(url = httr::parse_url("https://www.geeksforgeeks.org/"))


remDr <- rdriver[["client"]]
remDr$navigate("http://www.google.com/ncr")


remDr$navigate("http://www.bbc.com")
remDr$close()



?rsDriver
rD <- rsDriver()
remDr <- rD[["client"]]
remDr$navigate("http://www.google.com/ncr")

remDr$navigate(base_url)

remDr <- remoteDriver(browserName = "phantomjs", port = 4932L)
remDr$open(silent = TRUE)
remDr$navigate(url = "https://secure.in.gov/apps/idoa/contractsearch/")



remDr$screenshot(TRUE)
el <- remDr$findElement(value = ".input--untouched")
zip <- "30308"
remDr$findElement(using = "css", value = ".input--untouched")#$sendKeysToElement(list(zip))
?findElement
#  # now try injecting a new Math,random function
result <- remDr$phantomExecute("var page = this;
                               page.onInitialized = function () {
                               page.evaluate(function () {
                               Math.random = function() {return 42/100}
                               })
                               }", list())
remDr$navigate("http://ariya.github.com/js/random/")
# Math.random returns our custom function
remDr$findElement("id", "numbers")$getElementText()[[1]]
remDr$close()
pJS$stop()

## End(Not run)

[Package RSelenium version 1.7.9 Index]