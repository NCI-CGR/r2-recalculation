#!/bin/sh

module load python3/3.10.2 slurm

DATE=$(date +%y%m%d)
mkdir -p logs_${DATE}

snakemake --cores=1 --unlock 
sbcmd="sbatch --partition=defq --cpus-per-task=10 --time=9-00:00:00 --output=logs_${DATE}/snakejob_%j.out"
snakemake --use-conda -pr --cluster "$sbcmd" --keep-going --rerun-incomplete --jobs 300 --latency-wait 120
