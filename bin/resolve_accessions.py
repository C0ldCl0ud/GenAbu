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
GEO_ACCESSION_URL = "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi"

RUN_PATTERN = re.compile(r"^(?:SRR|ERR|DRR)[0-9]+$", re.IGNORECASE)
GEO_PATTERN = re.compile(r"^GSE[0-9]+$", re.IGNORECASE)
BIOPROJECT_PATTERN = re.compile(
    r"\bPRJ(?:NA|EB|DB)[0-9]+\b",
    re.IGNORECASE,
)

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

SAMPLESHEET_FIELDS = ["sample", "accession"]


class ResolutionError(RuntimeError):
    """Raised when an external accession service cannot be queried."""


def read_accessions(path: Path) -> list[dict[str, str]]:
    """Read and validate ACCESSION_EXTRACTOR output."""
    with path.open(encoding="utf-8", newline="") as input_file:
        reader = csv.DictReader(input_file, delimiter="\t")
        required = {
            "accession",
            "repository",
            "accession_type",
            "source_file",
        }

        if reader.fieldnames is None or not required.issubset(reader.fieldnames):
            found = ", ".join(reader.fieldnames or [])
            raise ValueError(
                "Accession table must contain accession, repository, "
                "accession_type, and source_file columns; found: "
                + found
            )

        rows = []

        for row in reader:
            accession = (row.get("accession") or "").strip().upper()

            if accession:
                rows.append(
                    {
                        "accession": accession,
                        "repository": (
                            row.get("repository") or ""
                        ).strip(),
                        "accession_type": (
                            row.get("accession_type") or ""
                        ).strip(),
                        "source_file": (
                            row.get("source_file") or ""
                        ).strip(),
                    }
                )

        return rows


def _request_text(
    url: str,
    *,
    accept: str,
    timeout: int,
) -> str:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": accept,
            "User-Agent": f"GenAbu-accession-resolver/{VERSION}",
        },
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8")


def _download_text(url: str, timeout: int = 60) -> str:
    """Download ENA tab-separated metadata."""
    return _request_text(
        url,
        accept="text/tab-separated-values",
        timeout=timeout,
    )


def _download_geo_text(url: str, timeout: int = 60) -> str:
    """Download a GEO record in plain-text form."""
    return _request_text(
        url,
        accept="text/plain",
        timeout=timeout,
    )


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

            reader = csv.DictReader(
                body.splitlines(),
                delimiter="\t",
            )

            if reader.fieldnames is None:
                return []

            return [
                {
                    field: (row.get(field) or "").strip()
                    for field in ENA_FIELDS
                }
                for row in reader
                if (row.get("run_accession") or "").strip()
            ]

        except (
            OSError,
            TimeoutError,
            urllib.error.URLError,
        ) as error:
            last_error = error

            if attempt < attempts:
                time.sleep(2 ** (attempt - 1))

    raise ResolutionError(
        f"ENA request failed for {accession}: {last_error}"
    )


def fetch_geo_bioprojects(
    accession: str,
    *,
    attempts: int = 3,
    downloader: Callable[[str, int], str] = _download_geo_text,
) -> list[str]:
    """
    Return BioProject accessions linked to a GEO series.

    GEO exposes records in a plain-text representation. Series relations
    can contain BioProject identifiers such as PRJNA926667.
    """
    query = urllib.parse.urlencode(
        {
            "acc": accession,
            "targ": "self",
            "form": "text",
            "view": "full",
        }
    )

    url = f"{GEO_ACCESSION_URL}?{query}"
    last_error: Exception | None = None

    for attempt in range(1, attempts + 1):
        try:
            body = downloader(url, 60)

            if not body.strip():
                return []

            projects: set[str] = set()

            for line in body.splitlines():
                # Restrict extraction to relationship information so that
                # unrelated BioProject IDs in free text are not interpreted
                # as links for this GEO series.
                if (
                    "series_relation" not in line.lower()
                    and "bioproject" not in line.lower()
                ):
                    continue

                for match in BIOPROJECT_PATTERN.finditer(line):
                    projects.add(match.group(0).upper())

            return sorted(projects)

        except (
            OSError,
            TimeoutError,
            urllib.error.URLError,
        ) as error:
            last_error = error

            if attempt < attempts:
                time.sleep(2 ** (attempt - 1))

    raise ResolutionError(
        f"GEO request failed for {accession}: {last_error}"
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
    runner: Callable[
        ..., subprocess.CompletedProcess[str]
    ] = subprocess.run,
) -> list[str]:
    """Use ffq to follow an accession to run accessions."""
    try:
        completed = runner(
            ["ffq", accession],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )

    except (
        OSError,
        subprocess.TimeoutExpired,
    ) as error:
        raise ResolutionError(
            f"ffq failed for {accession}: {error}"
        ) from error

    if completed.returncode != 0:
        stderr_lines = [
            line.strip()
            for line in completed.stderr.splitlines()
            if line.strip()
        ]

        if stderr_lines:
            # Keep the useful diagnostic information while ensuring that
            # unresolved.tsv remains one physical line per accession.
            message = " | ".join(stderr_lines)
        else:
            message = f"exit status {completed.returncode}"

        raise ResolutionError(
            f"ffq failed for {accession}: {message}"
        )

    try:
        payload = json.loads(completed.stdout)

    except json.JSONDecodeError as error:
        raise ResolutionError(
            f"ffq returned invalid JSON for {accession}: {error}"
        ) from error

    return sorted(_collect_run_accessions(payload))


