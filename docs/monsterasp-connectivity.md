# MonsterASP connectivity checks

The production mobile API is `https://technocare-live-api.runasp.net/api`.
HTTPS between the mobile app and MonsterASP is separate from the gateway's
outbound HTTPS connection to `https://technocare.az`.

## Verified status on 30 October 2026

Anonymous requests with normal certificate validation returned:

| Route | Result |
| --- | --- |
| `/health/live` | HTTP 200, public-website mode |
| `/api/v1/content/home` | HTTP 502, upstream website unavailable |
| `/api/v1/shop/products?page=1&pageSize=1` | HTTP 502, upstream website unavailable |

The liveness route confirms that the gateway process is running; it does not
prove that the app can retrieve website content. The current deployment still
fails the production release gate.

## Latest hosting support response

In ticket `O91X-Y34N-Y64L`, MonsterASP confirmed HTTPS activation. Its latest
reply on 30 October says the hosting website and database are working from
its side and identifies where to find the site's outbound public IP:

**Control Panel > Websites > select website > Overview > DNS Status**.

Support says that address is currently fixed but may change in the future.
It suggests allowlisting that address at the destination website. This is a
possible next diagnostic step, not confirmation that `technocare.az` is
blocking the address or that the gateway's upstream connection is repaired.

The website owner or hosting administrator can check firewall/WAF logs for
requests from that address and, if appropriate, allow the required public
website/API requests. Recheck the outbound address if connectivity later fails.
Do not disable certificate validation or revert the mobile app to HTTP.

After any hosting or website-side change, run from the repository root:

```powershell
$env:API_BASE_URL = 'https://technocare-live-api.runasp.net/api'
python scripts/check-release-api.py
```

Only a successful homepage and catalogue check clears the API release gate.
