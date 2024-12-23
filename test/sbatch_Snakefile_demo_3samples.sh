#!/bin/bash
#SBATCH -p all              ## Specify SLURM partition for job submssion
#SBATCH -t 5-00:00:00
#SBATCH --mem=10G
#SBATCH -J submit_snakemake_%j
#SBATCH -o submit_snakemake_%j.out
#SBATCH -e submit_snakemake_%j.err

## submit the snakemake for sample list

## configure shell: full path to conda.sh
source ~/miniconda3/etc/profile.d/conda.sh

conda activate iSHARC

## mkdir for cluster submission logs
## defined in .workflow/config/cluster_std_err.json
cd  /cluster/projects/tcge/scMultiome/iSHARC_demo_3samples
mkdir -p logs_cluster

## unlock workdir just in case the folder locked accidently before
snakemake --snakefile /cluster/home/yzeng/snakemake/iSHARC/workflow/Snakefile \
          --configfile /cluster/home/yzeng/snakemake/iSHARC/test/config_demo_3samples.yaml \
          --unlock

## -p   partition to submit for SLURM
## --mem    request memory, specify as much as you can. As we tested, 60G can handle all real cfMeDIP-seq datasets so far.
## --jobs   ## number of samples in modified sample_tmplate.tsv files (independent steps will be scheduled per sample)
## keep-going: Go on with independent jobs if a job fails
## sbatch -c :  maximal 12 threads per multithreading job by default, less -c INT  will be scaled down to INT

snakemake --snakefile /cluster/home/yzeng/snakemake/iSHARC/workflow/Snakefile \
          --configfile /cluster/home/yzeng/snakemake/iSHARC/test/config_demo_3samples.yaml \
          --cluster-config /cluster/home/yzeng/snakemake/iSHARC/workflow/config/cluster_std_err.json \
          --keep-going  --use-conda  --conda-prefix ${CONDA_PREFIX}_extra_env \
          --cluster "sbatch -p veryhimem -c 12 --mem=80G -J {cluster.jid} -o {cluster.std} -e {cluster.err} -t 5-00:00:00" \
          --latency-wait 60 --jobs 6 -p

## using higher mem for large dataset integration
# eg: veryhimem -c 12 --mem=600G

conda deactivate
