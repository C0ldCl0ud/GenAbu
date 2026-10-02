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
- SRA Toolkit 3.4.1
- Falco 2.0.2

## Input
- Start A: samplesheet
//insert a table here
- Start B: samplesheet
//insert a table here

## Parameters
- ...

## Output
- gene_abundance.tsv
//insert a table here

- report.html

- plots