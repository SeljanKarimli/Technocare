import importlib.util
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch
import urllib.error

spec = importlib.util.spec_from_file_location("release_api", Path(__file__).with_name("check-release-api.py"))
release_api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_api)


class ReleaseApiTests(unittest.TestCase):
    def test_gateway_requires_https(self):
        base = "https://technocare-live-api.runasp.net/api"
        self.assertEqual(release_api.api_base(base), base)
        for value in ("http://technocare-live-api.runasp.net/api", "http://technocare-live-api.runasp.net.evil.test/api", "http://technocare-live-api.runasp.net:8080/api"):
            with self.subTest(value=value), self.assertRaises(release_api.ReleaseApiError):
                release_api.api_base(value)

    def test_release_rejects_insecure_or_malformed_configuration(self):
        for base in ("", "http://api.example.com/api", "https://api.example.com", "https://user:secret@api.example.com/api", "https://api.example.com/api?key=secret"):
            with self.subTest(base=base), self.assertRaises(release_api.ReleaseApiError):
                release_api.api_base(base)

    def test_home_rejects_empty_or_unrenderable_content(self):
        for data in ([], {}, {"sections": []}, {"sections": [{"type": "unsupported"}]}):
            with self.subTest(data=data), self.assertRaises(release_api.ReleaseApiError):
                release_api.validate_home(data)

    def test_home_accepts_renderable_sections(self):
        release_api.validate_home({"sections": [{"type": "hero", "title": "Technocare"}]})

    def test_catalogue_rejects_empty_or_wrong_contract(self):
        for data in ([], {"items": []}, {"items": [{}]}):
            with self.subTest(data=data), self.assertRaises(release_api.ReleaseApiError):
                release_api.validate_products(data)

    def test_checks_exact_mobile_routes_with_release_base(self):
        urls = []

        def fetch(url):
            urls.append(url)
            return {"sections": [{"type": "hero"}]} if url.endswith("/home") else {"items": [{"id": 1, "name": "Product"}]}

        release_api.check("https://api.example.com/api/", fetch=fetch)
        self.assertEqual(urls, ["https://api.example.com/api/v1/content/home", "https://api.example.com/api/v1/shop/products?page=1&pageSize=1"])

    def test_dns_failure_is_actionable(self):
        with patch.object(release_api.urllib.request, "urlopen", side_effect=urllib.error.URLError("Name or service not known")):
            with self.assertRaisesRegex(release_api.ReleaseApiError, "DNS, TLS or connection failure"):
                release_api.read_json("https://api.example.com/api/v1/content/home")

    def test_release_rejects_redirect_to_http(self):
        response = MagicMock()
        response.__enter__.return_value = response
        response.url = "http://technocare-live-api.runasp.net/api/v1/content/home"
        response.status = 200
        with patch.object(release_api.urllib.request, "urlopen", return_value=response):
            with self.assertRaisesRegex(release_api.ReleaseApiError, "insecure endpoint"):
                release_api.read_json("https://technocare-live-api.runasp.net/api/v1/content/home")

    def test_forbidden_is_not_mistaken_for_success(self):
        error = urllib.error.HTTPError("https://api.example.com/api/v1/content/home", 403, "Forbidden", {}, None)
        with patch.object(release_api.urllib.request, "urlopen", side_effect=error):
            with self.assertRaisesRegex(release_api.ReleaseApiError, "HTTP 403"):
                release_api.read_json(error.url)


if __name__ == "__main__":
    unittest.main()
