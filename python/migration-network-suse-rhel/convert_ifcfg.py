#!/usr/bin/env python3
import sys
import os
import re

def parse_ifcfg(path):
    config = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                config[k.strip()] = v.strip().strip('"').strip("'")
    return config

def convert_to_rh(cfg):
    out = {}
    if "IPADDR" in cfg and "/" in cfg["IPADDR"]:
        ip, prefix = cfg["IPADDR"].split("/")
        out["IPADDR"] = ip
        if prefix == "24":
            out["NETMASK"] = "255.255.255.0"
        elif prefix == "16":
            out["NETMASK"] = "255.255.0.0"
        elif prefix == "8":
            out["NETMASK"] = "255.0.0.0"
        else:
            out["NETMASK"] = prefix
    elif "IPADDR" in cfg:
        out["IPADDR"] = cfg["IPADDR"]

    out["BOOTPROTO"] = cfg.get("BOOTPROTO", "static")
    out["ONBOOT"] = "yes" if cfg.get("STARTMODE", "off") in ["auto", "onboot"] else "no"
    if "MASTER" in cfg:
        out["SLAVE"] = "yes"
        out["MASTER"] = cfg["MASTER"]
    if "BONDING_MASTER" in cfg:
        out["DEVICE"] = cfg.get("INTERFACENAME", "bond0")
        out["BONDING_OPTS"] = f"mode={cfg.get('BONDING_MODE', '1')} miimon={cfg.get('MIIMON', '100')}"
    if "DEVICE" not in out:
        out["DEVICE"] = cfg.get("INTERFACENAME", "eth0")
    return out

def convert_to_suse(cfg):
    out = {}
    ip = cfg.get("IPADDR")
    mask = cfg.get("NETMASK")
    if ip and mask:
        cidr = "24" if mask == "255.255.255.0" else "16" if mask == "255.255.0.0" else "8" if mask == "255.0.0.0" else mask
        out["IPADDR"] = f"{ip}/{cidr}"
    elif ip:
        out["IPADDR"] = ip

    out["BOOTPROTO"] = cfg.get("BOOTPROTO", "static")
    out["STARTMODE"] = "onboot" if cfg.get("ONBOOT", "no") == "yes" else "off"
    if "SLAVE" in cfg and cfg["SLAVE"].lower() == "yes":
        out["MASTER"] = cfg.get("MASTER", "bond0")
    if "BONDING_OPTS" in cfg:
        out["BONDING_MASTER"] = "yes"
        mode_match = re.search(r"mode=(\w+)", cfg["BONDING_OPTS"])
        miimon_match = re.search(r"miimon=(\d+)", cfg["BONDING_OPTS"])
        if mode_match:
            out["BONDING_MODE"] = mode_match.group(1)
        if miimon_match:
            out["MIIMON"] = miimon_match.group(1)
    out["INTERFACENAME"] = cfg.get("DEVICE", "eth0")
    return out

def write_ifcfg(cfg, path):
    with open(path, 'w') as f:
        for k, v in cfg.items():
            f.write(f'{k}="{v}"\n')

def main():
    if len(sys.argv) != 4:
        print("Usage: convert_ifcfg.py [to-rh|to-suse] input_file output_file")
        sys.exit(1)

    direction = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]

    cfg = parse_ifcfg(input_file)
    if direction == "to-rh":
        new_cfg = convert_to_rh(cfg)
    elif direction == "to-suse":
        new_cfg = convert_to_suse(cfg)
    else:
        print("Invalid direction: use to-rh or to-suse")
        sys.exit(1)

    write_ifcfg(new_cfg, output_file)
    print(f"Converted: {output_file}")

if __name__ == "__main__":
    main()
