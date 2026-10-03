import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "bin" / "extract_accessions.py"
SPEC = importlib.util.spec_from_file_location("extract_accessions", SCRIPT)
EXTRACTOR = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(EXTRACTOR)


class ExtractAccessionsTests(unittest.TestCase):

    def test_extracts_normalizes_deduplicates_and_sorts(self):
        text = (
            "Data: srr7, GSE123, SRP2, gse123, PRJNA4, ERR8, "
            "ERP3, DRP5, PRJEB6, PRJDB9, and DRR10."
        )

        self.assertEqual(
            EXTRACTOR.extract_accessions(text),
            [
                "DRP5",
                "DRR10",
                "ERP3",
                "ERR8",
                "GSE123",
                "PRJDB9",
                "PRJEB6",
                "PRJNA4",
                "SRP2",
                "SRR7",
            ],
        )

    def test_does_not_extract_embedded_or_malformed_values(self):
        text = "GSE SRPABC XGSE123 GSE123X PRJNA PRJNA12X"

        self.assertEqual(EXTRACTOR.extract_accessions(text), [])

    def test_classifies_every_supported_accession_family(self):
        expected = {
            "GSE1": ("GEO", "series"),
            "SRP1": ("SRA", "study"),
            "ERP1": ("ENA", "study"),
            "DRP1": ("DRA", "study"),
            "SRR1": ("SRA", "run"),
            "ERR1": ("ENA", "run"),
            "DRR1": ("DRA", "run"),
            "PRJNA1": ("BioProject", "project"),
            "PRJEB1": ("BioProject", "project"),
            "PRJDB1": ("BioProject", "project"),
        }

        for accession, classification in expected.items():
            with self.subTest(accession=accession):
                self.assertEqual(EXTRACTOR.classify(accession), classification)

    def test_rejects_an_unsupported_accession_in_classification(self):
        with self.assertRaisesRegex(ValueError, "Unsupported accession"):
            EXTRACTOR.classify("ABC123")

    def test_writes_the_expected_tab_separated_table(self):
        with tempfile.TemporaryDirectory() as directory:
            directory_path = Path(directory)
            input_path = directory_path / "paper.txt"
            output_path = directory_path / "paper.accessions.tsv"
            input_path.write_text(
                "Deposited as GSE123 and SRR7.\n",
                encoding="utf-8",
            )

            EXTRACTOR.write_accessions(input_path, output_path)

            self.assertEqual(
                output_path.read_text(encoding="utf-8").splitlines(),
                [
                    "accession\trepository\taccession_type\tsource_file",
                    "GSE123\tGEO\tseries\tpaper.txt",
                    "SRR7\tSRA\trun\tpaper.txt",
                ],
            )


if __name__ == "__main__":
    unittest.main()
