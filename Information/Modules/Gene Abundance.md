---
type: module
input:
    - gene_quant_files
    - gtf
output:
    - counts
    - abundance
    - versions
image:
    - python:3.13.7-bookworm
parent:
child:
tools:
    - Python 3.13
    - gene_abundance.py
---
# Gene Abundance

## Description
The GENE_ABUNDANCE module generates gene-level count and abundance matrices from quantification files produced by Salmon, using gene annotations provided in a GTF file. It invokes the gene_abundance.py script to aggregate the input quantification data across samples.

The module produces two tab-separated output files: gene_counts.tsv, containing gene-level counts and gene_abundance.tsv, containing gene-level abundance values. Both files are checked to ensure they exist and are non-empty. The outputs are published to the results directory. A versions.yml file records the Python version used during execution.