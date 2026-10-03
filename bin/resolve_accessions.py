#!/usr/bin/env python3
"""Resolve public study and project accessions to sequencing runs."""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Iterable
from pathlib import Path
from typing import Any


VERSION = "0.1.0"
ENA_FILE_REPORT_URL = "https://www.ebi.ac.uk/ena/portal/api/filereport"
RUN_PATTERN = re.compile(r"^(?:SRR|ERR|DRR)[0-9]+$", re.IGNORECASE)
GEO_PATTERN = re.compile(r"^GSE[0-9]+$", re.IGNORECASE)

ENA_FIELDS = [
    "study_accession",
    "secondary_study_accession",
    "sample_accession",
    "secondary_sample_accession",
    "experiment_accession",
    "run_accession",
    "scientific_name",
    "library_strategy",
    "library_source",
    "library_selection",
    "library_layout",
    "fastq_ftp",
    "fastq_md5",
]

RESOLVED_FIELDS = [
    "source_accession",
    "source_file",
    "resolution_source",
    *ENA_FIELDS,
]

UNRESOLVED_FIELDS = [
    "accession",
    "repository",
    "accession_type",
    "source_file",
    "reason",
]


class ResolutionError(RuntimeError):
    """Raised when an external accession service cannot be queried."""


def read_accessions(path: Path) -> list[dict[str, str]]:
    """Read and validate ACCESSION_EXTRACTOR output."""
    with path.open(encoding="utf-8", newline="") as input_file:
        reader = csv.DictReader(input_file, delimiter="\t")
        required = {"accession", "repository", "accession_type", "source_file"}
        if reader.fieldnames is None or not required.issubset(reader.fieldnames):
            found = ", ".join(reader.fieldnames or [])
            raise ValueError(
                "Accession table must contain accession, repository, "
                "accession_type, and source_file columns; found: " + found
            )

        rows = []
        for row in reader:
            accession = (row.get("accession") or "").strip().upper()
            if accession:
                rows.append(
                    {
                        "accession": accession,
                        "repository": (row.get("repository") or "").strip(),
                        "accession_type": (
                            row.get("accession_type") or ""
                        ).strip(),
                        "source_file": (row.get("source_file") or "").strip(),
                    }
                )
        return rows


def _download_text(url: str, timeout: int = 60) -> str:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "text/tab-separated-values",
            "User-Agent": f"GenAbu-accession-resolver/{VERSION}",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8")


def fetch_ena_rows(
    accession: str,
    *,
    attempts: int = 3,
    downloader: Callable[[str, int], str] = _download_text,
) -> list[dict[str, str]]:
    """Return ENA read-run rows for an accession."""
    query = urllib.parse.urlencode(
        {
            "accession": accession,
            "result": "read_run",
            "fields": ",".join(ENA_FIELDS),
            "format": "tsv",
            "download": "true",
        }
    )
    url = f"{ENA_FILE_REPORT_URL}?{query}"
    last_error: Exception | None = None

    for attempt in range(1, attempts + 1):
        try:
            body = downloader(url, 60)
            if not body.strip():
                return []

            reader = csv.DictReader(body.splitlines(), delimiter="\t")
            if reader.fieldnames is None:
                return []

            return [
                {field: (row.get(field) or "").strip() for field in ENA_FIELDS}
                for row in reader
                if (row.get("run_accession") or "").strip()
            ]
        except (OSError, TimeoutError, urllib.error.URLError) as error:
            last_error = error
            if attempt < attempts:
                time.sleep(2 ** (attempt - 1))

    raise ResolutionError(
        f"ENA request failed for {accession}: {last_error}"
    )


def _collect_run_accessions(value: Any) -> set[str]:
    runs: set[str] = set()

    if isinstance(value, dict):
        for key, child in value.items():
            if key == "accession" and isinstance(child, str):
                candidate = child.upper()
                if RUN_PATTERN.fullmatch(candidate):
                    runs.add(candidate)
            runs.update(_collect_run_accessions(child))
    elif isinstance(value, list):
        for child in value:
            runs.update(_collect_run_accessions(child))

    return runs


