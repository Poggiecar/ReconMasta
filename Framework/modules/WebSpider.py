from random import randint
import argparse
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import time
import signal
import sys
from tqdm import tqdm



class WebsiteScraper:
    def __init__(self, base_url):
        self.base_url = base_url
        self.visited_urls = set()
        self.new_urls = set([self.base_url])

    def crawl(self, request_delay=0.33, wordlist=None):
        print("\nComienza el crawling\n")
        write_count = 0
        write_flag = 1

        # Manejar la señal de interrupción (Ctrl + C)
        signal.signal(signal.SIGINT, self.handle_interrupt)

        try:
            if wordlist:
                with open(wordlist, 'r', encoding='utf-8') as f:
                    words = [line.strip() for line in f]

                for word in tqdm(words, desc="Porcentaje de completado", unit="palabras"):
                    url = urljoin(self.base_url, word)
                    if self.is_same_domain(url) and url not in self.visited_urls and self.is_valid_url(url):
                        self.process_url(url, write_count, write_flag)
                        write_count += 1

            else:
                while self.new_urls:
                    url = self.new_urls.pop()

                    if url in self.visited_urls or not self.is_same_domain(url)or not self.is_valid_url(url):
                        continue

                    self.process_url(url, write_count, write_flag)
                    write_count += 1

                    time.sleep(request_delay)

                    try:
                        response = requests.get(url)
                        response.raise_for_status()
                    except requests.exceptions.RequestException as e:
                        print(f"Error al procesar la URL {url}: {e}")
                        continue

                    self.write_url_data(url)

                    soup = BeautifulSoup(response.text, 'html.parser')
                    links = {urljoin(url, link.get('href')) for link in soup.find_all('a') if self.is_same_domain(urljoin(url, link.get('href')))}
                    self.new_urls.update(links)
        except KeyboardInterrupt:
            print("\n¡Crawling interrumpido por el usuario!")
            sys.exit(0)

    def process_url(self, url, write_count, write_flag):
        
        print(url)
        self.visited_urls.add(url)
        self.write_url_data(url)
    
    def is_valid_url(self, url):
        try:
            response = requests.get(url)
            response.raise_for_status()
            return response.status_code == 200
        except requests.exceptions.RequestException as e:
            
            return False
    def process_url_wordlist(self, url):
        full_url = urljoin(self.base_url, url)
        if full_url not in self.visited_urls:
            self.process_url(full_url, 0, 1)

    def handle_interrupt(self, signum, frame):
        print("\n¡Crawling interrumpido por el usuario!")
        sys.exit(0)

    def is_same_domain(self, url):
        base_domain = urlparse(self.base_url).netloc
        current_domain = urlparse(url).netloc
        return base_domain == current_domain

    def write_url_data(self, url):
        file_path = 'data.txt'
        with open(file_path, 'a', encoding='utf-8') as fp:
            fp.write(url + '\n')

def parse_arguments():
    parser = argparse.ArgumentParser(description="Web Scraper")
    parser.add_argument('website_address', help="Dirección del sitio web")
    parser.add_argument('-w', '--wordlist', help="Archivo de lista de palabras")

    args = parser.parse_args()
    return args

def main():
    args = parse_arguments()
    website = args.website_address

    if not website.startswith("http"):
        print("\033[91m {}\033[00m".format("Por favor, incluye el esquema del sitio web (http/https) en la dirección proporcionada"))
        return

    scraper = WebsiteScraper(website)
    wordlist = args.wordlist
    scraper.crawl(wordlist=wordlist)

if __name__ == '__main__':
    main()
