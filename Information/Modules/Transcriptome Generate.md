---
type: module
input:
    - reference, genome_fasta, gtf, transcript_cache_dir
output:
    - transcript_fasta
    - versions
image:
    - quay.io/biocontainers/gffread:0.12.7--hdcf5f25_4
parent:
    - REFERENCE_PREPARATION
child:
tools:
    - gffread
    - gunzip
    - gzip
---
# Transcriptome Generation

## Description
The TRANSCRIPTOME_GENERATE module generates a transcriptome FASTA file from a reference genome FASTA and its corresponding GTF annotation using gffread. Compressed input files are decompressed, while uncompressed files are copied into the working directory. The module uses the genome sequence and gene annotations to extract transcript sequences.

The generated transcriptome is compressed into transcripts.fa.gz. The module checks that the uncompressed and compressed files are non-empty and validates the compressed file with gzip -t. The resulting transcriptome is emitted together with the reference metadata and published to the specified persistent cache directory. The gffread version is recorded in versions.yml.

The stub implementation creates a small synthetic transcriptome FASTA file and placeholder version information for testing without generating transcript sequences from the actual reference.