def fetch_ffq_runs(
    accession: str,
    *,
    timeout: int = 300,
    runner: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
) -> list[str]:
    """Use ffq to follow a GEO accession to run accessions."""
    try:
        completed = runner(
            ["ffq", "--ftp", accession],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ResolutionError(f"ffq failed for {accession}: {error}") from error

    if completed.returncode != 0:
        detail = completed.stderr.strip().splitlines()
        message = detail[-1] if detail else f"exit status {completed.returncode}"
        raise ResolutionError(f"ffq failed for {accession}: {message}")

    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise ResolutionError(
            f"ffq returned invalid JSON for {accession}: {error}"
        ) from error

    return sorted(_collect_run_accessions(payload))


def resolve_one(
    record: dict[str, str],
    *,
    ena_fetcher: Callable[[str], list[dict[str, str]]] = fetch_ena_rows,
    ffq_fetcher: Callable[[str], list[str]] = fetch_ffq_runs,
) -> tuple[list[dict[str, str]], str]:
    """Resolve one extracted accession and report the resolution route."""
    accession = record["accession"]

    if GEO_PATTERN.fullmatch(accession):
        ffq_error: ResolutionError | None = None
        try:
            run_accessions = ffq_fetcher(accession)
        except ResolutionError as error:
            ffq_error = error
            run_accessions = []

        rows: list[dict[str, str]] = []
        for run_accession in run_accessions:
            rows.extend(ena_fetcher(run_accession))

        if rows:
            return rows, "ffq+ena"

        # ENA does not normally index GEO series identifiers directly, but this
        # final request is inexpensive and covers cross-repository aliases.
        ena_rows = ena_fetcher(accession)
        if ena_rows:
            return ena_rows, "ena"

        if ffq_error is not None:
            raise ffq_error
        raise ResolutionError(
            f"ffq and ENA returned no sequencing runs for {accession}"
        )

    ena_rows = ena_fetcher(accession)
    if ena_rows:
        return ena_rows, "ena"

    # ffq is a secondary route for supported study/run identifiers when the
    # direct ENA file report is empty, for example during repository sync lag.
    try:
        run_accessions = ffq_fetcher(accession)
    except ResolutionError as error:
        raise ResolutionError(
            f"ENA returned no sequencing runs for {accession}; {error}"
        ) from error

    rows = []
    for run_accession in run_accessions:
        rows.extend(ena_fetcher(run_accession))

    if rows:
        return rows, "ffq+ena"

    raise ResolutionError(
        f"ENA and ffq returned no sequencing runs for {accession}"
    )


def _join_unique(values: Iterable[str]) -> str:
    return ";".join(sorted({value for value in values if value}))


def resolve_records(
    records: list[dict[str, str]],
    *,
    ena_fetcher: Callable[[str], list[dict[str, str]]] = fetch_ena_rows,
    ffq_fetcher: Callable[[str], list[str]] = fetch_ffq_runs,
) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    """Resolve records, deduplicating output by run accession."""
    resolved_by_run: dict[str, dict[str, Any]] = {}
    unresolved: list[dict[str, str]] = []

    for record in records:
        try:
            rows, resolution_source = resolve_one(
                record,
                ena_fetcher=ena_fetcher,
                ffq_fetcher=ffq_fetcher,
            )
        except ResolutionError as error:
            unresolved.append({**record, "reason": str(error)})
            continue

        for row in rows:
            run_accession = row["run_accession"].upper()
            existing = resolved_by_run.get(run_accession)
            if existing is None:
                resolved_by_run[run_accession] = {
                    "source_accessions": {record["accession"]},
                    "source_files": {record["source_file"]},
                    "resolution_sources": {resolution_source},
                    "metadata": {
                        field: (row.get(field) or "") for field in ENA_FIELDS
                    },
                }
            else:
                existing["source_accessions"].add(record["accession"])
                existing["source_files"].add(record["source_file"])
                existing["resolution_sources"].add(resolution_source)

    resolved = []
    for run_accession in sorted(resolved_by_run):
        entry = resolved_by_run[run_accession]
        resolved.append(
            {
                "source_accession": _join_unique(entry["source_accessions"]),
                "source_file": _join_unique(entry["source_files"]),
                "resolution_source": _join_unique(
                    entry["resolution_sources"]
                ),
                **entry["metadata"],
            }
        )

    unresolved.sort(key=lambda row: row["accession"])
    return resolved, unresolved


def write_table(path: Path, fields: list[str], rows: Iterable[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as output_file:
        writer = csv.DictWriter(
            output_file,
            fieldnames=fields,
            delimiter="\t",
            lineterminator="\n",
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Resolve GEO, SRA, ENA, DRA, and BioProject accessions to "
            "run-level metadata."
        )
    )
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--resolved", required=True, type=Path)
    parser.add_argument("--unresolved", required=True, type=Path)
    parser.add_argument("--fail-if-empty", action="store_true")
    parser.add_argument("--version", action="version", version=VERSION)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        records = read_accessions(args.input)
        resolved, unresolved = resolve_records(records)
    except (OSError, ValueError) as error:
        print(f"ACCESSION_RESOLVER: {error}", file=sys.stderr)
        return 1

    write_table(args.resolved, RESOLVED_FIELDS, resolved)
    write_table(args.unresolved, UNRESOLVED_FIELDS, unresolved)

    if args.fail_if_empty and not resolved:
        if not records:
            reason = "the input contains no supported accessions"
        else:
            reason = "none of the extracted accessions resolved to sequencing runs"
        print(f"ACCESSION_RESOLVER: {reason}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
