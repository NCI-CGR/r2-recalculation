# Snakefile - Snakemake pipeline to recalculate r2 with snptest
# Reads configuration from config.yaml (see example config.yaml)

configfile: "config.yaml"

import os
import re
import sys

# ---- Required config keys ----
REQUIRED_KEYS = [
    "ranges_file",
    "vcf_dir",
    "vcf_suffix",
    "sample_file",
    "sample_dir",
    "sample_suffix",
    "include_all",
    "output_base",
]

missing = [k for k in REQUIRED_KEYS if k not in config]
if missing:
    sys.exit(f"ERROR: Missing required config keys in config.yaml: {missing}")

# ---- Load config ----
RANGES_FILE   = config["ranges_file"]
VCF_DIR       = config["vcf_dir"]
VCF_SUFFIX    = config["vcf_suffix"]
SAMPLE_FILE   = config["sample_file"]
SAMPLE_DIR    = config["sample_dir"]
SAMPLE_SUFFIX = config["sample_suffix"]
INCLUDE_ALL   = config["include_all"]
OUTPUT_BASE   = config["output_base"]

# ---- validation ----
if not os.path.exists(RANGES_FILE):
    sys.exit(f"ERROR: ranges_file not found: {RANGES_FILE}")

if not os.path.isdir(VCF_DIR):
    sys.exit(f"ERROR: vcf_dir not found: {VCF_DIR}")

if not os.path.isdir(SAMPLE_DIR):
    sys.exit(f"ERROR: sample_dir not found: {SAMPLE_DIR}")

if "{CHR}" not in SAMPLE_FILE and not os.path.exists(SAMPLE_FILE):
    sys.exit(f"ERROR: sample_file not found: {SAMPLE_FILE}")


def load_ranges(ranges_file):
    range_map = {}
    chrs = set()
    with open(ranges_file) as fh:
        for ln in fh:
            ln = ln.strip()
            if not ln or ln.startswith("#"):
                continue
            m = re.match(r'^(?:chr)?(?P<chr>[^:]+):(?P<rest>.+)$', ln, re.IGNORECASE)
            if not m:
                raise ValueError(f"Bad range line: {ln}")
            chr_full = f"chr{m.group('chr')}"
            rest = m.group("rest")
            range_map[(chr_full, rest)] = f"{chr_full}:{rest}"
            chrs.add(chr_full)
    return range_map, sorted(chrs)

def discover_groups(sample_dir, sample_suffix):
    groups = []
    for fname in os.listdir(sample_dir):
        if fname.endswith(sample_suffix):
            groups.append(os.path.splitext(fname)[0])
    groups = sorted(set(groups))
    if INCLUDE_ALL and "ALL" not in groups:
        groups.append("ALL")
    if not groups:
        sys.exit("ERROR: No group files discovered in sample_dir.")
    return groups


RANGE_MAP, CHROMS = load_ranges(RANGES_FILE)
GROUPS = discover_groups(SAMPLE_DIR, SAMPLE_SUFFIX)

TARGETS = []
for (chr_full, range_suffix), _ in RANGE_MAP.items():
    for group in GROUPS:
        filename = f"{chr_full}_{group}_{range_suffix}_recal_r2.txt"
        TARGETS.append(os.path.join(OUTPUT_BASE, chr_full, filename))

rule all:
    input:
        TARGETS

rule process_vcf:
    input:
        vcf=lambda wc: os.path.join(VCF_DIR, f"{wc.CHR}{VCF_SUFFIX}"),
        sample=lambda wc: (SAMPLE_FILE.format(CHR=wc.CHR) if "{CHR}" in SAMPLE_FILE else SAMPLE_FILE)
    output:
        os.path.join(OUTPUT_BASE, "{CHR}", "{CHR}_{GROUP}_{RANGE_SUFFIX}_recal_r2.txt")
    params:
        range_raw=lambda wc: RANGE_MAP[(wc.CHR, wc.RANGE_SUFFIX)],
        include_opt=lambda wc: (
            f"-include_samples {os.path.join(SAMPLE_DIR, wc.GROUP + SAMPLE_SUFFIX)}"
            if (wc.GROUP.upper() != "ALL" and os.path.exists(os.path.join(SAMPLE_DIR, wc.GROUP + SAMPLE_SUFFIX)))
            else ""
        )
    shell:
        r"""
        mkdir -p $(dirname {output})
        module load snptest/2.5.6

        if [ ! -f "{input.vcf}" ]; then
            echo "ERROR: Missing VCF file {input.vcf}" >&2
            exit 1
        fi

        if [ ! -f "{input.sample}" ]; then
            echo "ERROR: Missing sample file {input.sample}" >&2
            exit 1
        fi

        snptest -summary_stats_only -range {params.range_raw} -chunk 10000 -data {input.vcf} {input.sample} {params.include_opt} -genotype_field GP -o {output}
        """

print("Configuration loaded successfully.")
print(f"Discovered groups: {GROUPS}")
