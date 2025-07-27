import sqlite3
import time
import webbrowser
from datetime import date

import pandas as pd
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from webdriver_manager.chrome import ChromeDriverManager

DB_FILE = "cdjapan.db"
SEARCH_TERMS = [
    "%E4%B8%89%E6%A3%AE%E3%81%99%E3%81%9A%E3%81%93",
    "%E5%8D%97%E6%A2%9D%E6%84%9B%E4%B9%83",
    "%E5%9C%92%E7%94%B0%E6%B5%B7%E6%9C%AA",
    "%E7%B5%A2%E7%80%AC%E7%B5%B5%E9%87%8C",
    "%E3%83%A9%E3%83%96%E3%83%A9%E3%82%A4%E3%83%96+%E3%81%AC%E3%81%84%E3%81%90%E3%82%8B%E3%81%BF",
    "%E9%9F%B3%E3%81%AE%E3%83%AC%E3%82%AC%E3%83%BC%E3%83%88",
    "SEIKO+%E6%99%82%E8%A8%88",
]
BASE_URL = "https://www.cdjapan.co.jp/searchuni?q={term}&order=newdesc"

def setup_driver():
    """Initializes and returns a Selenium WebDriver."""
    print("Setting up Chrome WebDriver...")
    options = webdriver.ChromeOptions()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
    
    try:
        service = ChromeService(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=options)
        print("WebDriver setup complete.")
        return driver
    except Exception as e:
        print(f"Error setting up WebDriver: {e}")
        return None

def get_newest_item_url(driver, term):
    """
    Navigates to the search results page for a given term and scrapes the URL
    of the newest item.
    
    Args:
        driver: The Selenium WebDriver instance.
        term (str): The URL-encoded search term.
        
    Returns:
        str: The URL of the newest item, or None if not found.
    """
    search_url = BASE_URL.format(term=term)
    print(f"Searching for '{term}'...")
    
    try:
        driver.get(search_url)

        search_button = WebDriverWait(driver, 5).until(EC.element_to_be_clickable((By.CSS_SELECTOR, ".search-button")))

        search_button.click()
        
        WebDriverWait(driver, 15).until(
            EC.presence_of_element_located((By.ID, "js-search-result"))
        )
        
        time.sleep(2)

        soup = BeautifulSoup(driver.page_source, 'html.parser')
        
        first_item_link = soup.select_one("#js-search-result .item a")
        
        if first_item_link and first_item_link.get('href'):
            item_url = first_item_link['href']
            print(f"  Found newest item: {item_url}")
            return item_url
        else:
            print(f"  No item found for '{term}'.")
            return None
            
    except TimeoutException:
        print(f"  Timeout while waiting for search results for '{term}'.")
        return None
    except Exception as e:
        print(f"  An error occurred while scraping for '{term}': {e}")
        return None

def main():
    """
    Main script execution flow:
    1. Connect to the database and read existing items.
    2. Set up the web driver.
    3. Scrape the latest item URLs for each search term.
    4. Compare new URLs with old ones and identify updates.
    5. Update the database with the new data.
    6. Open new items in the browser.
    7. Clean up resources.
    """
    try:
        with sqlite3.connect(DB_FILE) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS newest_items (
                    search_term TEXT PRIMARY KEY,
                    newest_item TEXT,
                    last_update TEXT
                )
            """)
            
            db_terms_df = pd.read_sql_query("SELECT search_term FROM newest_items", conn)
            db_terms = set(db_terms_df['search_term'].tolist())
            
            for term in SEARCH_TERMS:
                if term not in db_terms:
                    print(f"Adding new search term '{term}' to database.")
                    conn.execute(
                        "INSERT INTO newest_items (search_term, newest_item, last_update) VALUES (?, ?, ?)",
                        (term, '', str(date.today()))
                    )
            
            items_df = pd.read_sql_query("SELECT * FROM newest_items", conn, index_col='search_term')
    except sqlite3.Error as e:
        print(f"Database error: {e}")
        return

    items_df = items_df.reindex(SEARCH_TERMS)
    old_urls = items_df['newest_item'].tolist()

    driver = setup_driver()
    if not driver:
        return
        
    newest_urls = []
    try:
        for term in SEARCH_TERMS:
            url = get_newest_item_url(driver, term)
            newest_urls.append(url)
            time.sleep(2)
    finally:
        print("Closing WebDriver.")
        driver.quit()

    print("\n--- Scraping Complete ---")
    print("Newest URLs found:")
    print(newest_urls)

    if not newest_urls:
        print("No URLs were scraped. Exiting.")
        return

    updates_df = pd.DataFrame({
        'search_term': SEARCH_TERMS,
        'old_url': old_urls,
        'newest_url': newest_urls
    }).set_index('search_term')

    updates_df['is_new'] = (updates_df['old_url'] != updates_df['newest_url']) & updates_df['newest_url'].notna()
    
    today_str = str(date.today())
    
    items_df['last_update'] = items_df['last_update'].where(~updates_df['is_new'], today_str)
    items_df['newest_item'] = items_df['newest_item'].where(~updates_df['is_new'], updates_df['newest_url'])
    
    try:
        print("\nUpdating database...")
        with sqlite3.connect(DB_FILE) as conn:
            items_df.reset_index().to_sql('newest_items', conn, if_exists='replace', index=False)
        print("Database update complete.")
    except sqlite3.Error as e:
        print(f"Database write error: {e}")

    new_items_to_open = updates_df[updates_df['is_new']]
    if not new_items_to_open.empty:
        print(f"\nFound {len(new_items_to_open)} new/updated item(s). Opening in browser...")
        for index, row in new_items_to_open.iterrows():
            term = index
            print(f"  New item for '{term}': {row['newest_url']}")
            webbrowser.open(row['newest_url'])
    else:
        print("\nNo new items found.")

if __name__ == "__main__":
    main()
