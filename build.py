#!/usr/bin/env python3

import argparse
import json
import re
import shutil
import subprocess
import sys
import shlex
import uuid
import urllib.request
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
PUBSPEC_YAML = ROOT_DIR / "pubspec.yaml"
PUBSPEC_LOCK = ROOT_DIR / "pubspec.lock"
VERSION_FILE = ROOT_DIR / "VERSION"

FLUTTER_RELEASES_URL = (
    "https://storage.googleapis.com/"
    "flutter_infra_release/releases/releases_linux.json"
)

DOCKER_IMAGE_PREFIX = "ghcr.io/gmeligio/flutter-android"


def die(message: str) -> None:
    print(f"Error: {message}", file=sys.stderr)
    sys.exit(1)


def run(
    command: list[str],
    *,
    cwd: Path | None = None,
) -> None:
    print(f"+ {shlex.join(command)}")

    subprocess.run(
        command,
        cwd=cwd,
        check=True,
    )


def check_flutter_project() -> None:
    if not PUBSPEC_YAML.is_file():
        die(
            "pubspec.yaml not found. "
            "build.py must be in the Flutter project root."
        )

    if not PUBSPEC_LOCK.is_file():
        die(
            "pubspec.lock not found. "
            "Run 'flutter pub get' first."
        )

    if not VERSION_FILE.is_file():
        die("VERSION not found in the project root.")


def get_app_version() -> str:
    version = VERSION_FILE.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        die("VERSION must use the X.Y.Z format.")
    return version


def get_sdk_constraints() -> tuple[str, str]:
    """
    Read the `sdks:` section from pubspec.lock.

    Example:

        sdks:
          dart: ">=3.13.2 <4.0.0"
          flutter: ">=3.38.4"
    """

    dart_constraint = None
    flutter_constraint = None
    in_sdks = False

    with PUBSPEC_LOCK.open(encoding="utf-8") as file:
        for raw_line in file:
            line = raw_line.rstrip()

            if line == "sdks:":
                in_sdks = True
                continue

            if in_sdks and line and not line[0].isspace():
                break

            if not in_sdks:
                continue

            match = re.match(
                r'^\s+(dart|flutter):\s*["\']?(.+?)["\']?\s*$',
                line,
            )

            if not match:
                continue

            sdk, constraint = match.groups()

            if sdk == "dart":
                dart_constraint = constraint
            elif sdk == "flutter":
                flutter_constraint = constraint

    if not dart_constraint:
        die("No Dart SDK constraint found in pubspec.lock.")

    if not flutter_constraint:
        die("No Flutter SDK constraint found in pubspec.lock.")

    return dart_constraint, flutter_constraint


def parse_version(version: str) -> tuple[int, int, int]:
    match = re.match(
        r"^(\d+)\.(\d+)\.(\d+)",
        version.strip(),
    )

    if not match:
        raise ValueError(f"Invalid version: {version}")

    return tuple(map(int, match.groups()))


def satisfies_constraint(
    version: str,
    constraint: str,
) -> bool:
    """
    Supports constraints such as:

        >=3.38.4
        >=3.13.2 <4.0.0
        >3.10.0 <=4.0.0
        3.47.2
    """

    actual = parse_version(version)

    for token in constraint.split():
        match = re.fullmatch(
            r"(>=|<=|>|<|=)?(\d+\.\d+\.\d+)",
            token,
        )

        if not match:
            raise ValueError(
                f"Unsupported SDK constraint: {token}"
            )

        operator = match.group(1) or "="
        expected = parse_version(match.group(2))

        if operator == ">=" and not actual >= expected:
            return False

        if operator == "<=" and not actual <= expected:
            return False

        if operator == ">" and not actual > expected:
            return False

        if operator == "<" and not actual < expected:
            return False

        if operator == "=" and not actual == expected:
            return False

    return True


def fetch_flutter_releases() -> list[dict]:
    print("Fetching Flutter release metadata...")

    try:
        with urllib.request.urlopen(
            FLUTTER_RELEASES_URL,
            timeout=30,
        ) as response:
            data = json.load(response)

    except Exception as exc:
        die(f"Failed to retrieve Flutter release metadata: {exc}")

    return data["releases"]


def compatible_flutter_releases(
    dart_constraint: str,
    flutter_constraint: str,
) -> list[tuple[str, str]]:
    """
    Return compatible stable releases as:

        [
            ("3.47.2", "3.13.2"),
            ("3.47.3", "3.13.3"),
            ...
        ]

    ordered oldest -> newest.
    """

    compatible: dict[str, str] = {}

    for release in fetch_flutter_releases():
        if release.get("channel") != "stable":
            continue

        # Ignore ARM duplicate records in Flutter's Linux manifest.
        if release.get("dart_sdk_arch") not in (None, "x64"):
            continue

        flutter_version = release.get("version")
        dart_version_raw = release.get("dart_sdk_version")

        if not flutter_version or not dart_version_raw:
            continue

        dart_match = re.match(
            r"^(\d+\.\d+\.\d+)",
            dart_version_raw,
        )

        if not dart_match:
            continue

        dart_version = dart_match.group(1)

        try:
            flutter_ok = satisfies_constraint(
                flutter_version,
                flutter_constraint,
            )

            dart_ok = satisfies_constraint(
                dart_version,
                dart_constraint,
            )

        except ValueError as exc:
            die(str(exc))

        if flutter_ok and dart_ok:
            compatible[flutter_version] = dart_version

    return sorted(
        compatible.items(),
        key=lambda item: parse_version(item[0]),
    )


