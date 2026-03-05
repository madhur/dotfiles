#!/usr/bin/env python3
"""
rename_images.py — Rename image files using AWS Bedrock (Claude vision).

Usage:
    python rename_images.py /path/to/folder [--apply] [--region REGION] [--model MODEL] [--max-retries N]
"""

import argparse
import base64
import io
import json
import os
import re
import sys
import time
import unicodedata
from pathlib import Path

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    sys.exit("Error: boto3 is required. Install it with: pip install boto3")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"}

DEFAULT_MODEL = "apac.anthropic.claude-3-7-sonnet-20250219-v1:0"
DEFAULT_REGION = "ap-south-1"
MAX_IMAGE_PX = (1024, 1024)
JPEG_QUALITY = 85

RETRYABLE_CODES = {
    "ThrottlingException",
    "ServiceQuotaExceededException",
    "InternalServerException",
    "ServiceUnavailableException",
    "ModelTimeoutException",
}

FATAL_CODES = {
    "AccessDeniedException",
    "ResourceNotFoundException",
}

# ---------------------------------------------------------------------------
# Slug helpers
# ---------------------------------------------------------------------------

def to_slug(text: str) -> str:
    """Convert arbitrary text to a lowercase kebab-case slug."""
    normalized = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    lower = normalized.lower()
    slugged = re.sub(r"[^a-z0-9]+", "-", lower)
    return slugged.strip("-")


def is_already_slugified(filename: str) -> bool:
    """Return True if the filename already looks like a kebab-case slug."""
    ext = "".join(Path(filename).suffixes).lower()
    if ext not in SUPPORTED_EXTENSIONS:
        return False
    stem = Path(filename).stem
    # Must be at least 2 chars, start/end with alnum, contain only alnum and hyphens
    return bool(re.match(r"^[a-z0-9][a-z0-9-]*[a-z0-9]$", stem))


# ---------------------------------------------------------------------------
# Image resizing (no disk writes)
# ---------------------------------------------------------------------------

def resize_image_in_memory(image_path: Path, max_size=MAX_IMAGE_PX, quality=JPEG_QUALITY):
    """
    Resize image in memory and return (bytes, media_type).
    Returns (None, None) on failure.
    Requires Pillow.
    """
    try:
        from PIL import Image
    except ImportError:
        raise RuntimeError("Pillow is required. Install it with: pip install Pillow")

    try:
        with Image.open(image_path) as img:
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")

            img.thumbnail(max_size, Image.Resampling.LANCZOS)

            buffer = io.BytesIO()
            original_format = (img.format or "JPEG").upper()

            if original_format in ("JPEG", "JPG"):
                img.save(buffer, format="JPEG", quality=quality, optimize=True)
                media_type = "image/jpeg"
            elif original_format == "PNG":
                img.save(buffer, format="PNG", optimize=True)
                media_type = "image/png"
            elif original_format == "GIF":
                img.save(buffer, format="GIF")
                media_type = "image/gif"
            elif original_format == "WEBP":
                img.save(buffer, format="WEBP", quality=quality)
                media_type = "image/webp"
            else:
                # BMP and others → JPEG
                img.save(buffer, format="JPEG", quality=quality, optimize=True)
                media_type = "image/jpeg"

            buffer.seek(0)
            return buffer.getvalue(), media_type

    except Exception as e:
        raise OSError(f"Failed to resize {image_path.name}: {e}") from e


# ---------------------------------------------------------------------------
# Bedrock API
# ---------------------------------------------------------------------------

PROMPT = (
    "Look at this image and give it a descriptive filename. "
    "Respond with ONLY a 3-6 word lowercase kebab-case slug (e.g. fluffy-orange-cat-sleeping). "
    "No punctuation, no explanation, just the slug."
)


def describe_image(client, model_id: str, image_bytes: bytes, media_type: str) -> str:
    """Call Bedrock and return a slug for the image."""
    b64 = base64.b64encode(image_bytes).decode("utf-8")

    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 50,
        "temperature": 0,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": b64,
                        },
                    },
                    {"type": "text", "text": PROMPT},
                ],
            }
        ],
    }

    response = client.invoke_model(
        modelId=model_id,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(body),
    )

    result = json.loads(response["body"].read())
    raw = result["content"][0]["text"].strip()
    return to_slug(raw)


def invoke_with_retry(client, model_id: str, image_bytes: bytes, media_type: str, max_retries: int) -> str:
    """Wrap describe_image with exponential backoff for transient errors."""
    last_error = None
    for attempt in range(max_retries + 1):
        try:
            return describe_image(client, model_id, image_bytes, media_type)
        except ClientError as e:
            code = e.response["Error"]["Code"]
            if code in FATAL_CODES:
                sys.exit(f"Fatal AWS error ({code}): {e.response['Error']['Message']}")
            if code in RETRYABLE_CODES and attempt < max_retries:
                wait = 2 ** (attempt + 1)
                print(f"    [retry {attempt + 1}/{max_retries}] {code} - waiting {wait}s...")
                time.sleep(wait)
                last_error = e
                continue
            raise
    raise last_error


