---
type: process
input:
    - sra_input
output:
    - reads
image:
parent:
child:
    - SRA_PREFETCH
    - FASTERQ_DUMP
tools:
    - SRA Toolkit
---
# SRA Input

## Description
The SRA Input subworkflow retrieves sequencing data from the Sequence Read Archive (SRA) using the provided accession information. It first uses SRA_PREFETCH to download the corresponding SRA data and then passes the downloaded files to FASTERQ_DUMP for conversion into FASTQ files.

After conversion, the subworkflow validates the number of FASTQ files generated for each sample, allowing either one file for single-end sequencing or two files for paired-end sequencing. An error is raised if the number of files does not match either of these expected configurations. The output metadata is updated with a single_end flag, allowing downstream processes to distinguish between single-end and paired-end samples. The resulting reads are emitted in a consistent structure for downstream processing.