def resolve_geo_via_bioproject(
    accession: str,
    *,
    ena_fetcher: Callable[
        [str], list[dict[str, str]]
    ] = fetch_ena_rows,
    geo_fetcher: Callable[
        [str], list[str]
    ] = fetch_geo_bioprojects,
) -> list[dict[str, str]]:
    """Resolve a GEO series through its linked BioProject accession."""
    projects = geo_fetcher(accession)

    if not projects:
        return []

    rows: list[dict[str, str]] = []

    for project in projects:
        rows.extend(ena_fetcher(project))

    return rows


def resolve_one(
    record: dict[str, str],
    *,
    ena_fetcher: Callable[
        [str], list[dict[str, str]]
    ] = fetch_ena_rows,
    ffq_fetcher: Callable[
        [str], list[str]
    ] = fetch_ffq_runs,
    geo_fetcher: Callable[
        [str], list[str]
    ] = fetch_geo_bioprojects,
) -> tuple[list[dict[str, str]], str]:
    """Resolve one extracted accession and report the resolution route."""
    accession = record["accession"]

    if GEO_PATTERN.fullmatch(accession):
        ffq_error: ResolutionError | None = None
        geo_error: ResolutionError | None = None

        # First retain the existing ffq route. If ffq works, no change in
        # behaviour is introduced for GEO records that were already
        # resolvable.
        try:
            run_accessions = ffq_fetcher(accession)

        except ResolutionError as error:
            ffq_error = error
            run_accessions = []

        rows: list[dict[str, str]] = []

        try:
            for run_accession in run_accessions:
                rows.extend(
                    ena_fetcher(run_accession)
                )

        except ResolutionError as error:
            ffq_error = error
            rows = []

        if rows:
            return rows, "ffq+ena"

        # ffq 0.3.1 can currently fail while traversing GEO -> SRA
        # relationships. Use the BioProject relation published by GEO as
        # an independent fallback route.
        try:
            rows = resolve_geo_via_bioproject(
                accession,
                ena_fetcher=ena_fetcher,
                geo_fetcher=geo_fetcher,
            )

        except ResolutionError as error:
            geo_error = error
            rows = []

        if rows:
            return rows, "geo+bioproject+ena"

        errors = []

        if ffq_error is not None:
            errors.append(str(ffq_error))

        if geo_error is not None:
            errors.append(str(geo_error))

        if errors:
            raise ResolutionError(
                "; ".join(errors)
            )

        raise ResolutionError(
            "ffq and GEO BioProject resolution returned no "
            f"sequencing runs for {accession}"
        )

    ena_rows = ena_fetcher(accession)

    if ena_rows:
        return ena_rows, "ena"

    # ffq is a secondary route for supported study/run identifiers when
    # the direct ENA file report is empty, for example during repository
    # synchronisation lag.
    try:
        run_accessions = ffq_fetcher(accession)

    except ResolutionError as error:
        raise ResolutionError(
            f"ENA returned no sequencing runs for {accession}; "
            f"{error}"
        ) from error

    rows: list[dict[str, str]] = []

    for run_accession in run_accessions:
        rows.extend(
            ena_fetcher(run_accession)
        )

    if rows:
        return rows, "ffq+ena"

    raise ResolutionError(
        f"ENA and ffq returned no sequencing runs for {accession}"
    )


def _join_unique(values: Iterable[str]) -> str:
    return ";".join(
        sorted(
            {
                value
                for value in values
                if value
            }
        )
    )


