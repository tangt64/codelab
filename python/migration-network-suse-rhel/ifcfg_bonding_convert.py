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

def write_ifcfg(cfg, path):
    with open(path, 'w') as f:
        for k, v in cfg.items():
            f.write(f'{k}="{v}"\n')

def convert_bond_master_rh_to_suse(cfg):
    out = {}
    out["DEVICE"] = cfg.get("DEVICE", "bond0")
    out["BONDING_MASTER"] = "yes"
    out["STARTMODE"] = "onboot"

    # BONDING_OPTS → BONDING_MODE, MIIMON 등 추출
    opts = cfg.get("BONDING_OPTS", "")
    mode_match = re.search(r"mode=(\w+)", opts)
    miimon_match = re.search(r"miimon=(\d+)", opts)

    if mode_match:
        out["BONDING_MODE"] = mode_match.group(1)
    if miimon_match:
        out["MIIMON"] = miimon_match.group(1)

    return out

def convert_bond_slave_rh_to_suse(cfg):
    out = {}
    out["DEVICE"] = cfg.get("DEVICE", "eth0")
    out["MASTER"] = cfg.get("MASTER", "bond0")
    out["STARTMODE"] = "onboot"
    out["INTERFACENAME"] = out["DEVICE"]
    return out

def main():
    if len(sys.argv) != 4:
        print("Usage: bonding_ifcfg_converter.py [master|slave] input_file output_file")
        sys.exit(1)

    role = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]

    cfg = parse_ifcfg(input_file)

    if role == "master":
        new_cfg = convert_bond_master_rh_to_suse(cfg)
    elif role == "slave":
        new_cfg = convert_bond_slave_rh_to_suse(cfg)
    else:
        print("Invalid role: use 'master' or 'slave'")
        sys.exit(1)

    write_ifcfg(new_cfg, output_file)
    print(f"Converted bonding {role}: {output_file}")

if __name__ == "__main__":
    main()
