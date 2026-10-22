---
type: process
input:
    - genome
    - reference_cache
output:
    - reference
    - genome_fasta
    - gtf
    - transcript_fasta
    - salmon_index
    - manifest
    - versions
image:
parent:
child:
    - REFERENCE_RESOLVER
    - TRANSCRIPTOME_GENERATE
    - SALMON_INDEX
tools:
    - Salmon
    - GffRead
---
# Reference Preparation

## Description
The Reference Preparation subworkflow resolves and prepares the reference files required for downstream quantification. It retrieves the genome FASTA file and corresponding GTF annotation through REFERENCE_RESOLVER, using pinned reference information to ensure consistent and reproducible reference selection.

The subworkflow generates a transcript FASTA file from the genome and GTF annotation when no usable cached transcriptome is available. Similarly, it builds a Salmon index when a compatible index is not already present in the reference cache. Existing cached files are reused to avoid unnecessary processing and reduce execution time. The Salmon index cache is version-specific to account for changes in the Salmon version and indexing parameters.

The subworkflow emits the reference metadata, genome FASTA, GTF annotation, transcript FASTA, Salmon index, and manifest. Software version information from the reference resolution, transcriptome generation, and index generation steps is combined to support reproducibility.
