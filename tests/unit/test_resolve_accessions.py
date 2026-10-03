import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "bin" / "resolve_accessions.py"
SPEC = importlib.util.spec_from_file_location("resolve_accessions", SCRIPT)
RESOLVER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(RESOLVER)


def accession_record(accession, accession_type="study"):
    return {
        "accession": accession,
        "repository": "test",
        "accession_type": accession_type,
        "source_file": "paper.txt",
    }


def ena_row(run_accession, sample_accession="SRS1"):
    row = {field: "" for field in RESOLVER.ENA_FIELDS}
    row.update(
        {
            "study_accession": "SRP1",
            "sample_accession": sample_accession,
            "experiment_accession": "SRX1",
            "run_accession": run_accession,
            "scientific_name": "Homo sapiens",
            "library_strategy": "RNA-Seq",
            "library_layout": "PAIRED",
        }
    )
    return row


class ResolveAccessionsTests(unittest.TestCase):

    def test_direct_study_uses_ena(self):
        calls = []

        def ena_fetcher(accession):
            calls.append(accession)
            return [ena_row("SRR1")]

        resolved, unresolved = RESOLVER.resolve_records(
            [accession_record("SRP1")],
            ena_fetcher=ena_fetcher,
            ffq_fetcher=lambda accession: self.fail("ffq should not be called"),
        )

        self.assertEqual(calls, ["SRP1"])
        self.assertEqual(unresolved, [])
        self.assertEqual(resolved[0]["run_accession"], "SRR1")
        self.assertEqual(resolved[0]["sample_accession"], "SRS1")
        self.assertEqual(resolved[0]["resolution_source"], "ena")

    def test_geo_series_uses_ffq_then_ena(self):
        rows = {
            "SRR1": [ena_row("SRR1", "SRS1")],
            "SRR2": [ena_row("SRR2", "SRS2")],
            "GSE1": [],
        }

        resolved, unresolved = RESOLVER.resolve_records(
            [accession_record("GSE1", "series")],
            ena_fetcher=lambda accession: rows[accession],
            ffq_fetcher=lambda accession: ["SRR1", "SRR2"],
        )

        self.assertEqual(unresolved, [])
        self.assertEqual(
            [row["run_accession"] for row in resolved],
            ["SRR1", "SRR2"],
        )
        self.assertTrue(
            all(row["resolution_source"] == "ffq+ena" for row in resolved)
        )

    def test_duplicate_runs_are_merged(self):
        def ena_fetcher(accession):
            if accession in {"SRP1", "SRR1"}:
                return [ena_row("SRR1")]
            return []

        resolved, unresolved = RESOLVER.resolve_records(
            [
                accession_record("GSE1", "series"),
                accession_record("SRP1"),
            ],
            ena_fetcher=ena_fetcher,
            ffq_fetcher=lambda accession: ["SRR1"],
        )

        self.assertEqual(unresolved, [])
        self.assertEqual(len(resolved), 1)
        self.assertEqual(resolved[0]["source_accession"], "GSE1;SRP1")
        self.assertEqual(resolved[0]["run_accession"], "SRR1")

    def test_unresolved_accession_is_reported(self):
        def ffq_failure(accession):
            raise RESOLVER.ResolutionError("mock ffq failure")

        resolved, unresolved = RESOLVER.resolve_records(
            [accession_record("SRP999")],
            ena_fetcher=lambda accession: [],
            ffq_fetcher=ffq_failure,
        )

        self.assertEqual(resolved, [])
        self.assertEqual(unresolved[0]["accession"], "SRP999")
        self.assertIn("mock ffq failure", unresolved[0]["reason"])

    def test_ffq_output_is_reduced_to_unique_run_accessions(self):
        completed = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=(
                '[{"accession":"SRR2"},'
                '{"nested":{"accession":"SRR1"}},'
                '{"accession":"SRR2"}]'
            ),
            stderr="",
        )

        runs = RESOLVER.fetch_ffq_runs(
            "GSE1",
            runner=lambda *args, **kwargs: completed,
        )

        self.assertEqual(runs, ["SRR1", "SRR2"])

    def test_accession_table_requires_expected_columns(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.tsv"
            path.write_text("accession\nSRP1\n", encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "must contain"):
                RESOLVER.read_accessions(path)


if __name__ == "__main__":
    unittest.main()
