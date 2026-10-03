include { PDF_TO_TEXT } from '../../../modules/local/pdf_to_text/main'
include { ACCESSION_EXTRACTOR } from '../../../modules/local/accession_extractor/main'
include { ACCESSION_RESOLVER } from '../../../modules/local/accession_resolver/main'


workflow PAPER_ACCESSIONS {

    take:
    paper
    max_runs

    main:
    PDF_TO_TEXT(paper)
    ACCESSION_EXTRACTOR(PDF_TO_TEXT.out.text)
    ACCESSION_RESOLVER(
        ACCESSION_EXTRACTOR.out.accessions,
        max_runs
    )

    ch_sra = ACCESSION_RESOLVER.out.resolved
        .splitCsv(header: true, sep: '\t')
        .filter { row -> row.run_accession }
        .map { row ->
            def meta = [
                id: row.run_accession,
                source_accession: row.source_accession,
                sample_accession: row.sample_accession,
                secondary_sample_accession: row.secondary_sample_accession,
                study_accession: row.study_accession,
                library_strategy: row.library_strategy,
                library_layout: row.library_layout
            ]

            tuple(meta, row.run_accession)
        }

    emit:
    text = PDF_TO_TEXT.out.text
    accessions = ACCESSION_EXTRACTOR.out.accessions
    resolved = ACCESSION_RESOLVER.out.resolved
    unresolved = ACCESSION_RESOLVER.out.unresolved
    samplesheet = ACCESSION_RESOLVER.out.samplesheet
    sra = ch_sra
}
