## Input configfile specification
> **IMPORTANT**: READ THROUGH THE GUIDE INFORMATION IN THE TEMPLATES TO MAKE CORRECT MANIFEST TALBES AND CONFIG FILE.

### Step 1: Prepare Cell Rancer ARC and corresponding reference
Before starting a run with FASTQ files, ensure that [Cell Ranger ARC](https://support.10xgenomics.com/single-cell-multiome-atac-gex/software/pipelines/latest/what-is-cell-ranger-arc) and corresponding genome reference (e.g., [GRCh38](https://cf.10xgenomics.com/supp/cell-arc/refdata-cellranger-arc-GRCh38-2020-A-2.0.0.tar.gz)) are installed and downloaded. You will need to specify their PATHs in the config.yaml file. If you are starting with existing Cell Ranger ARC outputs, these steps can be skipped.

2) The template for the sample FASTQ data or Cell Ranger ARC outputs table is provided. Note: Ensure the table `headers` match exactly as specified. The `gex_seq_path` and  `atac_seq_path` are required when staring from FASTQ files, and the `arc_outs_path` is essential when running the pipeline with existing outputs from Cell Ranger ARC.

|	sample_id   |  sample_seq_id	 |  gex_seq_path |  atac_seq_path | arc_outs_path  |
|-------------|------------------|---------------|----------------|----------------|
|  Sample1	  |   Sample1_seq    | ./iSHARC/test/dummy_data/Sample1_seq/GEX | ./iSHARC/test/dummy_data/Sample1_seq/ATAC	|    iSHARC/test/dummy_data/Sample1_arc_outs |                      |
|  Sample2	  |   Sample1_seq    | ./iSHARC/test/dummy_data/Sample1_seq/GEX | ./iSHARC/test/dummy_data/Sample1_seq/ATAC |
iSHARC/test/dummy_data/Sample1_arc_outs |  


3) The samples aggregation template, which can be different from the sample seq information table.

|	sample_id   |
|-------------|
|  Sample1	|
|  Sample2	|


### Step 2: Specify input configuration file by following the instructions
A configuration YAML file is required to specify the paths to all input files and the parameters needed to successfully run the pipeline. Important: Always use absolute paths instead of relative paths in your configuration files. For more detailed instructions, refer to the [config_template](./test/config_template.yaml)


## Test datasets

`dummy_data/`: Contains data for performing a quick dry run of the pipeline to verify that all configurations are correctly set. It also facilitates generating the DAG for the templates.   