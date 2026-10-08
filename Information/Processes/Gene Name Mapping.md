---
type: process
input:
    - NCBI gene information file
    - Reference GTF
    - Gene count matrix
    - Gene abundance matrix
output:
    - Gene count matrix with gene names
    - Gene abundance matrix with gene names
image: python:3.13.7-bookworm
parent: QUANTIFICATION
child: GENENAME_MAPPING_PROCESS
tools: python:3.13.7
---
# Gene Name Mapping

## Description
The Gene Name Mapping process adds gene names to the gene id in the gene count and abundance tables. It uses the NCBI gene_info file as the primary annotation source and the reference GTF as a fallback. Genes without an available mapping are retained with an empty gene name.