retrieve_from_Jexis <- function(id) { 
  require(tidyverse)
  require(rvest)
  require(rJava)
  require(RSelenium)
  
  temp = tempdir()
  # downloading in folder temp
  downloadPath <- file.path(temp) %>% stringr::str_replace_all("\\\\", "\\\\\\\\") # dont question it
  # to save the file in a temp directory
  fprof <- makeFirefoxProfile(list(browser.download.dir = downloadPath,
                                   browser.download.folderList = 2L,
                                   browser.download.manager.showWhenStarting = FALSE,
                                   browser.helperApps.neverAsk.openFile = "text/csv",
                                   browser.helperApps.neverAsk.saveToDisk = "text/csv"))
  
  # to make firefox headless
  exCap <- list(firefox_profile = fprof$firefox_profile, 
                "moz:firefoxOptions" = list(args = list('--headless')))
  
  # start the thingy
  driver <- rsDriver(browser = "firefox", verbose = FALSE
                     ,extraCapabilities = exCap
  )
  remDr<-driver[["client"]]
  
  # go to the page of the dataset
  remDr$navigate(paste0("https://jexis.idiv.de/ddm/data/Showdata/", id))
  
  # find and click the dropdown menu
  webElem1 <- remDr$findElements(using='xpath',
                                 value= '//*[@id="showData"]')
  name <- webElem1[[2]]$getElementText()
  name <- strsplit(name[[1]], 
                   "\\\\|[^[:print:]]", 
                   fixed=FALSE)[[1]][1]
  
  Sys.sleep(1)
  # go to the primary data tab
  webElem1 <- remDr$findElement(using='id', 
                                value= "primarydata")
  webElem1$clickElement()
  
  Sys.sleep(1)
  # find and click the dropdown menu
  webElem1 <- remDr$findElements(using='xpath',
                                 value= '//*[@id="dropdownMenu1"]')
  webElem1[[2]]$clickElement()
  
  webElem1 <- remDr$findElement(using='xpath',
                                value= '//*[@ext=".csv"]')
  webElem1$clickElement()
  
  data = read.csv(Sys.glob(paste0(temp, "\\", name, "*.csv")), sep = ";")
  
  # closes firefox remote browser (which you don't see if headless)
  remDr$closeWindow()
  # kills java
  system("taskkill /im java.exe /f", intern=FALSE, ignore.stdout=FALSE,
         show.output.on.console = FALSE)
  
  return(data)
}


# this was my first attempt, now obsolete
retrieve_from_Jexis_crawler <- function(id) { 
require(tidyverse)
require(rvest)
require(rJava)
require(RSelenium)

# start the thingy
driver <- rsDriver(browser = "firefox", verbose = FALSE
                   #this line makes a headless firefox :) 
                   #i.e. running in background; comment it out for debugging
                   ,extraCapabilities = list("moz:firefoxOptions" = list(args = list('--headless')))
)
remDr<-driver[["client"]]

# go to the page of the dataset
remDr$navigate(paste0("https://jexis.idiv.de/ddm/data/Showdata/", id))

Sys.sleep(1)
# go to the primary data tab
webElem1 <- remDr$findElement(using='id', 
                              value= "primarydata")
webElem1$clickElement()

Sys.sleep(1)

# choose to display 500 observations
# webElem1 <- remDr$findElement(using='xpath',
#                               value= '//*[@class="t-dropdown-wrap t-state-default"]')
# if the data are not public, this is where the process will break
webElem1 <- tryCatch(remDr$findElement(using='xpath',
                                       value= '//*[@class="t-dropdown-wrap t-state-default"]'), 
                     error = function(e){ 
                                         message('Data are not public!')
                                         remDr$closeWindow()
                                         system("taskkill /im java.exe /f", 
                                                intern=FALSE, 
                                                ignore.stdout=FALSE,
                                                show.output.on.console = FALSE)
                                         }
                     )

webElem1$clickElement()

webElem1 <- remDr$findElement(using='xpath',
                              value= '//*[@class="t-popup t-group"]/ul/li[5]')
webElem1$clickElement()

# find how many 500s
webElem1 <- remDr$findElement(using='xpath', 
                              value= '//*[@class="t-icon t-arrow-last"]')
webElem1$clickElement()

n <- remDr$findElement(using='xpath',
                       value= '//*[@class="t-state-active"]')$getElementText()
n = as.integer(n[[1]])

# go back to the first 500
webElem1 <- remDr$findElement(using='xpath', 
                              value= '//*[@class="t-icon t-arrow-first"]')
webElem1$clickElement()

# initiate an empty list
data = vector(mode = "list", n)

i=1

while(i<n+1) { # we will do this n times where n=number of 500s
  # grab the data
  find.table <- remDr$findElement(using = 'xpath',
                                  value= '//*[@id="PrimaryDataResultGrid"]')
  tables <- find.table$getPageSource()[[1]] %>%
            read_html() %>%
            html_table(fill = TRUE)
  data[[i]] = tables[[length(tables)]]

  # move to the next 500
  webElem <- remDr$findElement(using = 'xpath', 
                               value= '//*[@class="t-icon t-arrow-next"]')
  webElem$clickElement()

  i = i+1
}
# list to dataframe
data = do.call("rbind", data)

# closes firefox remote browser (which you don't see if headless)
remDr$closeWindow()
# kills java
system("taskkill /im java.exe /f", intern=FALSE, ignore.stdout=FALSE,
       show.output.on.console = FALSE)

return(data)
}

