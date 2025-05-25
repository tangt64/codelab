#!/usr/bin/env python3
import sys
import os
import re

def netmask_to_cidr(netmask):
    try:
        return sum([bin(int(x)).count('1') for x in netmask.split('.')])
    except:
        return 24  # fallback

def parse_ifcfg(filepath):
    cfg = {}
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip().strip('"').strip("'")
    return cfg

def convert_to_networkd(cfg):
    device = cfg.get("DEVICE", "eth0")
    lines = ["[Match]", f"Name={device}", "", "[Network]"]

    if cfg.get("BOOTPROTO", "") == "dhcp":
        lines.append("DHCP=yes")
    elif "IPADDR" in cfg:
        ip = cfg["IPADDR"]
        prefix = netmask_to_cidr(cfg.get("NETMASK", "255.255.255.0"))
        lines.append(f"Address={ip}/{prefix}")
        if "GATEWAY" in cfg:
            lines.append(f"Gateway={cfg['GATEWAY']}")
        if "DNS1" in cfg:
            lines.append(f"DNS={cfg['DNS1']}")

    return "\n".join(lines)

def convert_to_bond_netdev(cfg):
    name = cfg.get("DEVICE", "bond0")
    opts = cfg.get("BONDING_OPTS", "")
    mode = "active-backup"
    miimon = "100"
    mo = re.search(r"mode=(\w+)", opts)
    mm = re.search(r"miimon=(\d+)", opts)
    if mo:
        mode = mo.group(1)
    if mm:
        miimon = mm.group(1)

    lines = [
        "[NetDev]",
        f"Name={name}",
        "Kind=bond",
        "",
        "[Bond]",
        f"Mode={mode}",
        f"MIIMonitorSec={miimon}0ms" if int(miimon) < 1000 else f"MIIMonitorSec={int(miimon)//1000}s"
    ]
    return "\n".join(lines)

def convert_slave_to_network(cfg):
    device = cfg.get("DEVICE", "eth1")
    master = cfg.get("MASTER", "bond0")
    lines = [
        "[Match]",
        f"Name={device}",
        "",
        "[Network]",
        f"Bond={master}"
    ]
    return "\n".join(lines)

def main():
    if len(sys.argv) != 3:
        print("Usage: nm_to_systemd.py <ifcfg-file> <output-dir>")
        sys.exit(1)

    infile = sys.argv[1]
    outdir = sys.argv[2]
    os.makedirs(outdir, exist_ok=True)

    cfg = parse_ifcfg(infile)
    dev = cfg.get("DEVICE", "eth0")

    if "BONDING_OPTS" in cfg:
        outpath = os.path.join(outdir, f"{dev}.netdev")
        with open(outpath, "w") as f:
            f.write(convert_to_bond_netdev(cfg))
        print(f"[+] Created: {outpath}")

        outpath = os.path.join(outdir, f"{dev}.network")
        with open(outpath, "w") as f:
            f.write(convert_to_networkd(cfg))
        print(f"[+] Created: {outpath}")

    elif "MASTER" in cfg:
        outpath = os.path.join(outdir, f"{dev}.network")
        with open(outpath, "w") as f:
            f.write(convert_slave_to_network(cfg))
        print(f"[+] Created: {outpath}")

    else:
        outpath = os.path.join(outdir, f"{dev}.network")
        with open(outpath, "w") as f:
            f.write(convert_to_networkd(cfg))
        print(f"[+] Created: {outpath}")

if __name__ == "__main__":
    main()
