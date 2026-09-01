# Technocare App API

WordPress plugin that turns the live technocare.az Elementor/WooCommerce content into stable JSON for the mobile backend.

## Requirements

- WordPress with PHP 8.0+
- WooCommerce
- PHP DOM extension (catalog fallback blocks remain available without DOM, but full page extraction requires it)

## Install

Copy this directory to `wp-content/plugins/technocare-app-api`, define `TECHNOCARE_APP_SHARED_SECRET` in `wp-config.php`, activate the plugin, then configure the homepage and supported section order under **Settings → Technocare App**.

The service and education collections are sourced from the published `/xidmetler` and `/tedris` landing pages and the published pages they link to. Projects are extracted from the live `/layiheler` page first, with the `portfolio` post type as fallback. Project search is applied before pagination so results are never limited to the first 12 loaded cards.

The plugin maintains `wp_technocare_product_search`, a denormalized WooCommerce search index containing SKU, name, brand, categories, Azerbaijani-normalized text, stock, price, and popularity. Initial activation schedules 200-product WP-Cron batches. Product, stock, brand, and category changes update the corresponding row immediately. Both full search and `/suggestions` rank exact SKU, SKU prefix, exact/name prefix, brand/category, then description.

## Caching and security

Public GET responses include `Cache-Control`, `ETag`, and `Last-Modified`. Internal POST requests require a timestamp, one-time nonce, and SHA-256 HMAC over `timestamp.nonce.body`. Checkout tokens expire after five minutes and are deleted as soon as they are opened.

## Syntax check

```bash
php -l technocare-app-api.php
```
