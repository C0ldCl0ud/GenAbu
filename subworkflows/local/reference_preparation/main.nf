include { REFERENCE_RESOLVER } from '../reference_resolver/main'

include { TRANSCRIPTOME_GENERATE } from '../../../modules/local/transcriptome_generate/main'
include { SALMON_INDEX }           from '../../../modules/local/salmon_index/main'


def expandCacheRoot(value) {

    return value
        .toString()
        .replaceFirst(
            /^~(?=\/|$)/,
            System.getProperty('user.home')
        )
}


def getReferenceCacheDir(cacheRoot, reference) {

    return new File(
        expandCacheRoot(cacheRoot),
        "${reference.source.toLowerCase()}/release-${reference.release}/${reference.id}-${reference.assembly}"
    )
}


def salmonIndexIsCached(indexDir) {

    if (!indexDir.isDirectory()) {
        return false
    }

    def requiredFiles = [
        new File(indexDir, 'info.json'),
        new File(indexDir, 'refseq.bin'),
        new File(indexDir, 'refseq_offsets.json')
    ]

    return requiredFiles.every {
        it.isFile() &&
        it.length() > 0
    }
}


workflow REFERENCE_PREPARATION {

    take:
    genome
    reference_cache

    main:

    /*
     * Resolve/download the pinned genome and GTF.
     */
    REFERENCE_RESOLVER(
        genome,
        reference_cache
    )


    /*
     * -------------------------------------------------------------------------
     * Transcriptome cache
     * -------------------------------------------------------------------------
     */

    ch_transcript_state = REFERENCE_RESOLVER.out.reference
        .combine(reference_cache)
        .map {
            reference,
            genome_fasta,
            gtf,
            manifest,
            gene_names,
            cache_root ->

            def cache_dir = getReferenceCacheDir(
                cache_root,
                reference
            )

            def transcript_file = new File(
                cache_dir,
                'transcripts.fa.gz'
            )

            def cached =
                transcript_file.isFile() &&
                transcript_file.length() > 0

            log.info(
                cached
                    ? "Transcriptome cache hit: ${transcript_file}"
                    : "Transcriptome cache miss: ${transcript_file}"
            )

            tuple(
                reference,
                genome_fasta,
                gtf,
                cache_dir.canonicalPath,
                transcript_file.canonicalPath,
                cached
            )
        }


    /*
     * Cached transcriptomes bypass GffRead.
     */
    ch_transcript_cached = ch_transcript_state
        .filter {
            reference,
            genome_fasta,
            gtf,
            cache_dir,
            transcript_path,
            cached ->

            cached
        }
        .map {
            reference,
            genome_fasta,
            gtf,
            cache_dir,
            transcript_path,
            cached ->

            tuple(
                reference,
                file(transcript_path)
            )
        }


    /*
     * Missing transcriptomes are generated and published into the
     * persistent reference cache.
     */
    ch_transcript_missing = ch_transcript_state
        .filter {
            reference,
            genome_fasta,
            gtf,
            cache_dir,
            transcript_path,
            cached ->

            !cached
        }
        .map {
            reference,
            genome_fasta,
            gtf,
            cache_dir,
            transcript_path,
            cached ->

            tuple(
                reference,
                genome_fasta,
                gtf,
                cache_dir
            )
        }


    TRANSCRIPTOME_GENERATE(
        ch_transcript_missing
    )


    ch_transcripts = ch_transcript_cached
        .mix(
            TRANSCRIPTOME_GENERATE.out.transcript_fasta
        )


    /*
     * -------------------------------------------------------------------------
     * Salmon index cache
     * -------------------------------------------------------------------------
     */

    ch_transcripts_keyed = ch_transcripts
        .map {
            reference,
            transcript_fasta ->

            tuple(
                reference.id,
                reference,
                transcript_fasta
            )
        }


    ch_genomes_keyed = REFERENCE_RESOLVER.out.genome_fasta
        .map {
            reference,
            genome_fasta ->

            tuple(
                reference.id,
                genome_fasta
            )
        }


    ch_salmon_base = ch_transcripts_keyed
        .join(
            ch_genomes_keyed,
            by: 0
        )


    ch_salmon_state = ch_salmon_base
        .combine(reference_cache)
        .map {
            reference_id,
            reference,
            transcript_fasta,
            genome_fasta,
            cache_root ->

            def reference_cache_dir =
                getReferenceCacheDir(
                    cache_root,
                    reference
                )

            def salmon_cache_dir = new File(
                reference_cache_dir,
                'salmon-2.7.0-k31'
            )

            def index_dir = new File(
                salmon_cache_dir,
                'salmon_index'
            )

            def cached =
                salmonIndexIsCached(
                    index_dir
                )

            log.info(
                cached
                    ? "Salmon index cache hit: ${index_dir}"
                    : "Salmon index cache miss: ${index_dir}"
            )

            tuple(
                reference,
                transcript_fasta,
                genome_fasta,
                salmon_cache_dir.canonicalPath,
                index_dir.canonicalPath,
                cached
            )
        }


    /*
     * Cached indexes bypass SALMON_INDEX.
     */
    ch_salmon_cached = ch_salmon_state
        .filter {
            reference,
            transcript_fasta,
            genome_fasta,
            salmon_cache_dir,
            index_path,
            cached ->

            cached
        }
        .map {
            reference,
            transcript_fasta,
            genome_fasta,
            salmon_cache_dir,
            index_path,
            cached ->

            tuple(
                reference,
                file(index_path)
            )
        }


    /*
     * Missing indexes are built and persisted.
     */
    ch_salmon_missing = ch_salmon_state
        .filter {
            reference,
            transcript_fasta,
            genome_fasta,
            salmon_cache_dir,
            index_path,
            cached ->

            !cached
        }
        .map {
            reference,
            transcript_fasta,
            genome_fasta,
            salmon_cache_dir,
            index_path,
            cached ->

            tuple(
                reference,
                transcript_fasta,
                genome_fasta,
                salmon_cache_dir
            )
        }


    SALMON_INDEX(
        ch_salmon_missing
    )


    ch_salmon_index = ch_salmon_cached
        .mix(
            SALMON_INDEX.out.index
        )


    /*
     * Public REFERENCE_PREPARATION interface.
     */
    emit:

    reference =
        REFERENCE_RESOLVER.out.reference

    genome_fasta =
        REFERENCE_RESOLVER.out.genome_fasta

    gtf =
        REFERENCE_RESOLVER.out.gtf
            .map {
                reference,
                gtf ->
                gtf
            }
    
    gene_names =
        REFERENCE_RESOLVER.out.gene_names
        .map {
            reference,
            gene_names ->
            gene_names
        }

    transcript_fasta =
        ch_transcripts

    salmon_index =
        ch_salmon_index

    manifest =
        REFERENCE_RESOLVER.out.manifest
}