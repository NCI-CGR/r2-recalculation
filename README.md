# Recalculate Imputed r² with SNPTEST (Snakemake Pipeline)

## Overview

This pipeline runs SNPTEST to produce recalculated r² for specified groups.
It is configured via `config.yaml` and auto-discovers group files in the `groups/` directory. Outputs are written to the `results/` directory.

## Required files

1. `config.yaml` — strict configuration (see example)
2. `ranges.txt` — one `chr:start-end` per line
3. `groups/` — directory with groups `EUR.txt`, `Project1.txt`, etc. (one sample ID per line)
4. An Oxford SNPTEST `.sample` file (path set in `config.yaml`)
5. SLURM submission script (`run_snakemake_slurm.sh`) — use for cluster runs


## Recommended folder layout

```
repo/
├── Snakefile
├── config.yaml
├── run_snakemake_slurm.sh
├── ranges.txt
└── results/

```

Edit `config.yaml` (example below) and place it next to the `Snakefile`. The Snakefile is strict and will exit if required keys are missing.
## Example `config.yaml`

```yaml
ranges_file: "ranges.txt"

vcf_dir: "/path/to/vcfs"
vcf_suffix: ".dose.vcf.gz"

sample_file: "/path/to/sample_files/all_samples.sample"

sample_dir: "/path/to/groups"
sample_suffix: ".txt"

include_all: false

output_base: "results"
```

**Important:** The pipeline will exit if any of the above keys are missing.

---

# Input files (formats & examples)

## 1) `ranges.txt` — REQUIRED
- One range per line
- Format: `chrN:start-end` (e.g. `chr1:1-29392142`)
- Blank lines and lines starting with `#` are ignored

Example:
```
# chr1 ranges
chr1:1-29392142
chr1:29392143-38265949

# chr2 sample range
chr2:1-10000000
```

You may optionally omit the `chr` prefix (the loader will accept `1:1-1000000` and normalize it).
The ranges in this file were calculated based on TOPMed-imputed data.
If you are using a different imputation panel (e.g., 1000 Genomes, HRC, etc.),please modify the genomic ranges according to your imputed dataset.

---
## 2) `/path/groups/` directory — optional but expected
- Each file is named `<GROUP>.txt` (e.g. `EUR.txt`, `Project1.txt`, `male.txt`)
- Each file contains **one sample ID per line**, exactly matching sample IDs in the VCF header

Example `groups/EUR.txt`:
```
NA12878
NA12891
NA12892
```

If `groups/` contains `EUR.txt` and `AFR.txt`, the pipeline will produce jobs for those groups. The pipeline can optionally include an `ALL` pseudo-group (disabled by default) to run without any `-include_samples` filter.
Ensure IDs exactly match the VCF sample IDs (case-sensitive).

---

## 3) Oxford `.sample` file — REQUIRED (path set in `config.yaml` as `sample_file`)
SNPTEST expects an Oxford-style `.sample` file (not PLINK .ped).

```
ID_1 ID_2 missing
0 0 0
NA12878 NA12878 0
NA12891 NA12891 0
```

- `ID_1` and `ID_2` must match VCF sample names exactly.
- If you want to include phenotypes/covariates, expand columns and types (see SNPTEST docs https://www.chg.ox.ac.uk/~gav/snptest/#input_file_formats).


Use this one-liner on a VCF (gzipped):

```bash
zcat /path/to/chr1.dose.vcf.gz | \
grep "^#CHROM" | \
awk '{{ print "ID_1 ID_2 missing"; print "0 0 0"; for(i=10;i<=NF;i++) print $i" "$i" 0" }}' > sample_files/all_samples.sample
```


## Running locally

Dry-run:

```bash
snakemake -n
```

Run locally using 8 cores:

```bash
snakemake -j 8
```

## Running on SLURM

If you want to submit the workflow to SLURM, use the provided script `run_snakemake_slurm.sh`.

---

# How the pipeline works (high level)

For every `(CHR, GROUP, RANGE)` combination the pipeline:

1. Looks for VCF `${vcf_dir}/${CHR}${vcf_suffix}` (e.g. `.../chr2.dose.merged.vcf.gz`)
2. Uses `sample_file` as the Oxford `.sample`
3. If `groups/${GROUP}.txt` exists (and `GROUP != ALL`), adds `-include_samples groups/${GROUP}.txt`
4. Runs `snptest -summary_stats_only` with the configured options
5. Writes output to `results/{CHR}/{CHR}_{GROUP}_{start-end}_recal_r2.txt`

---

# Output layout & filename scheme

Outputs are placed under `results/{CHR}/`:

```
results/
  chr1/
    chr1_EUR_1-29392142_recal_r2.txt
    chr1_AFR_1-29392142_recal_r2.txt
    chr1_ALL_1-29392142_recal_r2.txt  (if include_all enabled)
  chr2/
    chr2_EUR_1-10000000_recal_r2.txt
```

Filename format:
```
{CHR}_{GROUP}_{start-end}_recal_r2.txt
```
