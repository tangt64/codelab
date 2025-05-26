#!/usr/bin/env python3
import sys
import os
import re

def parse_ifcfg(path):
    cfg = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip().strip('"').strip("'")
    return cfg

def build_nmcli_commands(cfg, os_type):
    cmds = []
    name = cfg.get("DEVICE") or cfg.get("INTERFACENAME") or "eth0"
    ip = cfg.get("IPADDR", "")
    nm = cfg.get("NETMASK", "")
    prefix = "24"
    if nm == "255.255.0.0":
        prefix = "16"
    elif nm == "255.0.0.0":
        prefix = "8"
    elif re.match(r'^\d+$', nm):
        prefix = nm

    con_type = "ethernet"
    if cfg.get("BONDING_MASTER") == "yes" or "BONDING_OPTS" in cfg:
        con_type = "bond"
        bondmode = cfg.get("BONDING_MODE", "active-backup")
        if "BONDING_OPTS" in cfg:
            mo = re.search(r"mode=(\w+)", cfg["BONDING_OPTS"])
            if mo:
                bondmode = mo.group(1)
        cmds.append(f"nmcli connection add type bond ifname {name} mode {bondmode}")

    elif cfg.get("SLAVE", "").lower() == "yes" or "MASTER" in cfg:
        con_type = "ethernet"
        master = cfg.get("MASTER", "bond0")
        cmds.append(f"nmcli connection add type ethernet slave-type bond con-name {name} ifname {name} master {master}")
        return cmds

    ipline = f"{ip}/{prefix}" if ip and prefix else "dhcp"
    bootproto = cfg.get("BOOTPROTO", "dhcp")
    if bootproto == "dhcp":
        cmds.append(f"nmcli connection add type {con_type} ifname {name} con-name {name} autoconnect yes ipv4.method auto")
    else:
        cmds.append(f"nmcli connection add type {con_type} ifname {name} con-name {name} autoconnect yes ipv4.method manual ipv4.addresses {ipline}")
    return cmds

def main():
    if len(sys.argv) != 3:
        print("Usage: nmcli_migrate.py <suse|rhel> <ifcfg-file>")
        sys.exit(1)

    target = sys.argv[1]
    infile = sys.argv[2]

    if target not in ["suse", "rhel"]:
        print("Target must be either 'suse' or 'rhel'")
        sys.exit(1)

    cfg = parse_ifcfg(infile)
    cmds = build_nmcli_commands(cfg, target)
    print("\n".join(cmds))

if __name__ == "__main__":
    main()