def resolve_records(
    records: list[dict[str, str]],
    *,
    ena_fetcher: Callable[
        [str], list[dict[str, str]]
    ] = fetch_ena_rows,
    ffq_fetcher: Callable[
        [str], list[str]
    ] = fetch_ffq_runs,
    geo_fetcher: Callable[
        [str], list[str]
    ] = fetch_geo_bioprojects,
) -> tuple[
    list[dict[str, str]],
    list[dict[str, str]],
]:
    """Resolve records, deduplicating output by run accession."""
    resolved_by_run: dict[str, dict[str, Any]] = {}
    unresolved: list[dict[str, str]] = []

    for record in records:
        try:
            rows, resolution_source = resolve_one(
                record,
                ena_fetcher=ena_fetcher,
                ffq_fetcher=ffq_fetcher,
                geo_fetcher=geo_fetcher,
            )

        except ResolutionError as error:
            unresolved.append(
                {
                    **record,
                    "reason": str(error),
                }
            )
            continue

        for row in rows:
            run_accession = row["run_accession"].upper()
            existing = resolved_by_run.get(run_accession)

            if existing is None:
                resolved_by_run[run_accession] = {
                    "source_accessions": {
                        record["accession"]
                    },
                    "source_files": {
                        record["source_file"]
                    },
                    "resolution_sources": {
                        resolution_source
                    },
                    "metadata": {
                        field: (row.get(field) or "")
                        for field in ENA_FIELDS
                    },
                }

            else:
                existing["source_accessions"].add(
                    record["accession"]
                )
                existing["source_files"].add(
                    record["source_file"]
                )
                existing["resolution_sources"].add(
                    resolution_source
                )

    resolved = []

    for run_accession in sorted(resolved_by_run):
        entry = resolved_by_run[run_accession]

        resolved.append(
            {
                "source_accession": _join_unique(
                    entry["source_accessions"]
                ),
                "source_file": _join_unique(
                    entry["source_files"]
                ),
                "resolution_source": _join_unique(
                    entry["resolution_sources"]
                ),
                **entry["metadata"],
            }
        )

    unresolved.sort(
        key=lambda row: row["accession"]
    )

    return resolved, unresolved


def write_table(
    path: Path,
    fields: list[str],
    rows: Iterable[dict[str, str]],
) -> None:
    with path.open(
        "w",
        encoding="utf-8",
        newline="",
    ) as output_file:

        writer = csv.DictWriter(
            output_file,
            fieldnames=fields,
            delimiter="\t",
            lineterminator="\n",
            extrasaction="ignore",
        )

        writer.writeheader()
        writer.writerows(rows)


def write_samplesheet(
    path: Path,
    resolved: Iterable[dict[str, str]],
) -> None:
    """Write a reusable SRA samplesheet with one unique row per run."""
    rows = [
        {
            "sample": row["run_accession"],
            "accession": row["run_accession"],
        }
        for row in resolved
    ]

    with path.open(
        "w",
        encoding="utf-8",
        newline="",
    ) as output_file:

        writer = csv.DictWriter(
            output_file,
            fieldnames=SAMPLESHEET_FIELDS,
            delimiter=",",
            lineterminator="\n",
        )

        writer.writeheader()
        writer.writerows(rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Resolve GEO, SRA, ENA, DRA, and BioProject "
            "accessions to run-level metadata."
        )
    )

    parser.add_argument(
        "--input",
        required=True,
        type=Path,
    )

    parser.add_argument(
        "--resolved",
        required=True,
        type=Path,
    )

    parser.add_argument(
        "--unresolved",
        required=True,
        type=Path,
    )

    parser.add_argument(
        "--samplesheet",
        required=True,
        type=Path,
    )

    parser.add_argument(
        "--fail-if-empty",
        action="store_true",
    )

    parser.add_argument(
        "--max-runs",
        type=int,
        default=20,
        help=(
            "Maximum number of unique sequencing runs to emit "
            "(default: 20)."
        ),
    )

    parser.add_argument(
        "--version",
        action="version",
        version=VERSION,
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.max_runs < 1:
        print(
            "ACCESSION_RESOLVER: --max-runs must be at least 1",
            file=sys.stderr,
        )
        return 1

    try:
        records = read_accessions(args.input)

        resolved, unresolved = resolve_records(
            records
        )

    except (
        OSError,
        ValueError,
    ) as error:
        print(
            f"ACCESSION_RESOLVER: {error}",
            file=sys.stderr,
        )
        return 1

    resolved = resolved[:args.max_runs]

    write_table(
        args.resolved,
        RESOLVED_FIELDS,
        resolved,
    )

    write_table(
        args.unresolved,
        UNRESOLVED_FIELDS,
        unresolved,
    )

    write_samplesheet(
        args.samplesheet,
        resolved,
    )

    if args.fail_if_empty and not resolved:
        if not records:
            reason = (
                "the input contains no supported accessions"
            )
        else:
            reason = (
                "none of the extracted accessions resolved "
                "to sequencing runs"
            )

        print(
            f"ACCESSION_RESOLVER: {reason}",
            file=sys.stderr,
        )

        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())