# ---------------------------------------------------------------------------
# Conflict resolution
# ---------------------------------------------------------------------------

def resolve_name(folder: Path, stem: str, suffix: str, used_names: set) -> str:
    """
    Return a filename (stem + suffix) that doesn't collide with existing files
    on disk or with names already claimed in this run.
    """
    candidate = stem + suffix
    if candidate not in used_names and not (folder / candidate).exists():
        return candidate

    counter = 2
    while True:
        candidate = f"{stem}-{counter}{suffix}"
        if candidate not in used_names and not (folder / candidate).exists():
            return candidate
        counter += 1


# ---------------------------------------------------------------------------
# Main processing
# ---------------------------------------------------------------------------

def process_folder(folder: Path, client, model_id: str, apply: bool, max_retries: int) -> None:
    image_files = sorted(
        p for p in folder.iterdir()
        if p.is_file() and p.suffix.lower() in SUPPORTED_EXTENSIONS
    )

    if not image_files:
        print("No image files found in folder.")
        return

    mode_label = "[DRY RUN]" if not apply else "[APPLY]"
    print(f"\n{mode_label} Processing {len(image_files)} image(s)...\n")

    renames = []   # list of (src_path, new_name)
    errors = []    # list of (filename, error_message)
    used_names = set()

    for image_path in image_files:
        name = image_path.name

        if is_already_slugified(name):
            print(f"  {name:<40} (already named, skipped)")
            used_names.add(name)
            continue

        print(f"  Analyzing: {name}", end="", flush=True)

        try:
            image_bytes, media_type = resize_image_in_memory(image_path)
        except RuntimeError as e:
            print(f"\n    Error: {e}")
            errors.append((name, str(e)))
            continue
        except OSError as e:
            print(f"\n    Error: {e}")
            errors.append((name, str(e)))
            continue

        try:
            slug = invoke_with_retry(client, model_id, image_bytes, media_type, max_retries)
        except ClientError as e:
            msg = f"{e.response['Error']['Code']}: {e.response['Error']['Message']}"
            print(f"\n    Error: {msg}")
            errors.append((name, msg))
            continue
        except Exception as e:
            print(f"\n    Error: {e}")
            errors.append((name, str(e)))
            continue

        suffix = image_path.suffix.lower()
        new_name = resolve_name(folder, slug, suffix, used_names)
        used_names.add(new_name)
        renames.append((image_path, new_name))
        print(f"  -> {slug}")
        if apply:
            try:
                os.rename(image_path, folder / new_name)
            except OSError as e:
                print(f"    Error renaming {name}: {e}")
                errors.append((name, str(e)))

    _print_summary(folder, renames, errors, apply)


def _print_summary(folder: Path, renames: list, errors: list, apply: bool) -> None:
    mode_label = "[DRY RUN]" if not apply else "[APPLY]"

    if not renames and not errors:
        print("\nNothing to rename.")
        return

    if renames:
        action = "Would rename" if not apply else "Renaming"
        print(f"\n{mode_label} {action}:")
        max_src = max(len(src.name) for src, _ in renames)
        for src, new_name in renames:
            print(f"  {src.name:<{max_src}}  ->  {new_name}")

    if errors:
        print(f"\nErrors ({len(errors)}):")
        for filename, msg in errors:
            print(f"  {filename}: {msg}")

    if not apply:
        print("\nRun with --apply to execute renames.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Rename images using AWS Bedrock (Claude vision)."
    )
    parser.add_argument("folder", help="Path to folder containing images")
    parser.add_argument(
        "--apply", action="store_true", help="Execute renames (default: dry run)"
    )
    parser.add_argument(
        "--region", default=DEFAULT_REGION, help=f"AWS region (default: {DEFAULT_REGION})"
    )
    parser.add_argument(
        "--model", default=DEFAULT_MODEL, help=f"Bedrock inference profile ID (default: {DEFAULT_MODEL})"
    )
    parser.add_argument(
        "--max-retries", type=int, default=3, metavar="N",
        help="Max retries for transient errors (default: 3)"
    )
    args = parser.parse_args()

    folder = Path(args.folder).expanduser().resolve()
    if not folder.is_dir():
        sys.exit(f"Error: '{folder}' is not a directory.")

    try:
        client = boto3.client("bedrock-runtime", region_name=args.region)
    except Exception as e:
        sys.exit(f"Error creating Bedrock client: {e}")

    process_folder(folder, client, args.model, args.apply, args.max_retries)


if __name__ == "__main__":
    main()
