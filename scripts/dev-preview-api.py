"""Local-only API for exercising the Flutter preview before infrastructure deploy.

It keeps auth/application data in memory and proxies public catalogue reads to
the live WooCommerce Store API. It never sends email or push notifications.
"""

from __future__ import annotations

import html
import json
import re
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


HOST = "127.0.0.1"
PORT = 8787
WOO_BASE = "https://technocare.az/wp-json/wc/store/v1"
VERIFY_CODE = "123456"
TOKEN = "local-preview-token"

USERS: dict[str, dict[str, object]] = {
    "demo@technocare.az": {
        "id": "local-demo-user",
        "name": "Demo istifadəçi",
        "email": "demo@technocare.az",
        "phone": "+994 50 000 00 00",
        "password": "Technocare123!",
        "verified": True,
    }
}

PUBLIC_NOTIFICATIONS = [
    {
        "id": "000000000000000000000001",
        "title": "Technocare bildirişləri aktivdir",
        "message": "Production qoşulduqdan sonra sayt yenilikləri burada və cihaz bildirişi kimi görünəcək.",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "category": "website",
        "url": "https://technocare.az/",
        "isBroadcast": True,
        "read": False,
    }
]


def clean_text(value: object) -> str:
    text = re.sub(r"<[^>]+>", " ", str(value or ""))
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def money(value: object, minor_unit: int) -> float | None:
    try:
        return int(str(value)) / (10**minor_unit)
    except (TypeError, ValueError):
        return None


def map_product(item: dict[str, object]) -> dict[str, object]:
    prices = item.get("prices") if isinstance(item.get("prices"), dict) else {}
    minor = int(prices.get("currency_minor_unit", 2))
    attributes = item.get("attributes") if isinstance(item.get("attributes"), list) else []
    brand = ""
    for attribute in attributes:
        if not isinstance(attribute, dict) or attribute.get("taxonomy") != "pa_brand":
            continue
        terms = attribute.get("terms") if isinstance(attribute.get("terms"), list) else []
        if terms and isinstance(terms[0], dict):
            brand = str(terms[0].get("name", ""))
            break
    categories = []
    for category in item.get("categories", []) if isinstance(item.get("categories"), list) else []:
        if isinstance(category, dict):
            categories.append(
                {
                    "id": int(category.get("id", 0)),
                    "name": str(category.get("name", "")),
                    "slug": str(category.get("slug", "")),
                    "parentId": 0,
                    "count": 0,
                    "imageUrl": "",
                }
            )
    images = [
        str(image.get("src"))
        for image in item.get("images", []) if isinstance(item.get("images"), list)
        if isinstance(image, dict) and image.get("src")
    ]
    return {
        "id": int(item.get("id", 0)),
        "name": clean_text(item.get("name")),
        "slug": str(item.get("slug", "")),
        "sku": str(item.get("sku", "")),
        "brand": brand,
        "categories": categories,
        "shortDescription": clean_text(item.get("short_description")),
        "description": clean_text(item.get("description")),
        "images": images,
        "price": money(prices.get("price"), minor),
        "regularPrice": money(prices.get("regular_price"), minor),
        "salePrice": money(prices.get("sale_price"), minor),
        "currencyCode": str(prices.get("currency_code", "AZN")),
        "currencySymbol": html.unescape(str(prices.get("currency_symbol", "₼"))),
        "onSale": bool(item.get("on_sale")),
        "inStock": bool(item.get("is_in_stock")),
        "purchasable": bool(item.get("is_purchasable")),
        "permalink": str(item.get("permalink", "")),
    }


def woo_json(path: str, params: dict[str, object] | None = None):
    url = f"{WOO_BASE}/{path.lstrip('/')}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"User-Agent": "TechnocareLocalPreview/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.loads(response.read().decode("utf-8"))
        return payload, dict(response.headers)


