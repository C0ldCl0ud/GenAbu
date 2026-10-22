---
type: module
input:
    - reference, gtf
output:
    - gtf
image:
    - quay.io/biocontainers/gffread:0.12.7--hdcf5f25_4
parent:
    - QUANTIFICATION
child:
tools:
    - gzip
    - cat
---
# GTF Prepare

## Description
The GTF_PREPARE module prepares a GTF annotation file for downstream quantification steps. It accepts compressed (.gz) and uncompressed GTF files, decompressing compressed files or copying uncompressed content into a standardized output file named genes.input.gtf.

The module verifies that the resulting file exists and is non-empty, then emits it together with the associated reference metadata. A stub implementation creates a minimal example GTF file for testing without processing the actual input.