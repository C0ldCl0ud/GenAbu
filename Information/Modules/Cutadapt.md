---
type: module
input:
    - meta, reads
    - adapters
    - quality_cutoff
    - minimum_length
output:
    - reads
    - report
    - log
    - versions
image:
    - quay.io/biocontainers/cutadapt:5.2--py311haab0aaa_0
parent:
child:
tools:
    - Cutadapt
---
# Cutadapt

## Description
The Cutadapt module removes adapter sequences and trims reads according to the configured quality cutoff and minimum read length. It supports both single-end and paired-end sequencing data and applies the corresponding adapter settings to each read direction when provided.

Before processing, the module checks that each sample contains either one or two FASTQ files and verifies consistency with the single_end metadata flag, if present. A mismatch causes the process to terminate with an error. Cutadapt generates compressed trimmed FASTQ files, a JSON report containing trimming statistics, and a log file for each sample. The Cutadapt software version is recorded in versions.yml to support reproducibility.

A stub implementation generates representative output files for testing without performing actual read trimming.