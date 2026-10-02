https://github.com/databricks-industry-solutions/dbrna/blob/main/TEST_DATA.md

# GenAbu Pipeline: Public Test Datasets

This document catalogs publicly available RNA-seq datasets suitable for testing and validating this pipeline.
The pipeline processes **paired-end**  and **single-end** fastq files.

---

## Quick Reference: Recommended by Use Case

| Use Case                     | Dataset                    | Size                   | Download                                                       |
| ---------------------------- | -------------------------- | ---------------------- | -------------------------------------------------------------- |
| Unit/CI testing (minutes)    | nf-core subsampled yeast   | 2–5 MB/pair            | [GitHub](#1-nf-core-rnaseq-test-datasets)                      |


---

## 1. nf-core/rnaseq Test Datasets

These datasets are maintained by the nf-core community specifically for pipeline CI/CD testing.
The subsampled versions are ideal for fast local testing and automated pipelines.

### 1a. Minimal Test — *S. cerevisiae* (GSE110004)

- **Organism:** *Saccharomyces cerevisiae*
- **GEO:** https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE110004
- **Library type:** Paired-end, 101 bp, strand-specific (total RNA-seq)
- **Description:** Wild-type vs. Rap1-AID degron mutant, 3 replicates per condition
- **File size:** 2–5 MB per pair (pre-subsampled to ~50,000 reads)
- **Why useful:** Yeast genome is tiny (~12 Mb), making alignment very fast. Default dataset for `nf-core run -profile test`.

**Pre-subsampled test files (direct download from nf-core/test-datasets):**
```
https://github.com/nf-core/test-datasets/raw/rnaseq/testdata/GSE110004/SRR6357070_1.fastq.gz
https://github.com/nf-core/test-datasets/raw/rnaseq/testdata/GSE110004/SRR6357070_2.fastq.gz
```

**Full SRA accessions (original, ~50–68M reads each):**

| SRA Accession | Condition | Replicate |
|---|---|---|
| SRR6357070 | Wild-type | 1 |
| SRR6357071 | Wild-type | 2 |
| SRR6357072 | Wild-type | 3 |
| SRR6357073 | Rap1-AID, no induction | 1 |
| SRR6357074 | Rap1-AID, no induction | 2 |
| SRR6357075 | Rap1-AID, no induction | 3 |
| SRR6357076 | Rap1-AID, 30-min induction | 1 |
| SRR6357077 | Rap1-AID, 30-min induction | 2 |
| SRR6357078 | Rap1-AID, 30-min induction | 3 |

**SRA download:**
```bash
# Using SRA Toolkit
fasterq-dump --split-files SRR6357070

# Or via Entrez
efetch -db sra -id SRR6357070 -format runinfo
```

**Reference:** Wu et al. (2018). *Repression of Divergent Noncoding Transcription by a Sequence-Specific Transcription Factor.* Mol Cell 72(6):942–954. https://doi.org/10.1016/j.molcel.2018.09.033
