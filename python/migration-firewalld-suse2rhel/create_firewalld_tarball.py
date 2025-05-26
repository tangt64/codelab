import os
import tarfile
import argparse
import sys

def create_firewalld_tarball(src_dir="/etc/firewalld", output_dir=".", tar_name="migration-firewalld.tar"):
    if not os.path.exists(src_dir):
        return f"Source directory {src_dir} does not exist."

    os.makedirs(output_dir, exist_ok=True)
    tar_path = os.path.join(output_dir, tar_name)

    with tarfile.open(tar_path, "w") as tar:
        tar.add(src_dir, arcname=os.path.basename(src_dir))

    return tar_path

def main():
    parser = argparse.ArgumentParser(
        description="Create a tarball of /etc/firewalld configuration for migration.",
        usage="python3 migrate_firewalld_tar.py --output-dir <destination_path> --tar-name <filename.tar>"
    )
    parser.add_argument("--output-dir", type=str, default=".", help="Directory to save the tarball (default: current directory)")
    parser.add_argument("--tar-name", type=str, default="migration-firewalld.tar", help="Name of the output tarball file")

    # 인자 없이 실행하면 도움말 출력
    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(1)

    args = parser.parse_args()
    result = create_firewalld_tarball(output_dir=args.output_dir, tar_name=args.tar_name)
    print(f"Tarball created at: {result}")

if __name__ == "__main__":
    main()
