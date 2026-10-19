include { GTF_PREPARE } from '../../../modules/local/gtf_prepare/main'
include { SALMON_QUANT } from '../../../modules/local/salmon_quant/main'


workflow QUANTIFICATION {

    take:
    reads
    salmon_index
    gtf

    main:

    /*
     * Match the Salmon index and GTF belonging to the same
     * reference before attaching that reference to every sample.
     */
    ch_index_keyed = salmon_index
        .map {
            reference,
            index ->

            tuple(
                reference.id,
                reference,
                index
            )
        }


    GTF_PREPARE(gtf)

    ch_gtf_keyed = GTF_PREPARE.out.gtf
        .map {
            reference,
            gtf_file ->

            tuple(
                reference.id,
                gtf_file
            )
        }


    ch_reference = ch_index_keyed
        .join(
            ch_gtf_keyed,
            by: 0
        )
        .map {
            reference_id,
            reference,
            index,
            gtf_file ->

            tuple(
                reference,
                index,
                gtf_file
            )
        }


    ch_quant_input = reads
        .combine(
            ch_reference
        )
        .map {
            meta,
            sample_reads,
            reference,
            index,
            gtf_file ->

            tuple(
                meta,
                sample_reads,
                index,
                gtf_file
            )
        }


    SALMON_QUANT(
        ch_quant_input
    )


    emit:

    results =
        SALMON_QUANT.out.results

    transcript_quant =
        SALMON_QUANT.out.transcript_quant

    gene_quant =
        SALMON_QUANT.out.gene_quant

    meta_info =
        SALMON_QUANT.out.meta_info

    lib_format_counts =
        SALMON_QUANT.out.lib_format_counts

    versions =
        SALMON_QUANT.out.versions
}