class Handler(BaseHTTPRequestHandler):
    server_version = "TechnocarePreview/1.0"

    def log_message(self, format_string: str, *args: object) -> None:
        print(f"[{self.log_date_time_string()}] {format_string % args}")

    def end_headers(self) -> None:
        origin = self.headers.get("Origin", "http://127.0.0.1:8765")
        if origin in {"http://127.0.0.1:8765", "http://localhost:8765"}:
            self.send_header("Access-Control-Allow-Origin", origin)
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path.lower().rstrip("/")
        query = urllib.parse.parse_qs(parsed.query)
        try:
            if path == "/api/notifications/public":
                return self.json_response(PUBLIC_NOTIFICATIONS)
            if path == "/api/notifications/my-notifications":
                return self.json_response(PUBLIC_NOTIFICATIONS)
            if path in {"/api/v1/content/services", "/api/v1/content/education"}:
                kind = path.rsplit("/", 1)[-1]
                return self.json_response({"updatedAt": datetime.now(timezone.utc).isoformat(), "sourceUrl": "https://technocare.az/", "items": [], "kind": kind})
            if path == "/api/v1/content/projects":
                return self.json_response({"items": [], "page": 1, "pageSize": 12, "total": 0, "totalPages": 1})
            if path == "/api/v1/shop/products":
                return self.products(query)
            if path.startswith("/api/v1/shop/products/"):
                product_id = path.rsplit("/", 1)[-1]
                item, _ = woo_json(f"products/{product_id}")
                return self.json_response(map_product(item))
            if path == "/api/v1/shop/suggestions":
                limit = min(10, max(1, int(first(query, "limit", "5"))))
                items, _ = woo_json("products", {"search": first(query, "q", ""), "per_page": limit})
                mapped = [map_product(item) for item in items]
                return self.json_response({"items": [{"id": item["id"], "name": item["name"], "sku": item["sku"], "brand": item["brand"], "imageUrl": item["images"][0] if item["images"] else "", "price": item["price"], "onSale": item["onSale"], "inStock": item["inStock"]} for item in mapped]})
            if path == "/api/v1/shop/categories":
                items, _ = woo_json("products/categories", {"per_page": 100})
                return self.json_response({"items": [map_taxonomy(item) for item in items]})
            if path == "/api/v1/shop/brands":
                return self.json_response({"items": []})
            if path.startswith("/api/auth/") and len(path.rsplit("/", 1)[-1]) > 5:
                user = next(iter(USERS.values()))
                return self.json_response(public_user(user, token=False))
            if path in {"/health", "/health/live", "/health/ready"}:
                return self.json_response({"status": "local-preview"})
            return self.error_response(404, "Lokal preview endpoint-i tapılmadı.")
        except (urllib.error.URLError, TimeoutError, ValueError) as error:
            return self.error_response(502, f"Canlı kataloq hazırda əlçatan deyil: {type(error).__name__}")

    def do_POST(self) -> None:  # noqa: N802
        path = urllib.parse.urlparse(self.path).path.lower().rstrip("/")
        body = self.read_json()
        if body is None:
            return
        if path == "/api/auth/register":
            email = str(body.get("email", "")).strip().lower()
            if not email or email in USERS:
                return self.error_response(409, "Bu e-poçt artıq qeydiyyatdan keçib.")
            USERS[email] = {
                "id": f"local-{len(USERS) + 1}",
                "name": str(body.get("name", "")).strip(),
                "email": email,
                "phone": str(body.get("phone", "")).strip(),
                "password": str(body.get("password", "")),
                "verified": False,
            }
            return self.json_response({"message": "Qeydiyyat tamamlandı. Lokal doğrulama kodu: 123456", "developmentCode": VERIFY_CODE})
        if path == "/api/auth/verify-email":
            user = USERS.get(str(body.get("email", "")).strip().lower())
            if user is None or str(body.get("code", "")) != VERIFY_CODE:
                return self.error_response(400, "Təsdiq kodu yanlışdır.")
            user["verified"] = True
            return self.json_response({"message": "E-poçt uğurla təsdiqləndi."})
        if path in {"/api/auth/resend-code", "/api/auth/resend-verification"}:
            return self.json_response({"message": "Yeni lokal kod yaradıldı.", "developmentCode": VERIFY_CODE})
        if path == "/api/auth/login":
            user = USERS.get(str(body.get("email", "")).strip().lower())
            if user is None or user.get("password") != body.get("password"):
                return self.error_response(401, "E-poçt və ya şifrə yanlışdır.")
            if not user.get("verified"):
                return self.error_response(403, "E-poçt təsdiqlənməyib. 123456 kodunu daxil edin.")
            return self.json_response(public_user(user, token=True))
        if path == "/api/auth/forgot-password":
            return self.json_response({"message": "Lokal bərpa kodu: reset123", "developmentCode": "reset123"})
        if path == "/api/auth/reset-password":
            user = USERS.get(str(body.get("email", "")).strip().lower())
            if user is None or body.get("token") != "reset123":
                return self.error_response(400, "E-poçt və ya bərpa kodu yanlışdır.")
            user["password"] = str(body.get("newPassword", ""))
            return self.json_response({"message": "Şifrə uğurla yeniləndi."})
        if path in {"/api/serviceapplications", "/api/educationapplications"}:
            return self.json_response({"id": "local-application", "status": "Pending", "recipient": "info@technocare.az", **body}, status=201)
        return self.error_response(404, "Lokal preview endpoint-i tapılmadı.")

    def do_PUT(self) -> None:  # noqa: N802
        if self.path.lower().startswith("/api/notifications/"):
            return self.json_response({}, status=204)
        return self.error_response(404, "Lokal preview endpoint-i tapılmadı.")

    def do_DELETE(self) -> None:  # noqa: N802
        if self.path.lower().rstrip("/") == "/api/auth/delete-my-account":
            return self.json_response({}, status=204)
        return self.error_response(404, "Lokal preview endpoint-i tapılmadı.")

    def products(self, query: dict[str, list[str]]) -> None:
        page = max(1, int(first(query, "page", "1")))
        page_size = min(100, max(1, int(first(query, "pageSize", "20"))))
        params: dict[str, object] = {"page": page, "per_page": page_size}
        search = first(query, "q", "")
        if search:
            params["search"] = search
        category = first(query, "category", "")
        if category:
            params["category"] = category
        items, headers = woo_json("products", params)
        total = int(headers.get("X-WP-Total", len(items)))
        total_pages = int(headers.get("X-WP-TotalPages", max(1, (total + page_size - 1) // page_size)))
        mapped = [map_product(item) for item in items]
        self.json_response({"items": mapped, "page": page, "pageSize": page_size, "total": total, "totalPages": total_pages, "facets": {"categories": [], "brands": [], "minPrice": None, "maxPrice": None, "inStockCount": sum(1 for item in mapped if item["inStock"])}})

    def read_json(self) -> dict[str, object] | None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
            value = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
            if not isinstance(value, dict):
                raise ValueError
            return value
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
            self.error_response(400, "JSON məlumatı düzgün deyil.")
            return None

    def json_response(self, payload: object, status: int = 200) -> None:
        data = b"" if status == 204 else json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if data:
            self.wfile.write(data)

    def error_response(self, status: int, message: str) -> None:
        self.json_response({"message": message}, status=status)


def first(query: dict[str, list[str]], key: str, default: str) -> str:
    values = query.get(key) or query.get(key.lower())
    return values[0] if values else default


def map_taxonomy(item: dict[str, object]) -> dict[str, object]:
    image = item.get("image") if isinstance(item.get("image"), dict) else {}
    return {"id": int(item.get("id", 0)), "name": clean_text(item.get("name")), "slug": str(item.get("slug", "")), "parentId": int(item.get("parent", 0)), "count": int(item.get("count", 0)), "imageUrl": str(image.get("src", ""))}


def public_user(user: dict[str, object], token: bool) -> dict[str, object]:
    return {"id": user["id"], "name": user["name"], "email": user["email"], "phone": user["phone"], "role": "User", "emailVerified": bool(user["verified"]), **({"token": TOKEN} if token else {})}


if __name__ == "__main__":
    print(f"Technocare local preview API: http://{HOST}:{PORT}/api")
    print("Demo: demo@technocare.az / Technocare123! | verification: 123456")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
