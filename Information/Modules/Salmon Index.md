---
type: module
input:
    - reference, transcript_fasta, genome_fasta, salmon_cache_dir
output:
    - index
    - versions
image:
    - community.wave.seqera.io/library/salmon:2.7.0--74784226202c61b9
parent:
    - REFERENCE_PREPARATION
child:
tools:
    - Salmon
    - gunzip
    - grep
    - sed
    - cut
    - cat
---
# SALMON_INDEX

## Description
The SALMON_INDEX module builds a Salmon index for transcript quantification using the transcript FASTA and genome FASTA files associated with a reference genome. Compressed FASTA inputs are decompressed, while uncompressed files are copied into the working directory. The module validates the input files before combining the transcript and genome sequences into a gentrome FASTA file.

To support decoy-aware indexing, chromosome or contig identifiers are extracted from the genome FASTA headers and written to decoys.txt. Salmon then builds the index using the combined gentrome FASTA, the decoy list, a k-mer length of 31, and the available CPUs.

The module checks that the index directory and selected index files exist, then emits the index together with its reference metadata. The index is published to the specified persistent cache directory, and the Salmon version is recorded in versions.yml. During stub execution, placeholder index files are generated for workflow testing without running Salmon.