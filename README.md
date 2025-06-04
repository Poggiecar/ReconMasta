# ReconMasta

This repository contains a bash script for reconnaissance tasks.

## Setup

Run `setup.sh` to install the required tools. The script uses `apt` and `go` to fetch binaries and updates nuclei templates.

```bash
sudo ./setup.sh
```

After installation you can run `ReconMasta.sh` normally.

## Usage

```
./ReconMasta.sh [options]
```

Options:

- `-v`    : verbose output
- `-vv`   : very verbose output
- `-d` or `--debug` : enable debug mode and log all commands to `run.log`
- `--nuclei` : run Nuclei automatically
- `--no-nuclei` : skip Nuclei step

When debug mode is enabled, a `run.log` file will be created inside the generated
results folder containing a full command trace.

