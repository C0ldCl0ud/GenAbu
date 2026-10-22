---
type: module
input:
    - meta, reads, index, gtf
output:
    - results
    - transcript_quant
    - gene_quant
    - meta_info
    - lib_format_counts
    - versions
image:
    - community.wave.seqera.io/library/salmon:2.7.0--74784226202c61b9
parent:
child:
    - QUANTIFICATION
tools:
    - Salmon
    - sed
    - cp
---
# Salmon Quant

## Description
The SALMON_QUANT module quantifies transcript and gene expression from single-end or paired-end RNA-seq reads using Salmon. It takes FASTQ files, a pre-built Salmon index, and a GTF annotation file as input. Before quantification, it verifies that each sample has either one or two read files and checks consistency with the single_end metadata flag, if present. Salmon automatically detects the library type and uses selective alignment with mapping validation to quantify expression.

The module generates a Salmon output directory containing the quantification results and auxiliary information. It emits separate transcript-level and gene-level quantification files (quant.sf and quant.genes.sf), along with metadata and library-format statistics in JSON format. If the corresponding auxiliary JSON files are unavailable, empty JSON objects are emitted as fallbacks. The Salmon version is recorded in versions.yml.

The stub implementation generates synthetic quantification files and placeholder metadata for testing without running the actual quantification.