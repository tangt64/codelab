
import os
import threading
import time
import requests

def cpu_stress():
    while True:
        _ = 1234 ** 1234

def mem_stress():
    a = []
    while True:
        a.append(' ' * 10**6)
        time.sleep(0.1)

def disk_stress():
    while True:
        with open("/tmp/testfile", "w") as f:
            f.write("0" * 1024 * 1024)
        os.remove("/tmp/testfile")

def net_stress():
    while True:
        try:
            requests.get("http://example.com", timeout=3)
        except:
            pass

for target in [cpu_stress, mem_stress, disk_stress, net_stress]:
    threading.Thread(target=target, daemon=True).start()

while True:
    time.sleep(1)
