include { SALMON_INDEX } from '../../../modules/local/salmon_index/main'
include { SALMON_QUANT } from '../../../modules/local/salmon_quant/main'


workflow SALMON_QUANT_INTEGRATION {

    take:
    transcript_fasta
    genome_fasta
    gtf
    reads
    salmon_cache

    main:

    /*
     * Synthetic reference metadata.
     */
    reference = [
        id: 'synthetic',
        species: 'Synthetic test',
        assembly: 'test1',
        source: 'GenAbu',
        release: 1
    ]


    /*
     * -------------------------------------------------------------------------
     * Build a real Salmon index.
     * -------------------------------------------------------------------------
     */

    ch_index_input = transcript_fasta
        .combine(
            genome_fasta
        )
        .combine(
            salmon_cache
        )
        .map {
            transcript_file,
            genome_file,
            cache_dir ->

            tuple(
                reference,
                transcript_file,
                genome_file,
                cache_dir
            )
        }


    SALMON_INDEX(
        ch_index_input
    )


    /*
     * -------------------------------------------------------------------------
     * Construct sample read metadata.
     * -------------------------------------------------------------------------
     */

    ch_reads = reads
        .map { read_file ->

            tuple(
                [
                    id: 'sample1',
                    single_end: true
                ],
                [
                    read_file
                ]
            )
        }


    /*
     * -------------------------------------------------------------------------
     * Combine reads, index, and GTF into the SALMON_QUANT contract:
     *
     *   tuple(
     *       meta,
     *       reads,
     *       salmon_index,
     *       gtf
     *   )
     * -------------------------------------------------------------------------
     */

    ch_quant_input = ch_reads
        .combine(
            SALMON_INDEX.out.index
        )
        .combine(
            gtf
        )
        .map {
            meta,
            sample_reads,
            reference_meta,
            salmon_index,
            gtf_file ->

            tuple(
                meta,
                sample_reads,
                salmon_index,
                gtf_file
            )
        }


    SALMON_QUANT(
        ch_quant_input
    )


    emit:

    index =
        SALMON_INDEX.out.index

    results =
        SALMON_QUANT.out.results

    transcript_quant =
        SALMON_QUANT.out.transcript_quant

    gene_quant =
        SALMON_QUANT.out.gene_quant
}