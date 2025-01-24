################################################################################
##  initialization_of_individual_sample.R is a function for creating Seurat
##  object with RNA, ATAC_ARC and ATAC assays, as well as adding QC metrics.
##  The analyses includes:
##      * re-peak calling using MACS for ATAC assay
##      * QC metrics for RNA and ATAC
##
## Contact : Yong Zeng <yong.zeng@uhn.ca>
################################################################################


############################################
### parse arguments and set output directory
############################################
{
suppressPackageStartupMessages(library("argparse"))

# create parser object
parser <- ArgumentParser()

## adding parameters
## by default ArgumentParser will add an help option
## run "Rscript main_for_individual_sample.R -h" for help info
parser$add_argument("-s", "--sample_id", required=TRUE,
                    help = "Unique sample ID")
parser$add_argument("-fbm", "--feature_barcode_matrix", required=TRUE,
                    help = "filtered_feature_bc_matrix.h5 file for the matrix of features, genes and ATAC peaks detected, by barcodes from cellranger ARC outs folder")
parser$add_argument("-pbm", "--per_barcode_metrics", required=TRUE,
                    help = "per_barcode_metrics.csv file for QC metrics per barcode")
parser$add_argument("-atac", "--atac_file",required=TRUE,
                    help = "atac_fragments.tsv.gz file for ATAC from cellranger ARC outs foler. The index file needs to be in the same location")
parser$add_argument("-macs", "--macs_dir", required=TRUE,
                    help = "The PATH to executable MSAC2")
parser$add_argument("-pipe", "--pipe_dir", required=TRUE,
                    help = "The PATH to iSHARC pipeline, which local dependences included")
parser$add_argument("-min_RNA", "--min_nCount_RNA", type = "integer", default = 1000,
                    help = "Minimal nCount_RNA for second round QC filtering")
parser$add_argument("-max_RNA", "--max_nCount_RNA", type = "integer", default = 25000,
                    help = "Maximum nCount_RNA for second round QC filtering")
parser$add_argument("-min_ATAC", "--min_nCount_ATAC", type = "integer", default = 5000,
                    help = "Minimal nCount_ATAC for second round QC filtering")
parser$add_argument("-max_ATAC", "--max_nCount_ATAC", type = "integer", default = 70000,
                    help = "Maximum nCount_ATAC for second round QC filtering")
parser$add_argument("-max_MT", "--max_pct_MT", type = "integer", default = 20,
                    help = "Maximum percentage of MT for second round QC filtering")
parser$add_argument("-mim_TSS", "--min_TSS_Enrichment", type = "integer", default = 1,
                    help = "Minimal TSS enrichment score for second round QC filtering")
parser$add_argument("-mim_NS", "--max_Nucleosome_Signal", type = "integer", default = 1,
                    help = "Maximun nucleosome signal score for second round QC filtering")

## assigning passing arguments
args <- parser$parse_args()
print(args)

sample_id <- args$sample_id
fbm_file <- args$feature_barcode_matrix
pbm_file <- args$per_barcode_metrics
atac_file <- args$atac_file
macs2_dir <- args$macs_dir
pipe_dir <- args$pipe_dir

out_dir <- paste0(getwd(), "/individual_samples/", sample_id, "/") ## with forward slash at the end
}


############################
### loading required packages
#############################
{
suppressMessages(library(hdf5r))           ## to read HDF5 files
suppressMessages(library(Seurat))
suppressMessages(library(Signac))
suppressMessages(library(ggplot2))
suppressMessages(library(EnsDb.Hsapiens.v86))
}

###############################################
### read in files and parameters initialization
###############################################
{
## hdf 5 file after joint cell calling
fbm_data <- Read10X_h5(fbm_file)

## sparse Matrix of class "dgCMatrix"
rna_counts <- fbm_data$`Gene Expression`
atac_counts <- fbm_data$Peaks                  ## peaks called by cellranger-arc
rm(fbm_data)

### gene anno_gene to UCSC style failed, which might be due to version of Signac and GenomeInfoDb
## tried to load locally generated anno_gene with above codes, failed as well ..
if(FALSE){
anno_gene <- GetGRangesFromEnsDb(ensdb = EnsDb.Hsapiens.v86)     ## signac
## change NCBI chromosome format "1, 2, X, Y, MT" to UCSC format "chr1, chr2, chrX,Y,M"
## seqlevelsStyle(anno_gene) <- 'UCSC'       ## failed due to "cannot open URL on server ..."
anno_gene_v <- "hg38"
genome(anno_gene) <- anno_gene_v
}

## loading annotation data from pipeline repo
anno_rds <- paste0(pipe_dir, "/workflow/dependencies/EnsDb.Hsapiens.v86_2UCSC_hg38.RDS")
anno_gene <- readRDS(anno_rds)
genome_info <- seqinfo(anno_gene)


## read in metrics per barcodes
pbm <- read.csv(pbm_file)

## Parallelization using plan for both seurat and signac
## plan("multiprocess", workers = 4)

print("The data loading has been successfully completed!!")

}


