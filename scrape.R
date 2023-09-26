library(rvest)
library(stringr)
library(magrittr)
library(readr)
library(RSQLite)
library(lubridate)
library(stringi)
library(dplyr)

# Set encoding
stri_enc_set("Shift_JIS")

# Connect to database
result_db <- dbConnect(SQLite(), dbname = "cdjapan.db")

# Query database
items <- dbGetQuery(result_db, "SELECT * FROM newest_items;")

# Extract relevant columns
old_urls <- items$newest_item
search_term_raw <- items$search_term
dates <- items$last_update

# Define search terms
search_terms <- c(
    "%E4%B8%89%E6%A3%AE%E3%81%99%E3%81%9A%E3%81%93",
    "%E5%8D%97%E6%A2%9D%E6%84%9B%E4%B9%83",
    "%E5%9C%92%E7%94%B0%E6%B5%B7%E6%9C%AA",
    "%E7%B5%A2%E7%80%AC%E7%B5%B5%E9%87%8C",
    "%E3%83%A9%E3%83%96%E3%83%A9%E3%82%A4%E3%83%96+%E3%81%AC%E3%81%84%E3%81%90%E3%82%8B%E3%81%BF",
    "%E9%9F%B3%E3%81%AE%E3%83%AC%E3%82%AC%E3%83%BC%E3%83%88",
    "SEIKO+%E6%99%82%E8%A8%88"
)

Sys.sleep(15L)

# Scrape URLs
get_newest_urls <- function(term) {
    base_url <- str_c("https://www.cdjapan.co.jp/searchuni?q=", term, "&order=newdesc")

    Sys.sleep(4L)

    url <- read_html(base_url) %>%
        html_elements(xpath = "//*[@id=\"js-search-result\"]") %>%
        html_element(xpath = "//*[@class=\"item\"]") %>%
        html_element("a") %>%
        html_attr("href")

    return(url)
}

newest_urls <- lapply(search_terms, get_newest_urls) %>%
    unlist()

tibble(search_term_raw, old_urls, newest_urls, dates) %>%
    mutate(dates = case_when(
        old_urls != newest_urls ~ as.character(today()),
        TRUE ~ dates
    )) %>%
    dplyr::select(-old_urls) %>%
    set_names(c("search_term", "newest_item", "last_update")) %>%
    dbWriteTable(result_db, "newest_items", ., overwrite = TRUE)
dbDisconnect(result_db)

# Open web page for any new items
open_new_items <- function(new_url, old_url) {
    if (new_url != old_url) {
        browseURL(new_url)
    }
}

mapply(open_new_items, newest_urls, old_urls) %>%
    invisible()
