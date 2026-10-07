include { samplesheetToList } from 'plugin/nf-schema'

include { REFERENCE_DOWNLOAD } from '../../../modules/local/reference_download/main'


def normalizeReferenceKey(value) {

    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(/[^a-z0-9]+/, '_')
        .replaceAll(/^_+|_+$/, '')
}


def resolveReference(catalog, requestedGenome) {

    def query = normalizeReferenceKey(requestedGenome)

    def matches = catalog.findAll { row ->

        def id                 = row[0]
        def species            = row[1]
        def assembly           = row[2]
        def assembly_version   = row[3]
        def aliases            = row[7] ?: []

        def candidates = [
            id,
            species,
            assembly,
            assembly_version
        ] + aliases

        candidates.any {
            normalizeReferenceKey(it) == query
        }
    }

    if (matches.isEmpty()) {

        def supported = catalog.collect { row ->
            "${row[0]} (${row[1]}, ${row[2]})"
        }.join(', ')

        error """
        Unknown reference genome: '${requestedGenome}'

        Supported references:
          ${supported}

        Examples:
          --genome human
          --genome "Homo sapiens"
          --genome mouse
          --genome "Mus musculus"
        """
    }

    if (matches.size() > 1) {
        error """
        Reference genome '${requestedGenome}' is ambiguous.

        Matching catalogue entries:
          ${matches.collect { it[0] }.join(', ')}
        """
    }

    def row = matches.first()

    return [
        id                : row[0],
        species           : row[1],
        assembly          : row[2],
        assembly_version  : row[3],
        assembly_accession: row[4],
        source            : row[5],
        release           : row[6],
        aliases           : row[7],
        genome_url        : row[8],
        gtf_url           : row[9],
        gene_name_url     : row[10]
    ]
}


workflow REFERENCE_RESOLVER {

    take:
    genome
    reference_cache

    main:

    /*
     * references.yml is a pinned catalogue distributed with GenAbu.
     */
    def reference_catalog = samplesheetToList(
        "${projectDir}/assets/references.yml",
        "${projectDir}/assets/schema_references.json"
    )


    /*
     * Resolve the user-friendly genome name and determine whether
     * all required files already exist in the persistent cache.
     */
    ch_reference_state = genome
        .combine(reference_cache)
        .map { requested_genome, cache_value ->

            def reference = resolveReference(
                reference_catalog,
                requested_genome
            )

            /*
             * Expand a leading ~ if the user supplied one.
             */
            def cache_root = cache_value
                .toString()
                .replaceFirst(
                    /^~(?=\/|$)/,
                    System.getProperty('user.home')
                )

            def cache_dir = new File(
                cache_root,
                "${reference.source.toLowerCase()}/release-${reference.release}/${reference.id}-${reference.assembly}"
            )

            def genome_file = new File(
                cache_dir,
                'genome.fa.gz'
            )

            def gtf_file = new File(
                cache_dir,
                'genes.gtf.gz'
            )

            def manifest_file = new File(
                cache_dir,
                'reference.yml'
            )

            def gene_names_file = new File(
                cache_dir,
                "gene_names.gene_info.gz"
            )

            def cached =
                genome_file.isFile() &&
                genome_file.length() > 0 &&
                gtf_file.isFile() &&
                gtf_file.length() > 0 &&
                manifest_file.isFile() &&
                manifest_file.length() > 0 &&
                gene_names_file.isFile() &&
                gene_names_file.length() > 0

            log.info(
                "Reference '${requested_genome}' resolved to " +
                "${reference.species} ${reference.assembly} " +
                "(${reference.source} release ${reference.release})"
            )

            log.info(
                cached
                    ? "Reference cache hit: ${cache_dir}"
                    : "Reference cache miss: ${cache_dir}"
            )

            tuple(
                reference,
                cache_root,
                cached,
                genome_file.canonicalPath,
                gtf_file.canonicalPath,
                manifest_file.canonicalPath,
                gene_names_file.canonicalPath
            )
        }


    /*
     * Cached references bypass the download process entirely.
     */
    ch_cached = ch_reference_state
        .filter {
            reference,
            cache_root,
            cached,
            genome_path,
            gtf_path,
            manifest_path,
            gene_names_path ->

            cached
        }
        .map {
            reference,
            cache_root,
            cached,
            genome_path,
            gtf_path,
            manifest_path,
            gene_names_path ->

            tuple(
                reference,
                file(genome_path),
                file(gtf_path),
                file(manifest_path),
                file(gene_names_path)
            )
        }


    /*
     * Cache misses are downloaded once and published into the
     * persistent reference cache.
     */
    ch_missing = ch_reference_state
        .filter {
            reference,
            cache_root,
            cached,
            genome_path,
            gtf_path,
            manifest_path,
            gene_names_path ->

            !cached
        }
        .map {
            reference,
            cache_root,
            cached,
            genome_path,
            gtf_path,
            manifest_path,
            gene_names_path ->

            tuple(
                reference,
                cache_root
            )
        }


    REFERENCE_DOWNLOAD(ch_missing)


    /*
     * Downstream processes see exactly the same channel structure
     * whether the reference came from cache or was freshly downloaded.
     */
    ch_resolved = ch_cached
        .mix(REFERENCE_DOWNLOAD.out.reference_files)


    ch_genome = ch_resolved.map {
        reference,
        genome_fasta,
        gtf,
        manifest,
        gene_names ->

        tuple(
            reference,
            genome_fasta
        )
    }


    ch_gtf = ch_resolved.map {
        reference,
        genome_fasta,
        gtf,
        manifest,
        gene_names ->

        tuple(
            reference,
            gtf
        )
    }

    ch_gene_names = ch_resolved.map {
        reference,
        genome_fasta,
        gtf,
        manifest,
        gene_names ->

        tuple(
            reference,
            gene_names
        )
    }


    ch_manifest = ch_resolved.map {
        reference,
        genome_fasta,
        gtf,
        manifest,
        gene_names ->

        tuple(
            reference,
            manifest
        )
    }


    emit:
    reference     = ch_resolved
    genome_fasta  = ch_genome
    gtf           = ch_gtf
    gene_names    = ch_gene_names
    manifest      = ch_manifest
}