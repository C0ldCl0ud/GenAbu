---
type: process
input:
    - genome
    - reference_cache
output:
    - reference
    - genome_fasta
    - gtf
    - manifest
    - versions
image:
parent:
    - Reference Preparation
child:
    - REFERENCE_DOWNLOAD
tools:
    - nf-schema
---
# Reference Resolver

## Description
The Reference Resolver identifies the requested reference genome using a pinned reference catalogue distributed with GenAbu. It supports user-friendly names, species names, assembly identifiers, and predefined aliases. The requested genome is matched against the catalogue, and the workflow terminates with a descriptive error if the reference is unknown or ambiguous.

After resolving the reference, the subworkflow checks whether the genome FASTA, GTF annotation, and reference manifest are already available and usable in the persistent reference cache. If all required files are present, they are reused without downloading the reference again. Otherwise, the reference files are retrieved through REFERENCE_DOWNLOAD and stored in the cache.

The subworkflow emits the resolved reference metadata, genome FASTA, GTF annotation, and manifest in a consistent channel structure, regardless of whether the files were retrieved from the cache or downloaded during the current run. Software version information is forwarded from the download process to support reproducibility.
