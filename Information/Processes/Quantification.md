---
type: process
input: 
    - reads
    - salmon_index
    - gtf
output: 
    - results
    - transcript_quant
    - gene_quant
    - meta_info
    - lib_format_counts
    - versions
image:
parent:
child:
    - GTF_PREPARE
    - SALMON_QUANT
tools: 
    - Salmon
---
# Quantification

## Description
The Quantification subworkflow estimates transcript- and gene-level abundance from the provided FASTQ reads using Salmon. Before quantification, the reference GTF annotation is prepared by decompressing it if necessary. The Salmon index and corresponding GTF annotation are matched by reference identifier to ensure that compatible reference files are used for each sample. The reads are then combined with the appropriate index and annotation and passed to Salmon, which performs quasi-mapping-based quantification with mapping validation enabled. Both single-end and paired-end sequencing data are supported.

For each sample, the subworkflow produces transcript-level and gene-level quantification tables, along with Salmon metadata and library format statistics. The Salmon software version is also recorded to support reproducibility. These outputs provide the abundance estimates for downstream processing and reporting.