###################################################################
## add RNA, ATAC_ARC and ATAC assay to a Seurat object (scMultiome)
###################################################################
{

################
## add RNA assay
# Create Seurat object and add chrM percentage to meta data
scMultiome <- CreateSeuratObject(counts = rna_counts)
scMultiome[["pct_MT"]] <- PercentageFeatureSet(scMultiome, pattern = "^MT-")
rm(rna_counts)

#######################################################
# add the ATAC-seq data generated by cellranger-arc
# Only use peaks in standard chromosomes: chr1-22 + chrX + chrY
grange.counts <- StringToGRanges(rownames(atac_counts), sep = c(":", "-"))
grange.use <- seqnames(grange.counts) %in% standardChromosomes(grange.counts)
atac_counts <- atac_counts[as.vector(grange.use), ]

## add ATAC assay by cellranger-arc
## if genome is assigned as "hg38" or "GRCh38", the internet is required for download!!!
chrom_assay <- CreateChromatinAssay(
                  counts = atac_counts,
                  sep = c(":", "-"),
                  genome = genome_info,
                  fragments = atac_file,
                  min.cells = 0,
                  min.features = 0,
                  annotation = anno_gene
                )

scMultiome[["ATAC_ARC"]] <- chrom_assay

rm(atac_counts, chrom_assay)

########################
## call peaks using MAC2
DefaultAssay(scMultiome) <- "ATAC_ARC"

## need to specify the outdir, folder needs to be create in advance
peaks <- CallPeaks(scMultiome, macs2.path = macs2_dir,
                  outdir = out_dir,  fragment.tempdir = out_dir)

# remove peaks on nonstandard chromosomes and in genomic blacklist regions
peaks <- keepStandardChromosomes(peaks, pruning.mode = "coarse")
peaks <- subsetByOverlaps(x = peaks, ranges = blacklist_hg38, invert = TRUE)

## quantify counts in each peak
## counting fragments (as ArchR)rather than cut sites by cellranger-arc
macs2_counts <- FeatureMatrix(
                  fragments = Fragments(scMultiome),
                  features = peaks,
                  sep = c("-", "-"),                 ##  c(":", "-") will lead to invalid character indexing
                  cells = colnames(scMultiome)
                )

## using the same granges format
tmp <- unlist(strsplit(rownames(macs2_counts), "-"))
LL <- length(tmp)
n_name <- paste0(tmp[seq(1, LL, 3)], ":", tmp[seq(2, LL, 3)], "-", tmp[seq(3, LL, 3)])
rownames(macs2_counts) <- n_name

################################################################################
# Add ATAC assay using the MACS2 peak set and add it to the Seurat object
scMultiome[["ATAC"]] <- CreateChromatinAssay(
                          counts = macs2_counts,
                          sep = c(":", "-"),
                          genome = genome_info,
                          fragments = atac_file,
                          min.cells = 0,
                          min.features = -1,               ##  set negative to ensure same number of cells!!
                          annotation = anno_gene
                        )

rm(macs2_counts)

####################################
#####  add ATAC specific QC metircs
DefaultAssay(scMultiome) <- "ATAC"

# compute nucleosome signal score per cell
scMultiome <- NucleosomeSignal(object = scMultiome)
scMultiome$Nucleosome_Signal <- scMultiome$nucleosome_signal
scMultiome$Nucleosome_Percentile <- scMultiome$nucleosome_percentile
scMultiome$nucleosome_signal <- scMultiome$nucleosome_percentile<- NULL

# compute TSS enrichment score per cell
scMultiome <- TSSEnrichment(object = scMultiome, fast = FALSE)
scMultiome$TSS_Enrichment <- scMultiome$TSS.enrichment
scMultiome$TSS_Percentile <- scMultiome$TSS.percentile
scMultiome$TSS.enrichment <- scMultiome$TSS.percentile <- NULL

## add blacklist ratio and fraction of reads in peaks
idx_b <- match(rownames(scMultiome[[]]), pbm$barcode)
pbm_f <- pbm[idx_b, ]

scMultiome[["pctFragments_in_Peaks"]] <- pbm_f$atac_peak_region_fragments / pbm_f$atac_fragments * 100

scMultiome[["pctFragments_in_Blacklist"]] <- FractionCountsInRegion(
                                                        object = scMultiome,
                                                        assay = 'ATAC',
                                                        regions = blacklist_hg38
                                                      )

###############################
#####  QC metrics visualization

## violin plots for QC metrics
## only plot features without missing values or NA

is_na <- is.na(scMultiome[[]])
idx_na <- colSums(is_na) > 0
f_plot <-  colnames(scMultiome[[]])[!idx_na][-1]

## for all QC metrics
g <- VlnPlot(scMultiome, features = f_plot,
             ncol = 4, log = TRUE, pt.size = 0, group.by = "orig.ident") + NoLegend()
g <- g & theme(axis.title.x = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank())
ggsave(paste0(out_dir, sample_id, "_VlnPlot_4_QC_metrics.pdf"), width = 12, height = 8)

## for selected QC metrics
g <- VlnPlot(scMultiome, features = c("nCount_RNA", "pct_MT", "nCount_ATAC", "TSS_Enrichment", "Nucleosome_Signal"),
             ncol = 4, log = TRUE, pt.size = 0, group.by = "orig.ident") + NoLegend()
g <- g & theme(axis.title.x = element_blank(), axis.text.x = element_blank(), axis.ticks.x = element_blank())
ggsave(paste0(out_dir, sample_id, "_VlnPlot_4_QC_metrics.pdf"), width = 12, height = 8)

## percentiles and MADs for selected QC metrics
## NA removed
qc_df <- data.matrix(scMultiome [[c("nCount_RNA", "pct_MT", "nCount_ATAC", "TSS_Enrichment",
                                      "Nucleosome_Signal", "pctFragments_in_Peaks", "pctFragments_in_Blacklist")]])
probs_s <- c(0, 0.025, 0.25, 0.50, 0.75, 0.975, 1)
qc_percentiles <- apply(qc_df, 2, function(x) quantile(x, probs = probs_s, na.rm = TRUE))

upper_3mad <- apply(qc_df, 2, function(x) median(x, na.rm = TRUE) + 3 * mad(x, na.rm = TRUE))
lower_3mad <- apply(qc_df, 2, function(x) median(x, na.rm = TRUE) - 3 * mad(x, na.rm = TRUE))
qc_out <- rbind(qc_percentiles, lower_3mad, upper_3mad)
write.csv(qc_out, file = paste0(out_dir, sample_id, "_QC_metrics_percentiles_and_MADs.csv"))




#######################################
## assess the automactic second-round QC
{

## taking both MADs and preset cutoffs into account
rna_upper <-  min(args$max_nCount_RNA, upper_3mad["nCount_RNA"])
rna_lower <-  max(args$min_nCount_RNA, lower_3mad["nCount_RNA"])
atac_uppper <- min(args$max_nCount_ATAC, upper_3mad["nCount_ATAC"])
atac_lower  <- max(args$min_nCount_ATAC, lower_3mad["nCount_ATAC"])
mt_upper  <- min(args$max_MT, upper_3mad["pct_MT"])
tss_lower <- max(args$min_TSS_Enrichment, lower_3mad["TSS_Enrichment"])
ns_upper  <- min(args$max_Nucleosome_Signal, upper_3mad["Nucleosome_Signal"])

qc_df <- data.frame(qc_df)   ## convert to data frame

idx_RNA <- qc_df$nCount_RNA > rna_lower &  qc_df$nCount_RNA < rna_upper

idx_ATAC <- qc_df$nCount_ATAC > atac_lower & qc_df$nCount_ATAC < atac_uppper

idx_MT <- qc_df$pct_MT < mt_upper

idx_TSS <- qc_df$TSS_Enrichment > tss_lower

idx_NS <- qc_df$Nucleosome_Signal < ns_upper

## counting
cnt_RNA <- sum(idx_RNA & idx_MT, na.rm = T)
cnt_ATAC <- sum(idx_ATAC & idx_MT & idx_TSS & idx_NS, na.rm = T)
cnt_both <- sum(idx_RNA & idx_ATAC & idx_MT & idx_TSS & idx_NS, na.rm = T)

cnt_raw <- nrow(qc_df)

cells_2filtered <- data.frame(cnt_raw, cnt_RNA, cnt_ATAC, cnt_both)
cells_frac <- round(cells_2filtered / nrow(qc_df), 2)
cells_2filtered  <- rbind(cells_2filtered, cells_frac)

rownames(cells_2filtered) <- c("Number of cells", "Fraction of 1st filtered cells")
colnames(cells_2filtered) <- c("1st_joint_filtered", "2nd_filtered_by_RNA", "2nd_filtered_by_ATAC",        "2nd_filtered_by_Both")

scMultiome@misc[["second_QC_assessment"]] <- cells_2filtered
cells_2filtered

## save inital meta.data as misc
## scMultiome@misc[["initial_meta_data"]] <- scMultiome@meta.data


# Misc(scMultiome, slot = "second_QC_assessment") <- cells_2filtered  ## list to save as tbl_graph object
# will be added as a list
}

saveRDS(scMultiome, file = paste0(out_dir, sample_id, "_initial_seurat_object.RDS"))
write.csv(scMultiome@meta.data,  file = paste0(out_dir, sample_id, "_initial_meta_data.csv"))

print("The initialization of individual sample has been successfully completed!!")
}
