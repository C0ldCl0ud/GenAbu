---
type: module
input:
    - meta, accession
output:
    - sra
image:
    - quay.io/biocontainers/sra-tools:3.2.1--h4304569_1
parent:
    - SRA_INPUT
child:
tools:
    - prefetch
---
# SRA Prefetch

## Description
The SRA_PREFETCH module downloads sequencing data for a specified SRA accession using prefetch from the NCBI SRA Toolkit. It takes the sample metadata and accession identifier as input and stores the retrieved data in an accession-specific directory.

The module emits the sample metadata, accession identifier, and downloaded directory for downstream processing, such as conversion to FASTQ files. The stub implementation creates a placeholder directory and .sra file for testing without downloading actual sequencing data.