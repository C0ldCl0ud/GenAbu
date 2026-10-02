include { SRA_PREFETCH } from '../../../modules/local/sra_prefetch/main'
include { FASTERQ_DUMP } from '../../../modules/local/fasterq_dump/main'


workflow SRA_INPUT {

    take:
    sra_input

    main:

    SRA_PREFETCH(sra_input)

    FASTERQ_DUMP(SRA_PREFETCH.out.sra)

    ch_reads = FASTERQ_DUMP.out.reads.map { meta, reads ->

        def read_list = reads instanceof List ? reads : [reads]

        if (!(read_list.size() in [1, 2])) {
            error "Expected 1 or 2 FASTQ files for ${meta.id}, found ${read_list.size()}"
        }

        tuple(
            meta + [single_end: read_list.size() == 1],
            read_list
        )
    }

    emit:
    reads = ch_reads
}