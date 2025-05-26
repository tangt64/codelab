
import os
import subprocess
import datetime
import argparse
import sys
from pathlib import Path

def log(message, log_file):
    timestamp = datetime.datetime.now().isoformat()
    entry = f"[{timestamp}] {message}"
    print(entry)
    with open(log_file, "a") as f:
        f.write(entry + "\n")

def create_subvolume(target_path, log_file):
    if not os.path.exists(target_path):
        subprocess.run(["btrfs", "subvolume", "create", target_path], check=True)
        log(f"Subvolume created at {target_path}", log_file)
    else:
        log(f"Subvolume already exists at {target_path}", log_file)

def rsync_data(src, dst, log_file):
    cmd = ["rsync", "-aAXH", "--numeric-ids", "--info=progress2", f"{src}/", f"{dst}/"]
    log(f"Starting rsync from {src} to {dst}", log_file)
    result = subprocess.run(cmd)
    if result.returncode == 0:
        log(f"Finished rsync to {dst}", log_file)
    else:
        log(f"rsync failed from {src} to {dst} with return code {result.returncode}", log_file)

def generate_fstab_entry(uuid, subvol_name, mount_point, options="defaults,noatime"):
    return f"UUID={uuid} {mount_point} btrfs subvol={subvol_name},{options} 0 0\n"

def main():
    parser = argparse.ArgumentParser(
        description="Migrate a single XFS directory to a Btrfs subvolume.",
        usage="python3 migrate_dir_to_btrfs_subvol.py --xfs-dir <source_dir> --btrfs-mount <btrfs_mount_point> --subvol-name <name> --mount-point <mount_point> [--fstab-out <output_file>]"
    )
    parser.add_argument("--xfs-dir", required=False, help="Source directory on XFS filesystem")
    parser.add_argument("--btrfs-mount", required=False, help="Mount point of the Btrfs volume")
    parser.add_argument("--subvol-name", required=False, help="Name of the Btrfs subvolume to create")
    parser.add_argument("--mount-point", required=False, help="Mount point for the new subvolume")
    parser.add_argument("--fstab-out", help="Optional output file to write fstab entry")
    parser.add_argument("--log", default="/var/log/xfs_to_btrfs_single.log", help="Log file path")

    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(1)

    args = parser.parse_args()

    required_args = [args.xfs_dir, args.btrfs_mount, args.subvol_name, args.mount_point]
    if not all(required_args):
        parser.print_help(sys.stderr)
        sys.exit(1)

    log_file = args.log
    src = args.xfs_dir.rstrip("/")
    subvol_path = os.path.join(args.btrfs_mount.rstrip("/"), args.subvol_name)

    log("==== Starting single directory XFS to Btrfs subvolume migration ====", log_file)
    create_subvolume(subvol_path, log_file)
    rsync_data(src, subvol_path, log_file)

    if args.fstab_out:
        fstab_path = Path(args.fstab_out)
        with open(fstab_path, "w") as fstab:
            uuid_placeholder = "<UUID-of-BTRFS-device>"
            entry = generate_fstab_entry(uuid_placeholder, args.subvol_name, args.mount_point)
            fstab.write(entry)
        log(f"fstab entry written to {fstab_path}", log_file)

    log("==== Migration Completed ====", log_file)

if __name__ == "__main__":
    main()
