
#!/usr/bin/env python3
import sys
import os
import configparser
import argparse

def parse_nm_keyfile(filepath):
    config = configparser.ConfigParser(strict=False, delimiters=("=",))
    config.optionxform = str
    config.read(filepath)
    return config

def convert_to_link(config):
    interface_name = config.get("connection", "interface-name", fallback="eth0")
    mac = config.get("ethernet", "mac-address", fallback=None)
    lines = ["[Match]"]
    if mac:
        lines.append(f"MACAddress={mac}")
    else:
        lines.append(f"OriginalName={interface_name}")
    lines += ["", "[Link]", f"Name={interface_name}"]
    return interface_name, "\n".join(lines)

def convert_to_network(config):
    interface_name = config.get("connection", "interface-name", fallback="eth0")
    method = config.get("ipv4", "method", fallback="auto")
    lines = ["[Match]", f"Name={interface_name}", "", "[Network]"]
    if method == "auto":
        lines.append("DHCP=yes")
    elif method == "manual":
        addresses = config.get("ipv4", "address1", fallback=None)
        gateway = config.get("ipv4", "gateway", fallback=None)
        dns = config.get("ipv4", "dns", fallback=None)
        if addresses:
            lines.append(f"Address={addresses.split(',')[0]}")
        if gateway:
            lines.append(f"Gateway={gateway}")
        if dns:
            lines.append(f"DNS={dns}")
    return interface_name, "\n".join(lines)

def convert_to_vlan_netdev(config):
    name = config.get("connection", "interface-name", fallback="vlan100")
    id = config.get("vlan", "id", fallback="100")
    dev = config.get("vlan", "parent", fallback="eth0")
    lines = [
        "[NetDev]",
        f"Name={name}",
        "Kind=vlan",
        "",
        "[VLAN]",
        f"Id={id}"
    ]
    return name, "\n".join(lines)

def convert_to_bond_netdev(config):
    name = config.get("connection", "interface-name", fallback="bond0")
    mode = config.get("bond", "mode", fallback="active-backup")
    lines = [
        "[NetDev]",
        f"Name={name}",
        "Kind=bond",
        "",
        "[Bond]",
        f"Mode={mode}"
    ]
    return name, "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Convert NetworkManager keyfile to systemd-networkd format.")
    parser.add_argument("nm_file", nargs="?", help="Path to NetworkManager keyfile")
    parser.add_argument("output_dir", nargs="?", help="Output directory")
    parser.add_argument("-t", "--type", choices=["network", "bonding", "vlan"], default="network", help="Type of interface to convert")

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)

    args = parser.parse_args()

    if not args.nm_file or not args.output_dir:
        parser.print_help()
        sys.exit(1)

    config = parse_nm_keyfile(args.nm_file)
    os.makedirs(args.output_dir, exist_ok=True)

    if args.type == "bonding":
        name, netdev = convert_to_bond_netdev(config)
        with open(os.path.join(args.output_dir, f"{name}.netdev"), "w") as f:
            f.write(netdev)
    elif args.type == "vlan":
        name, netdev = convert_to_vlan_netdev(config)
        with open(os.path.join(args.output_dir, f"{name}.netdev"), "w") as f:
            f.write(netdev)
    else:
        name, network = convert_to_network(config)
        with open(os.path.join(args.output_dir, f"{name}.network"), "w") as f:
            f.write(network)

    name, link = convert_to_link(config)
    with open(os.path.join(args.output_dir, f"{name}.link"), "w") as f:
        f.write(link)

    print(f"[+] Converted configuration written to: {args.output_dir}")

if __name__ == "__main__":
    main()
