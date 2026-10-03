include { REFERENCE_RESOLVER } from '../reference_resolver/main'

include { TRANSCRIPTOME_GENERATE } from '../../../modules/local/transcriptome_generate/main'
include { SALMON_INDEX }           from '../../../modules/local/salmon_index/main'


workflow REFERENCE_PREPARATION {

    take:
    genome
    reference_cache

    main:

    /*
     * Resolve the user-friendly genome identifier to a pinned
     * genome FASTA + GTF reference bundle.
     */
    REFERENCE_RESOLVER(
        genome,
        reference_cache
    )


    /*
     * Build the transcriptome from the matching genome and GTF.
     */
    ch_transcriptome_input = REFERENCE_RESOLVER.out.reference
        .map {
            reference,
            genome_fasta,
            gtf,
            manifest ->

            tuple(
                reference,
                genome_fasta,
                gtf
            )
        }

    TRANSCRIPTOME_GENERATE(
        ch_transcriptome_input
    )


    /*
     * SALMON_INDEX needs:
     *
     *   reference metadata
     *   transcript FASTA
     *   genome FASTA
     *
     * Key both channels by reference ID before joining so the
     * correct genome is always paired with its transcriptome.
     */
    ch_transcripts_keyed = TRANSCRIPTOME_GENERATE.out.transcript_fasta
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


    ch_salmon_index_input = ch_transcripts_keyed
        .join(
            ch_genomes_keyed,
            by: 0
        )
        .map {
            reference_id,
            reference,
            transcript_fasta,
            genome_fasta ->

            tuple(
                reference,
                transcript_fasta,
                genome_fasta
            )
        }


    SALMON_INDEX(
        ch_salmon_index_input
    )


    emit:

    reference = REFERENCE_RESOLVER.out.reference

    genome_fasta = REFERENCE_RESOLVER.out.genome_fasta

    gtf = REFERENCE_RESOLVER.out.gtf

    transcript_fasta =
        TRANSCRIPTOME_GENERATE.out.transcript_fasta

    salmon_index =
        SALMON_INDEX.out.index

    manifest =
        REFERENCE_RESOLVER.out.manifest
}