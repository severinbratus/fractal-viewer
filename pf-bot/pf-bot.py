#!/usr/bin/env python
# coding: utf-8

from selenium.webdriver.common.by import By
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

from time import sleep

import subprocess as sp
import re

import discord
from discord.ext import commands, tasks


intents = discord.Intents.default()
with open('token.txt') as fin:
    token = fin.read().strip()
bot = commands.Bot(command_prefix='!', token=token, intents=intents)


def get_n_projects(headless=False):
    # create headless chrome options
    chrome_options = Options()
    if headless: chrome_options.add_argument('--headless')
    chrome_options.add_argument('--disable-gpu')

    # create chrome driver instance
    driver = webdriver.Chrome(options=chrome_options)

    # navigate to the website
    driver.get("https://projectforum.tudelft.nl/")

    # click the login button
    login_button = driver.find_element(By.LINK_TEXT, "Log In (TU Delft)")
    login_button.click()

    sleep(1)
    uname_input = driver.find_element(By.ID, "username")
    pwd_input = driver.find_element(By.ID, "password")
    uname_input.send_keys(uname)
    pwd_input.send_keys(pwd)

    sleep(1)
    driver.find_element(By.ID, "submit_button").click()
    sleep(1)
    driver.find_element(By.PARTIAL_LINK_TEXT, "Software Project").click()
    sleep(1)
    driver.find_element(By.PARTIAL_LINK_TEXT, "Projects").click()

    sleep(1)
    source = re.sub(r"\s+", " ", driver.page_source).strip()

    pattern = r"The list below shows the <b>(.*)</b> projects that are available for this course"
    match = re.search(pattern, source)
    n_projects = int(match.group(1))

    # close the driver
    driver.quit()
    
    return n_projects

@tasks.loop(minutes=5)
async def main_task():
    print('main_task')
    
    with open("nprojs.txt") as fin:
        n_pers = int(fin.read())

    n_read = get_n_projects(True)
    
    if n_read != n_pers:
        assert n_pers < n_read, f"{n_pers} > {n_read}"
        msg = f"{n_read - n_pers} project(s) added @everyone"
        sp.run(["notify-send", "--urgency=CRITICAL", msg])
        channel = bot.get_channel(channel_id) # Replace with your channel ID
        await channel.send(msg)
    # else:
    #     sp.run(["notify-send", f"No project(s) added"])

    with open("nprojs.txt", "w") as fout:
        print(n_read, file=fout)
        
    print("main_task*")
    
@bot.event
async def on_ready():
    # msg = "debug: on_ready"
    # print(msg)
    # channel = bot.get_channel(channel_id)
    # await channel.send(msg)
    main_task.start()  # Start the background task

channel_id = 1081567536698622093

with open('creds.txt') as fin:
    uname, pwd = fin.read().strip().split(',')

# bot.start(token)
import asyncio

async def main():
    await bot.start(token)

loop = asyncio.get_event_loop()
loop.run_until_complete(main())
