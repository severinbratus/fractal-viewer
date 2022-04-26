#!/usr/bin/python

from selenium.webdriver import Firefox
from selenium.webdriver import FirefoxOptions
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys

from random import random
from time import sleep

import re

## idea of the script:
# input: a list of desired timeslots
#   (as a file with weekday and clock-time pairs)
# output: if any of the timeslots are available,
#   send a text for notification to stdout

DATE, HOUR = range(2)
date = list[str]

driver = None

def main() -> None:
    global driver

    times : list[date] # = [['Saturday','07:00']]
    with open('times.txt') as fin:
        times = [line.strip().split() for line in fin.readlines()]
   
    options = FirefoxOptions()
    options.headless = True
    driver = Firefox(options=options)

    # go to x.tudelft.nl
    driver.get("https://x.tudelft.nl/en/home")

    # authenticate w tud identity
    with open('creds.txt') as fin:
        uname, passwd = fin.readline().split()
    
    driver.find_element(By.LINK_TEXT, 'tudelft').click()

    driver.implicitly_wait(10)
    driver.find_element(By.ID, "username").send_keys(uname + Keys.TAB)
    driver.find_element(By.ID, "password").send_keys(passwd + Keys.RETURN)

    # wait for the page to load

    # navigate to bookings
    while not (elts := driver.find_elements(By.LINK_TEXT, 'Bookings')):
        driver.implicitly_wait(1)
    elts[0].click()

    cn = 'card__title--primary'
    pred = lambda elt: 'Fitness Time-Slots' in elt.text
    lf = lambda seq: list(filter(pred, seq))
    while not (elts := lf(driver.find_elements(By.CLASS_NAME, cn))):
        driver.implicitly_wait(10)
    elts[0].click()

    # scroll for seven rounds, checking if any of the given slots is free
    
   # free : list[date] = []

    driver.implicitly_wait(10)
    for i in range(6):
        cards = driver.find_elements(By.CLASS_NAME, 'card')
        for time in filter(lambda time: date_on(driver, time[DATE], times)):
            for card in cards:
                if 'ADD' in card.text and time[HOUR] in card.text:
                    print(time[DATE], re.search('[0-9]{2}:00', card.text).group(0))

        # go to the page on the right
        xp = '/html/body/div/div[1]/div[2]/main/div/div/div[1]/div[2]/div[3]/button'
        while not (elts := driver.find_elements(By.XPATH, xp)):
            driver.implicitly_wait(1)
        elts[0].click()
    
    driver.quit()

def date_on(driver, date : str) -> bool:
    '''Return true iff the date is on one of the .layout elements'''
    return any((date in elt.text) for elt in driver.find_elements(By.CLASS_NAME, 'layout'))

if __name__ == '__main__':
    main()

