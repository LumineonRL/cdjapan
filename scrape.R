library(rvest)
library(stringr)
library(magrittr)
library(readr)
library(RSQLite)
library(lubridate)
library(stringi)
library(dplyr)

stri_enc_set("Shift_JIS")
db1 <- dbConnect(SQLite(), dbname = "cdjapan.db")

items <- dbGetQuery(db1, "SELECT * FROM newest_items;")
items
old_urls <- items$newest_item
search_term_raw <- items$search_term
dates <- items$last_update


# 三森すずこ、南條愛乃、園田海未、絢瀬絵里、ラブライブ ぬいぐるみ,
# 音のレガート, SEIKO 時計 R doesn't like it when you give it the UTF-8 encoded
# versions of the name even though it works fine in the URL.  Update 3/16/23.
# importing stringi and setting `stri_enc_set('Shift_JIS')` will probably allow
# it to work with proper encoding.  Update 5/3/23. Above solution did not work,
# but I'm convinced it's possible.
search_term <- c("%E4%B8%89%E6%A3%AE%E3%81%99%E3%81%9A%E3%81%93",
    "%E5%8D%97%E6%A2%9D%E6%84%9B%E4%B9%83",
    "%E5%9C%92%E7%94%B0%E6%B5%B7%E6%9C%AA",
    "%E7%B5%A2%E7%80%AC%E7%B5%B5%E9%87%8C",
    "%E3%83%A9%E3%83%96%E3%83%A9%E3%82%A4%E3%83%96+%E3%81%AC%E3%81%84%E3%81%90%E3%82%8B%E3%81%BF",
    "%E9%9F%B3%E3%81%AE%E3%83%AC%E3%82%AC%E3%83%BC%E3%83%88",
    "SEIKO+%E6%99%82%E8%A8%88")

newest_urls <- rep(NA, length(search_term))

# Give computer a little more time to establish internet connection.
Sys.sleep(15)

for (i in seq_along(1L:length(search_term))) {
    if (i > 1L) {
        Sys.sleep(4L)
    }
    base_url <- str_c("https://www.cdjapan.co.jp/searchuni?q=", search_term[i],
        "&order=newdesc")

    # Grabs the link to top search result.
    newest_urls[i] <- read_html(base_url) |>
        html_elements(xpath = "//*[@id=\"js-search-result\"]") |>
        html_element(xpath = "//*[@class=\"item\"]") |>
        html_element("a") |>
        html_attr("href")
}

tibble(search_term_raw, old_urls, newest_urls, dates) |>
    mutate(dates = case_when(old_urls != newest_urls ~ as.character(today()),
        TRUE ~ dates)) |>
    dplyr::select(-old_urls) |>
    set_names(c("search_term", "newest_item", "last_update")) |>
    dbWriteTable(db1, "newest_items", ., overwrite = TRUE)
dbDisconnect(db1)

# Open web page for any new new items.  Can probably rewrite this with an
# apply.
for (j in seq_along(1L:length(newest_urls))) {
    if (newest_urls[j] != old_urls[j]) {
        browseURL(newest_urls[j])
    }
}
