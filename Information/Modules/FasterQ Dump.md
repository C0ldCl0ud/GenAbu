---
type: module
input:
    - meta, accession, sra_dir
output:
    - reads
image:
    - quay.io/biocontainers/sra-tools:3.2.1--h4304569_1
parent:
    - SRA_INPUT
child:
tools:
    - fasterq-dump
    - gzip
---
# FasterQ Dump

## Description
The FASTERQ_DUMP module converts downloaded SRA data into FASTQ files using fasterq-dump from the SRA Toolkit. It uses the available CPUs for parallel processing and splits paired-end reads into separate files. The resulting FASTQ files are compressed with gzip and emitted as the reads output channel, together with the sample metadata.

The module uses the accession identifier to name the output files. For paired-end data, the files are named with _1 and _2 suffixes, while single-end data produces a single FASTQ file. The stub implementation creates placeholder output files for testing without running the actual conversion.