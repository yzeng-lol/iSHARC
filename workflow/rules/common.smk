workdir: config['work_dir']

## read in sample list
import os
import pandas as pd

## paths for pipeline and/or reference data
work_dir = config["work_dir"]
pipe_dir = config["pipe_dir"]
env_dir = os.getenv("CONDA_PREFIX")
samples_list = config["samples"]
samples_integr = config["samples_integr"]

######################################################
## read in sample and corresponding library file table
SAMPLES = (
    pd.read_csv(config["samples"], sep="\t")
    .set_index("sample_id", drop=False)
    .sort_index()
)


## read in samples for aggregation
if config["integration"]:
    SAMPLES_INTEGR = (
        pd.read_csv(config["samples_integr"], sep="\t")
        .set_index("sample_id", drop=False)
        .sort_index()
    )
else:
    SAMPLES_INTEGR = SAMPLES     ## must be defined

#############################################
## get taget outputs based on the config file
## either for individual samples or aggregate
## all samples listed in sample_aggr.tsv !!!
#############################################

def get_rule_all_input():
    ## ensure extra env installed
    extra_env = "extra_env/all_extra_env_installed",

    if config["integration"]:
        #integrated_rna = "integration/rna/RNA_integrated_by_anchors.RDS",
        #integrated_atac = "integration/atac/ATAC_integrated_by_anchors.RDS",
        integrated_rna_atac_harmony =  "integration/wnn/harmony/RNA_ATAC_integrated_by_WNN.RDS",
        integrated_rna_atac_anchor =  "integration/wnn/anchor/RNA_ATAC_integrated_by_WNN.RDS",
        integrate_report = "integration/Integrated_scMultiome_QC_and_Primary_Results_Report.html",

        return  extra_env + integrate_report   #+ integrated_rna_atac_harmony + integrated_rna_atac_anchor #+ integrated_rna + integrated_atac +

    else:         ## process individual sample
        arc_out = expand("arc_count/{samples}/outs/atac_fragments.tsv.gz", samples = SAMPLES["sample_id"]),
        main_out = expand("main_seurat/{samples}.RDS", samples = SAMPLES["sample_id"]),
        qc_report = expand("main_seurat/{samples}_scMultiome_QC_and_Primary_Results_Report.html", samples = SAMPLES["sample_id"]),

        return  extra_env + arc_out + main_out + qc_report


############################
## other functions for input
#############################

###############################
##  get corresponding bwa_index
def get_cellranger_arc_ref():
    if config["pdx"]:
        #return reference for PDX data
        return config["pdx_ref"]
    else:
        return config["arc_ref"]


#def get_library(wildcards):
#    return SAMPLES.loc[wildcards.sample]["sample_library"]

def get_sample_seq_id(wildcards):
    return SAMPLES.loc[wildcards.sample]["sample_seq_id"]

def get_gex_seq_path(wildcards):
    return SAMPLES.loc[wildcards.sample]["gex_seq_path"]

def get_atac_seq_path(wildcards):
    return SAMPLES.loc[wildcards.sample]["atac_seq_path"]
