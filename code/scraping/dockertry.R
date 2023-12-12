#$ sudo docker run -d -p 4445:4444 docker run -d -p 4444:4444 -p 7900:7900 --shm-size="2g" selenium/standalone-firefox:4.16.1-20231212
#$ sudo docker ps

#$ sudo docker run -d -p 4445:4444 selenium/standalone-firefox:2.53.0
#$ sudo docker ps

library(RSelenium)
remDr <- remoteDriver(port = 4445L)
remDr$open()

library(RSelenium)
remDr <- remoteDriver(
  remoteServerAddr = 'http://localhost:4444',
  port = 4445L
)
remDr$open()


