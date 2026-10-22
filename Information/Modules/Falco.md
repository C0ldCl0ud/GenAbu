---
type: module
input:
    - meta, reads
output:
    - data
    - html
    - summary
image:
    - quay.io/biocontainers/falco:2.0.2--h3be2455_0
parent:
child:
tools:
    - Falco
---
# Falco

## Description
The Falco module performs quality control on raw or trimmed FASTQ sequencing reads. It generates per-read quality control reports containing detailed sequencing metrics, an HTML report for visual inspection, and a summary file indicating the status of individual quality control checks. Both single-end and paired-end sequencing data are supported.

Before execution, the module verifies that each sample contains either one or two FASTQ files and checks consistency with the single_end metadata flag, if present. An input mismatch causes the process to terminate with an error. For paired-end samples, separate reports are generated for the forward and reverse reads, with filenames identifying the corresponding read direction. The resulting reports can be used to assess sequencing quality and identify potential issues before or after read trimming.
