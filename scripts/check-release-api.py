#!/usr/bin/env python3
"""Fail a mobile release before compilation if its public API is unusable.

Uses the same API_BASE_URL that is passed to Flutter. Only performs anonymous
GET requests; never requires or prints application credentials.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


class ReleaseApiError(Exception):
    pass


def permitted_transport(parsed):
    # Explicitly approved public, read-only gateway exception. All other
    # release hosts still require HTTPS.
    return parsed.scheme == "https" or (
        parsed.scheme == "http"
        and parsed.hostname == "technocare-live-api.runasp.net"
        and parsed.port in (None, 80)
    )


def api_base(value):
    value = value.strip().rstrip("/")
    parsed = urllib.parse.urlsplit(value)
    if (
        not permitted_transport(parsed)
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
        or parsed.path != "/api"
    ):
        raise ReleaseApiError("API_BASE_URL must be an HTTPS origin followed by /api, or the approved HTTP gateway.")
    return value


def read_json(url):
    request = urllib.request.Request(
        url, headers={"Accept": "application/json", "User-Agent": "TechnocareReleaseCheck/1.0"}
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            source = urllib.parse.urlsplit(url)
            destination = urllib.parse.urlsplit(response.url)
            if not permitted_transport(destination) or (source.scheme == "https" and destination.scheme != "https"):
                raise ReleaseApiError("API redirected to an unapproved insecure endpoint.")
            if response.status != 200:
                raise ReleaseApiError(f"Expected HTTP 200, received {response.status}.")
            return json.load(response)
    except urllib.error.HTTPError as error:
        raise ReleaseApiError(f"HTTP {error.code}; the public route must work without login.") from error
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        raise ReleaseApiError(f"DNS, TLS or connection failure: {error.reason if isinstance(error, urllib.error.URLError) else error}") from error
    except (ValueError, UnicodeError) as error:
        raise ReleaseApiError("Response is not valid JSON (possibly a hosting error page).") from error


def validate_home(data):
    if not isinstance(data, dict) or not isinstance(data.get("sections"), list):
        raise ReleaseApiError("Homepage response must contain a sections array.")
    visible_types = {
        "hero", "about", "mission", "categories", "brands", "best_sellers",
        "services", "education", "quality", "projects", "partners",
    }
    if not any(isinstance(section, dict) and section.get("type") in visible_types for section in data["sections"]):
        raise ReleaseApiError("Homepage has no sections supported by the mobile renderer.")


def validate_products(data):
    if not isinstance(data, dict) or not isinstance(data.get("items"), list) or not data["items"]:
        raise ReleaseApiError("Product catalogue must contain at least one item.")
    product = data["items"][0]
    if not isinstance(product, dict) or not product.get("id") or not product.get("name"):
        raise ReleaseApiError("Product catalogue does not match the mobile contract.")


def check(base, fetch=read_json):
    base = api_base(base)
    # Test the exact first-install homepage request, not just process health.
    for path, validator in (
        ("v1/content/home", validate_home),
        ("v1/shop/products?page=1&pageSize=1", validate_products),
    ):
        url = f"{base}/{path}"
        try:
            validator(fetch(url))
        except ReleaseApiError as error:
            raise ReleaseApiError(f"{url}: {error}") from error
        print(f"PASS {url}")


if __name__ == "__main__":
    try:
        check(os.environ.get("API_BASE_URL", ""))
    except ReleaseApiError as error:
        print(f"RELEASE BLOCKED: {error}", file=sys.stderr)
        print("Deploy the current backend and fix its DNS/TLS/upstream access, then rerun the release.", file=sys.stderr)
        sys.exit(1)