def docker_image_exists(image: str) -> bool:
    result = subprocess.run(
        [
            "docker",
            "manifest",
            "inspect",
            image,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    return result.returncode == 0


def resolve_docker_image() -> tuple[str, str, str]:
    dart_constraint, flutter_constraint = get_sdk_constraints()

    print("====================================")
    print("Resolving Flutter Docker image")
    print(f"Flutter constraint: {flutter_constraint}")
    print(f"Dart constraint:    {dart_constraint}")
    print("====================================")

    releases = compatible_flutter_releases(
        dart_constraint,
        flutter_constraint,
    )

    if not releases:
        die(
            "No stable Flutter release satisfies both SDK constraints.\n\n"
            f"Flutter: {flutter_constraint}\n"
            f"Dart:    {dart_constraint}"
        )

    for flutter_version, dart_version in releases:
        image = (
            f"{DOCKER_IMAGE_PREFIX}:"
            f"{flutter_version}"
        )

        print(
            f"Checking Flutter {flutter_version} "
            f"/ Dart {dart_version}..."
        )

        if docker_image_exists(image):
            return image, flutter_version, dart_version

    die(
        "Compatible Flutter releases exist, "
        "but no matching Docker image was found."
    )


def flutter_build_command(build_type: str) -> list[str]:
    version_arguments = [
        "--build-name",
        get_app_version(),
    ]

    if build_type == "prod":
        return [
            "flutter",
            "build",
            "apk",
            "--release",
            *version_arguments,
        ]

    return [
        "flutter",
        "build",
        "apk",
        "--debug",
        *version_arguments,
    ]


def build_local(build_type: str) -> None:
    if shutil.which("flutter") is None:
        die("Flutter was not found in PATH.")

    check_flutter_project()

    print("====================================")
    print("Building Flutter app locally")
    print(f"Build type: {build_type}")
    print("====================================")

    run(
        ["flutter", "pub", "get"],
        cwd=ROOT_DIR,
    )

    run(
        flutter_build_command(build_type),
        cwd=ROOT_DIR,
    )

    print()
    print("Build completed successfully.")

    if build_type == "prod":
        print(
            "APK: "
            "build/app/outputs/flutter-apk/"
            "app-release.apk"
        )
    else:
        print(
            "APK: "
            "build/app/outputs/flutter-apk/"
            "app-debug.apk"
        )


def build_docker(build_type: str) -> None:
    if shutil.which("docker") is None:
        die("Docker was not found in PATH.")

    check_flutter_project()

    image, flutter_version, dart_version = resolve_docker_image()

    print()
    print("====================================")
    print("Building Flutter app through Docker")
    print(f"Flutter:    {flutter_version}")
    print(f"Dart:       {dart_version}")
    print(f"Build type: {build_type}")
    print(f"Image:      {image}")
    print("====================================")

    if build_type == "prod":
        container_apk = (
            "/tmp/app/build/app/outputs/"
            "flutter-apk/app-release.apk"
        )
        host_apk = (
            ROOT_DIR
            / "build"
            / "app"
            / "outputs"
            / "flutter-apk"
            / "app-release.apk"
        )
    else:
        container_apk = (
            "/tmp/app/build/app/outputs/"
            "flutter-apk/app-debug.apk"
        )
        host_apk = (
            ROOT_DIR
            / "build"
            / "app"
            / "outputs"
            / "flutter-apk"
            / "app-debug.apk"
        )

    build_command = flutter_build_command(build_type)

    shell_command = "\n".join(
        [
            "set -euo pipefail",
            "",
            'rm -rf /tmp/app',
            'mkdir -p /tmp/app',
            "",
            # Copy into the container filesystem so everything is owned
            # by the container's flutter user instead of the host user.
            'cp -a --no-preserve=ownership /src/. /tmp/app/',
            "",
            'cd /tmp/app',
            "",
            # Don't reuse host-generated Flutter state.
            'rm -rf .dart_tool build',
            "",
            'flutter pub get',
            shlex.join(build_command),
        ]
    )

    container_name = (
        f"flutter-build-{uuid.uuid4().hex[:12]}"
    )

    try:
        run(
            [
                "docker",
                "run",
                "--name",
                container_name,
                "--mount",
                f"type=bind,source={ROOT_DIR},target=/src,readonly",
                image,
                "bash",
                "-c",
                shell_command,
            ]
        )

        #
        # docker cp creates the destination file as the host user
        # invoking Docker, avoiding UID 1001 ownership on the host.
        #
        host_apk.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        if host_apk.exists():
            host_apk.unlink()

        run(
            [
                "docker",
                "cp",
                f"{container_name}:{container_apk}",
                str(host_apk),
            ]
        )

    finally:
        subprocess.run(
            [
                "docker",
                "rm",
                "-f",
                container_name,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    print()
    print("Build completed successfully.")
    print(f"APK: {host_apk.relative_to(ROOT_DIR)}")
    

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build LibreSlip.",
    )

    parser.add_argument(
        "command",
        choices=["local", "docker"],
        help="Build locally or through Docker.",
    )

    parser.add_argument(
        "build_type",
        choices=["prod", "debug"],
        help="Build a production or debug APK.",
    )

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.command == "local":
        build_local(args.build_type)
    else:
        build_docker(args.build_type)


if __name__ == "__main__":
    main()
