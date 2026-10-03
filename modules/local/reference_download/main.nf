process REFERENCE_DOWNLOAD {

    tag "${reference.id} (${reference.source} ${reference.release})"
    label 'process_download'

    /*
     * Same pinned wget container currently used by nf-core/modules.
     * Unlike curlimages/curl, this works with Nextflow's normal Bash
     * process execution.
     */
    container 'community.wave.seqera.io/library/wget:1.21.4--8b0fcde81c17be5e'

    /*
     * Persist the downloaded reference outside the Nextflow work
     * directory so later GenAbu runs can reuse it.
     */
    publishDir {
        "${reference_cache}/${reference.source.toLowerCase()}/release-${reference.release}/${reference.id}-${reference.assembly}"
    },
        mode: 'copy',
        overwrite: false

    input:
    tuple val(reference), val(reference_cache)

    output:
    tuple val(reference),
          path("genome.fa.gz"),
          path("genes.gtf.gz"),
          path("reference.yml"),
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

    test -s genome.fa.gz
    test -s genes.gtf.gz

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
EOF

    printf '"%s":\\n    wget: "%s"\\n' \
        "${task.process}" \
        "\$(wget --version | head -1 | awk '{print \$3}')" \
        > versions.yml
    """

    stub:
    """
    printf 'stub genome\\n' > genome.fa.gz
    printf 'stub gtf\\n' > genes.gtf.gz

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
    EOF

    printf '"%s":\\n    wget: "1.21.4"\\n' \
        "${task.process}" \
        > versions.yml
    """
}