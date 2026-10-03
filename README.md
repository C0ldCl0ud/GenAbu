# GenAbu
This project aims at developing a baseline bioinformatics pipeline. The Pipeline transforms RNA-sequencing data into a gene abundance table.

## Goals
- Reproducible
- Interoperable
- Tested

## Pipeline - Draft
- Start A: Download fastq-files via accession codes
- Start B: Provide fastq-files
- Run quality control (QC)
- Trim
- Align/Map to a reference genome
- Calculate Abundances

## Tools
- nf-schema
- ffq 0.3.1
- SRA Toolkit 3.4.1
- Falco 2.0.2

## Input
- Start A: samplesheet
//insert a table here
- Start B: samplesheet
//insert a table here

## Parameters
- `--resolve_only`: for PDF input, resolve accessions and stop before downloading sequencing data. Default: `false`.

## Output
- `results/samplesheet.csv`: reusable run-level SRA samplesheet generated from a paper.
- `results/paper_resolve/`: extracted paper text, accession tables, and resolver versions.
- gene_abundance.tsv
//insert a table here

- report.html

- plots
