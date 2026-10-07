process REFERENCE_DOWNLOAD {

    tag "${reference.id} (${reference.source} ${reference.release})"
    label 'process_download'

    /*
     * Same pinned wget container used by nf-core/modules.
     */
    container 'community.wave.seqera.io/library/wget:1.21.4--8b0fcde81c17be5e'

    /*
     * Persist downloaded references outside the Nextflow work directory.
     */
    publishDir {
        "${reference_cache}/${reference.source.toLowerCase()}/release-${reference.release}/${reference.id}-${reference.assembly}"
    },
    mode: 'copy',
    overwrite: true

    input:
    tuple val(reference), val(reference_cache)

    output:
    tuple val(reference),
          path("genome.fa.gz"),
          path("genes.gtf.gz"),
          path("reference.yml"),
          path("gene_names.gene_info.gz"),
          emit: reference_files

    path "versions.yml",
         emit: versions

    script:
    """
    wget \
        --quiet \
        --show-progress \
        --tries=5 \
        --timeout=30 \
        --retry-connrefused \
        --output-document=genome.fa.gz \
        "${reference.genome_url}"

    wget \
        --quiet \
        --show-progress \
        --tries=5 \
        --timeout=30 \
        --retry-connrefused \
        --output-document=genes.gtf.gz \
        "${reference.gtf_url}"
    
    wget \
        --quiet \
        --show-progress \
        --tries=5 \
        --timeout=30 \
        --retry-connrefused \
        --output-document=gene_names.gene_info.gz \
        "${reference.gene_name_url}"

    gzip -t genome.fa.gz
    gzip -t genes.gtf.gz
    gzip -t gene_names.gene_info.gz

    cat > reference.yml <<'EOF'
id: ${reference.id}
species: "${reference.species}"
assembly: ${reference.assembly}
assembly_version: ${reference.assembly_version}
assembly_accession: ${reference.assembly_accession}
source: ${reference.source}
release: ${reference.release}
genome_url: "${reference.genome_url}"
gtf_url: "${reference.gtf_url}"
gene_name_url: "${reference.gene_name_url}"
EOF

    printf '"%s":\\n    wget: "%s"\\n' \
        "${task.process}" \
        "\$(wget --version | head -1 | awk '{print \$3}')" \
        > versions.yml
    """

    stub:
    """
    printf '>chr1\\nACGTACGT\\n' \
        | gzip -c \
        > genome.fa.gz

    printf 'chr1\\tGenAbu\\tgene\\t1\\t8\\t.\\t+\\t.\\tgene_id "gene1";\\n' \
        | gzip -c \
        > genes.gtf.gz

    #printf 'chr1\\tGenAbu\\tgene\\t1\\t8\\t.\\t+\\t.\\tgene_id "gene1";\\n' \
    #    | gzip -c \
    #    > gene_names.gene_info.gz

    cat > reference.yml <<'EOF'
id: ${reference.id}
species: "${reference.species}"
assembly: ${reference.assembly}
assembly_version: ${reference.assembly_version}
assembly_accession: ${reference.assembly_accession}
source: ${reference.source}
release: ${reference.release}
genome_url: "${reference.genome_url}"
gtf_url: "${reference.gtf_url}"
gene_name_url: "${reference.gene_name_url}"
EOF

    printf '"%s":\\n    wget: "1.21.4"\\n' \
        "${task.process}" \
        > versions.yml
    """
}