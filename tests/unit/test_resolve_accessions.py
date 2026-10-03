import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


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

    def test_writes_a_reusable_samplesheet_with_unique_run_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "samplesheet.csv"

            RESOLVER.write_samplesheet(
                path,
                [
                    ena_row("SRR1", "SRS1"),
                    ena_row("SRR2", "SRS1"),
                ],
            )

            self.assertEqual(
                path.read_text(encoding="utf-8").splitlines(),
                [
                    "sample,accession",
                    "SRR1,SRR1",
                    "SRR2,SRR2",
                ],
            )

    def test_max_runs_defaults_to_20(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)

            resolved_path = directory / "resolved.tsv"
            unresolved_path = directory / "unresolved.tsv"
            samplesheet_path = directory / "samplesheet.csv"

            resolved_rows = [
                ena_row(f"SRR{i:03d}")
                for i in range(1, 26)
            ]

            argv = [
                "resolve_accessions.py",
                "--input",
                str(directory / "input.tsv"),
                "--resolved",
                str(resolved_path),
                "--unresolved",
                str(unresolved_path),
                "--samplesheet",
                str(samplesheet_path),
            ]

            with (
                mock.patch("sys.argv", argv),
                mock.patch.object(
                    RESOLVER,
                    "read_accessions",
                    return_value=[accession_record("SRP1")],
                ),
                mock.patch.object(
                    RESOLVER,
                    "resolve_records",
                    return_value=(resolved_rows, []),
                ),
            ):
                exit_code = RESOLVER.main()

            self.assertEqual(exit_code, 0)

            resolved_lines = resolved_path.read_text(
                encoding="utf-8"
            ).splitlines()

            samplesheet_lines = samplesheet_path.read_text(
                encoding="utf-8"
            ).splitlines()

            # Header + 20 runs.
            self.assertEqual(len(resolved_lines), 21)
            self.assertEqual(len(samplesheet_lines), 21)

            self.assertIn("SRR020", resolved_lines[-1])
            self.assertNotIn(
                "SRR021",
                resolved_path.read_text(encoding="utf-8"),
            )

            self.assertEqual(
                samplesheet_lines[-1],
                "SRR020,SRR020",
            )

    def test_max_runs_limits_resolved_runs_and_samplesheet(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)

            resolved_path = directory / "resolved.tsv"
            unresolved_path = directory / "unresolved.tsv"
            samplesheet_path = directory / "samplesheet.csv"

            resolved_rows = [
                ena_row("SRR001"),
                ena_row("SRR002"),
                ena_row("SRR003"),
            ]

            argv = [
                "resolve_accessions.py",
                "--input",
                str(directory / "input.tsv"),
                "--resolved",
                str(resolved_path),
                "--unresolved",
                str(unresolved_path),
                "--samplesheet",
                str(samplesheet_path),
                "--max-runs",
                "2",
            ]

            with (
                mock.patch("sys.argv", argv),
                mock.patch.object(
                    RESOLVER,
                    "read_accessions",
                    return_value=[accession_record("SRP1")],
                ),
                mock.patch.object(
                    RESOLVER,
                    "resolve_records",
                    return_value=(resolved_rows, []),
                ),
            ):
                exit_code = RESOLVER.main()

            self.assertEqual(exit_code, 0)

            resolved_lines = resolved_path.read_text(
                encoding="utf-8"
            ).splitlines()

            self.assertEqual(len(resolved_lines), 3)
            self.assertIn("SRR001", resolved_lines[1])
            self.assertIn("SRR002", resolved_lines[2])

            self.assertNotIn(
                "SRR003",
                resolved_path.read_text(encoding="utf-8"),
            )

            self.assertEqual(
                samplesheet_path.read_text(
                    encoding="utf-8"
                ).splitlines(),
                [
                    "sample,accession",
                    "SRR001,SRR001",
                    "SRR002,SRR002",
                ],
            )

    def test_max_runs_must_be_at_least_one(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)

            argv = [
                "resolve_accessions.py",
                "--input",
                str(directory / "input.tsv"),
                "--resolved",
                str(directory / "resolved.tsv"),
                "--unresolved",
                str(directory / "unresolved.tsv"),
                "--samplesheet",
                str(directory / "samplesheet.csv"),
                "--max-runs",
                "0",
            ]

            with (
                mock.patch("sys.argv", argv),
                mock.patch.object(
                    RESOLVER,
                    "read_accessions",
                ) as read_accessions,
            ):
                exit_code = RESOLVER.main()

            self.assertEqual(exit_code, 1)

            # Invalid configuration should fail before any resolution work.
            read_accessions.assert_not_called()

if __name__ == "__main__":
    unittest.main()
