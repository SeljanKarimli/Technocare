<?php
/**
 * Plugin Name: Technocare App API
 * Description: Versioned, mobile-friendly content, catalogue and checkout endpoints for the Technocare Flutter app.
 * Version: 1.0.0
 * Requires PHP: 8.0
 * Author: Technocare
 */

if (!defined('ABSPATH')) {
    exit;
}

final class Technocare_App_API
{
    private const NAMESPACE = 'technocare-app/v1';
    private const HOME_PAGE_OPTION = 'technocare_app_home_page_id';
    private const SECTION_CONFIG_OPTION = 'technocare_app_section_config';
    private const SESSION_TTL = 300;

    /** @var string[] */
    private const SECTION_TYPES = [
        'hero',
        'about',
        'mission',
        'categories',
        'brands',
        'best_sellers',
        'services',
        'quality',
        'projects',
        'partners',
        'contact',
    ];

    public static function boot(): void
    {
        add_action('rest_api_init', [self::class, 'register_routes']);
        add_action('admin_menu', [self::class, 'register_settings_page']);
        add_action('admin_init', [self::class, 'register_settings']);
        add_action('template_redirect', [self::class, 'restore_checkout_session']);
        add_action('woocommerce_checkout_create_order', [self::class, 'attach_app_user_to_order'], 10, 2);
        add_action('woocommerce_thankyou', [self::class, 'render_app_return'], 30);
        add_filter('woocommerce_get_cancel_order_url_raw', [self::class, 'app_cancel_url'], 10, 2);
    }

    public static function register_routes(): void
    {
        register_rest_route(self::NAMESPACE, '/home', [
            'methods' => WP_REST_Server::READABLE,
            'callback' => [self::class, 'home'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NAMESPACE, '/products', [
            'methods' => WP_REST_Server::READABLE,
            'callback' => [self::class, 'products'],
            'permission_callback' => '__return_true',
            'args' => self::product_query_args(),
        ]);

        register_rest_route(self::NAMESPACE, '/products/(?P<id>\d+)', [
            'methods' => WP_REST_Server::READABLE,
            'callback' => [self::class, 'product'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NAMESPACE, '/categories', [
            'methods' => WP_REST_Server::READABLE,
            'callback' => [self::class, 'categories'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NAMESPACE, '/brands', [
            'methods' => WP_REST_Server::READABLE,
            'callback' => [self::class, 'brands'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NAMESPACE, '/projects', [
            'methods' => WP_REST_Server::READABLE,
            'callback' => [self::class, 'projects'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NAMESPACE, '/services', [
            'methods' => WP_REST_Server::READABLE,
            'callback' => static fn(WP_REST_Request $_request): WP_REST_Response => self::page_collection('xidmetler'),
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NAMESPACE, '/education', [
            'methods' => WP_REST_Server::READABLE,
            'callback' => static fn(WP_REST_Request $_request): WP_REST_Response => self::page_collection('tedris'),
            'permission_callback' => '__return_true',
        ]);

        register_rest_route(self::NAMESPACE, '/checkout-session', [
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => [self::class, 'checkout_session'],
            'permission_callback' => [self::class, 'verify_internal_request'],
        ]);

        register_rest_route(self::NAMESPACE, '/orders', [
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => [self::class, 'orders'],
            'permission_callback' => [self::class, 'verify_internal_request'],
        ]);
    }

    /** @return array<string, array<string, mixed>> */
    private static function product_query_args(): array
    {
        return [
            'q' => ['sanitize_callback' => 'sanitize_text_field', 'default' => ''],
            'page' => ['sanitize_callback' => 'absint', 'default' => 1],
            'pageSize' => ['sanitize_callback' => 'absint', 'default' => 20],
            'category' => ['sanitize_callback' => 'absint'],
            'brand' => ['sanitize_callback' => 'sanitize_title'],
            'inStock' => ['sanitize_callback' => 'rest_sanitize_boolean'],
            'minPrice' => ['sanitize_callback' => [self::class, 'sanitize_decimal']],
            'maxPrice' => ['sanitize_callback' => [self::class, 'sanitize_decimal']],
            'sort' => ['sanitize_callback' => 'sanitize_key', 'default' => 'relevance'],
        ];
    }

    public static function sanitize_decimal($value): ?float
    {
        return is_numeric($value) ? (float) $value : null;
    }

    public static function home(WP_REST_Request $request): WP_REST_Response
    {
        $page_id = (int) get_option(self::HOME_PAGE_OPTION, (int) get_option('page_on_front'));
        $page = get_post($page_id);
        if (!$page instanceof WP_Post || $page->post_status !== 'publish') {
            return new WP_REST_Response(['message' => 'Homepage is not configured.'], 503);
        }

        $html = apply_filters('the_content', $page->post_content);
        $sections = self::extract_home_sections($html);
        $payload = [
            'schemaVersion' => 1,
            'updatedAt' => get_post_modified_time(DATE_ATOM, true, $page),
            'sourceUrl' => get_permalink($page),
            'sections' => $sections,
        ];

        return self::cacheable_response($payload, (int) get_post_modified_time('U', true, $page));
    }

    /** @return array<int, array<string, mixed>> */
    private static function extract_home_sections(string $html): array
    {
        if (trim($html) === '') {
            return [];
        }

        if (!class_exists('DOMDocument')) {
            return self::catalog_fallback_sections();
        }

        $document = new DOMDocument('1.0', 'UTF-8');
        libxml_use_internal_errors(true);
        $document->loadHTML('<?xml encoding="UTF-8">' . $html, LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD);
        libxml_clear_errors();
        $xpath = new DOMXPath($document);
        $containers = $xpath->query("//*[contains(concat(' ', normalize-space(@class), ' '), ' e-parent ')]");
        if (!$containers || $containers->length === 0) {
            $containers = $xpath->query('//section|//main/*');
        }

        $config = self::section_config();
        $detected = [];
        $source_order = 0;
        foreach ($containers ?: [] as $container) {
            if (!$container instanceof DOMElement) {
                continue;
            }
            $text = self::clean_text($container->textContent ?? '');
            if ($text === '') {
                continue;
            }
            $type = self::classify_section($text, $source_order);
            $source_order++;
            if ($type === null || isset($detected[$type])) {
                continue;
            }
            $item = self::section_from_node($xpath, $container, $type);
            $item['sourceOrder'] = $source_order;
            $detected[$type] = $item;
        }

        if (function_exists('wc_get_products')) {
            $detected['categories'] = $detected['categories'] ?? self::fallback_section('categories', 'Məhsul kateqoriyaları');
            $detected['categories']['items'] = array_slice(self::get_categories(), 0, 12);
            $detected['brands'] = $detected['brands'] ?? self::fallback_section('brands', 'Brendlər');
            $detected['brands']['items'] = array_slice(self::get_brands(), 0, 20);
            $detected['best_sellers'] = $detected['best_sellers'] ?? self::fallback_section('best_sellers', 'Ən çox satılan məhsullar');
            $best_sellers = wc_get_products([
                'status' => 'publish',
                'limit' => 8,
                'orderby' => 'popularity',
                'order' => 'DESC',
            ]);
            $detected['best_sellers']['items'] = array_values(array_map([self::class, 'map_product'], $best_sellers));
        }

        $sections = [];
        foreach (self::SECTION_TYPES as $default_order => $type) {
            if (!isset($detected[$type])) {
                continue;
            }
            $entry = $config[$type] ?? ['enabled' => true, 'order' => $default_order];
            if (empty($entry['enabled'])) {
                continue;
            }
            $detected[$type]['order'] = isset($entry['order']) ? (int) $entry['order'] : $default_order;
            $sections[] = $detected[$type];
        }

        usort($sections, static fn(array $a, array $b): int => ($a['order'] ?? 0) <=> ($b['order'] ?? 0));
        return array_values($sections);
    }

    /** @return array<int, array<string, mixed>> */
    private static function catalog_fallback_sections(): array
    {
        if (!function_exists('wc_get_products')) {
            return [];
        }
        $sections = [];
        $categories = self::fallback_section('categories', 'Məhsul kateqoriyaları');
        $categories['items'] = array_slice(self::get_categories(), 0, 12);
        $sections[] = $categories + ['order' => 3];
        $brands = self::fallback_section('brands', 'Brendlər');
        $brands['items'] = array_slice(self::get_brands(), 0, 20);
        $sections[] = $brands + ['order' => 4];
        $products = self::fallback_section('best_sellers', 'Ən çox satılan məhsullar');
        $products['items'] = array_map([self::class, 'map_product'], wc_get_products([
            'status' => 'publish',
            'limit' => 8,
            'orderby' => 'popularity',
            'order' => 'DESC',
        ]));
        $sections[] = $products + ['order' => 5];
        return $sections;
    }

    /** @return array<string, mixed> */
    private static function fallback_section(string $type, string $title): array
    {
        return [
            'id' => $type,
            'type' => $type,
            'title' => $title,
            'eyebrow' => '',
            'body' => '',
            'images' => [],
            'links' => [],
            'metrics' => [],
            'items' => [],
        ];
    }

    private static function classify_section(string $text, int $index): ?string
    {
        $value = mb_strtolower($text, 'UTF-8');
        $rules = [
            'contact' => ['bizimlə əlaqə', 'əlaqə saxlayın', 'layihəniz var'],
            'partners' => ['partnyorlarımız', 'müştərilərimiz və partnyorlarımız'],
            'projects' => ['layihələrimiz', 'hər növ sənaye layihəsi'],
            'quality' => ['niyə bizi seçməlisiniz', 'müasir texnoloji həllər'],
            'services' => ['xidmətlərimiz', 'peşəkar həllər'],
            'best_sellers' => ['ən çox satılan', 'çox satılan məhsullar'],
            'brands' => ['brendlər'],
            'categories' => ['məhsul kateqoriyaları', 'məhsullar üzrə kateqoriyalar'],
            'mission' => ['missiyamız', 'üstünlüklərimiz', 'məqsədimiz'],
            'about' => ['xoş gəlmisiniz', '13+ il təcrübə', '100+ uğurlu layihə'],
        ];

        foreach ($rules as $type => $needles) {
            foreach ($needles as $needle) {
                if (str_contains($value, $needle)) {
                    return $type;
                }
            }
        }
        return $index === 0 ? 'hero' : null;
    }

    /** @return array<string, mixed> */
    private static function section_from_node(DOMXPath $xpath, DOMElement $node, string $type): array
    {
        $headings = [];
        foreach ($xpath->query('.//h1|.//h2|.//h3|.//h4', $node) ?: [] as $heading) {
            $value = self::clean_text($heading->textContent ?? '');
            if ($value !== '' && !in_array($value, $headings, true)) {
                $headings[] = $value;
            }
        }

        $paragraphs = [];
        foreach ($xpath->query('.//p', $node) ?: [] as $paragraph) {
            $value = self::clean_text($paragraph->textContent ?? '');
            if (mb_strlen($value) > 20 && !in_array($value, $paragraphs, true)) {
                $paragraphs[] = $value;
            }
        }

        $images = [];
        foreach ($xpath->query('.//img', $node) ?: [] as $image) {
            if (!$image instanceof DOMElement) {
                continue;
            }
            $url = $image->getAttribute('data-lazy-src') ?: $image->getAttribute('src');
            if ($url !== '' && !str_starts_with($url, 'data:') && !in_array($url, $images, true)) {
                $images[] = esc_url_raw($url);
            }
        }

        $links = [];
        foreach ($xpath->query('.//a[@href]', $node) ?: [] as $anchor) {
            if (!$anchor instanceof DOMElement) {
                continue;
            }
            $label = self::clean_text($anchor->textContent ?? '');
            $url = esc_url_raw($anchor->getAttribute('href'));
            if ($label !== '' && $url !== '') {
                $links[] = ['label' => $label, 'url' => $url];
            }
        }

        $metrics = [];
        if (preg_match_all('/\b\d{1,4}\s*[+%]/u', $node->textContent ?? '', $matches)) {
            foreach (array_unique($matches[0]) as $metric) {
                $metrics[] = ['value' => self::clean_text($metric), 'label' => ''];
            }
        }

        return [
            'id' => $type,
            'type' => $type,
            'eyebrow' => $headings[0] ?? '',
            'title' => $headings[1] ?? ($headings[0] ?? ''),
            'body' => implode("\n\n", array_slice($paragraphs, 0, 4)),
            'images' => array_slice($images, 0, 16),
            'links' => array_slice($links, 0, 12),
            'metrics' => array_slice($metrics, 0, 6),
            'items' => [],
        ];
    }

    private static function clean_text(string $value): string
    {
        return trim(preg_replace('/\s+/u', ' ', html_entity_decode(wp_strip_all_tags($value), ENT_QUOTES | ENT_HTML5, 'UTF-8')) ?? '');
    }

    public static function products(WP_REST_Request $request): WP_REST_Response
    {
        if (!function_exists('wc_get_product')) {
            return new WP_REST_Response(['message' => 'WooCommerce is unavailable.'], 503);
        }

        $page = max(1, (int) $request->get_param('page'));
        $page_size = min(60, max(1, (int) $request->get_param('pageSize')));
        $query = trim((string) $request->get_param('q'));
        $args = [
            'post_type' => 'product',
            'post_status' => 'publish',
            'paged' => $page,
            'posts_per_page' => $page_size,
            'ignore_sticky_posts' => true,
            'tax_query' => [],
            'meta_query' => [],
        ];

        if ($query !== '') {
            $args['s'] = $query;
            $args['technocare_search'] = $query;
            add_filter('posts_search', [self::class, 'extend_product_search'], 20, 2);
            add_filter('posts_clauses', [self::class, 'rank_product_search'], 20, 2);
        }

        $category = (int) $request->get_param('category');
        if ($category > 0) {
            $args['tax_query'][] = ['taxonomy' => 'product_cat', 'field' => 'term_id', 'terms' => [$category]];
        }
        $brand = sanitize_title((string) $request->get_param('brand'));
        if ($brand !== '' && taxonomy_exists('pa_brand')) {
            $args['tax_query'][] = ['taxonomy' => 'pa_brand', 'field' => 'slug', 'terms' => [$brand]];
        }
        if ($request->has_param('inStock') && rest_sanitize_boolean($request->get_param('inStock'))) {
            $args['meta_query'][] = ['key' => '_stock_status', 'value' => 'instock'];
        }
        $min_price = self::sanitize_decimal($request->get_param('minPrice'));
        $max_price = self::sanitize_decimal($request->get_param('maxPrice'));
        if ($min_price !== null || $max_price !== null) {
            $args['meta_query'][] = [
                'key' => '_price',
                'value' => [$min_price ?? 0, $max_price ?? PHP_INT_MAX],
                'compare' => 'BETWEEN',
                'type' => 'DECIMAL(20,6)',
            ];
        }

        self::apply_sort($args, (string) $request->get_param('sort'), $query !== '');
        $wp_query = new WP_Query($args);
        if ($query !== '') {
            remove_filter('posts_search', [self::class, 'extend_product_search'], 20);
            remove_filter('posts_clauses', [self::class, 'rank_product_search'], 20);
        }

        $items = [];
        foreach ($wp_query->posts as $post) {
            $product = wc_get_product($post->ID);
            if ($product) {
                $items[] = self::map_product($product);
            }
        }

        $payload = [
            'items' => $items,
            'page' => $page,
            'pageSize' => $page_size,
            'total' => (int) $wp_query->found_posts,
            'totalPages' => (int) $wp_query->max_num_pages,
            'facets' => [
                'categories' => array_slice(self::get_categories(), 0, 150),
                'brands' => array_slice(self::get_brands(), 0, 100),
            ] + self::get_catalog_stats(),
        ];
        return self::cacheable_response($payload, time(), 300);
    }

    public static function extend_product_search(string $search, WP_Query $query): string
    {
        global $wpdb;
        $term = $query->get('technocare_search');
        if (!$term || !$query->is_search()) {
            return $search;
        }
        $like = '%' . $wpdb->esc_like((string) $term) . '%';
        return $wpdb->prepare(
            " AND ({$wpdb->posts}.post_title LIKE %s OR {$wpdb->posts}.post_excerpt LIKE %s OR {$wpdb->posts}.post_content LIKE %s OR EXISTS (SELECT 1 FROM {$wpdb->postmeta} tcsku WHERE tcsku.post_id = {$wpdb->posts}.ID AND tcsku.meta_key = '_sku' AND tcsku.meta_value LIKE %s) OR EXISTS (SELECT 1 FROM {$wpdb->term_relationships} tcr JOIN {$wpdb->term_taxonomy} tct ON tct.term_taxonomy_id = tcr.term_taxonomy_id JOIN {$wpdb->terms} tcterm ON tcterm.term_id = tct.term_id WHERE tcr.object_id = {$wpdb->posts}.ID AND tct.taxonomy IN ('product_cat','pa_brand') AND tcterm.name LIKE %s)) ",
            $like,
            $like,
            $like,
            $like,
            $like
        );
    }

    /** @param array<string, string> $clauses @return array<string, string> */
    public static function rank_product_search(array $clauses, WP_Query $query): array
    {
        global $wpdb;
        $term = trim((string) $query->get('technocare_search'));
        if ($term === '') {
            return $clauses;
        }
        $exact = esc_sql($term);
        $prefix = esc_sql($wpdb->esc_like($term) . '%');
        $contains = esc_sql('%' . $wpdb->esc_like($term) . '%');
        $clauses['join'] .= " LEFT JOIN {$wpdb->postmeta} tc_rank_sku ON (tc_rank_sku.post_id = {$wpdb->posts}.ID AND tc_rank_sku.meta_key = '_sku') ";
        $clauses['orderby'] = "CASE
            WHEN tc_rank_sku.meta_value = '{$exact}' THEN 0
            WHEN tc_rank_sku.meta_value LIKE '{$prefix}' THEN 1
            WHEN {$wpdb->posts}.post_title = '{$exact}' THEN 2
            WHEN {$wpdb->posts}.post_title LIKE '{$prefix}' THEN 3
            WHEN EXISTS (SELECT 1 FROM {$wpdb->term_relationships} rank_rel JOIN {$wpdb->term_taxonomy} rank_tax ON rank_tax.term_taxonomy_id = rank_rel.term_taxonomy_id JOIN {$wpdb->terms} rank_term ON rank_term.term_id = rank_tax.term_id WHERE rank_rel.object_id = {$wpdb->posts}.ID AND rank_tax.taxonomy IN ('product_cat','pa_brand') AND rank_term.name LIKE '{$contains}') THEN 4
            WHEN {$wpdb->posts}.post_excerpt LIKE '{$contains}' OR {$wpdb->posts}.post_content LIKE '{$contains}' THEN 5
            ELSE 6 END ASC, {$wpdb->posts}.post_date DESC";
        $clauses['groupby'] = "{$wpdb->posts}.ID";
        return $clauses;
    }

    /** @param array<string, mixed> $args */
    private static function apply_sort(array &$args, string $sort, bool $has_query): void
    {
        if ($has_query && ($sort === '' || $sort === 'relevance')) {
            return;
        }
        switch ($sort) {
            case 'price_asc':
                $args['meta_key'] = '_price';
                $args['orderby'] = 'meta_value_num';
                $args['order'] = 'ASC';
                break;
            case 'price_desc':
                $args['meta_key'] = '_price';
                $args['orderby'] = 'meta_value_num';
                $args['order'] = 'DESC';
                break;
            case 'popularity':
                $args['meta_key'] = 'total_sales';
                $args['orderby'] = 'meta_value_num';
                $args['order'] = 'DESC';
                break;
            case 'name':
                $args['orderby'] = 'title';
                $args['order'] = 'ASC';
                break;
            default:
                $args['orderby'] = 'date';
                $args['order'] = 'DESC';
        }
    }

    public static function product(WP_REST_Request $request): WP_REST_Response
    {
        $product = function_exists('wc_get_product') ? wc_get_product((int) $request['id']) : false;
        if (!$product || $product->get_status() !== 'publish') {
            return new WP_REST_Response(['message' => 'Product not found.'], 404);
        }
        return self::cacheable_response(self::map_product($product), (int) get_post_modified_time('U', true, $product->get_id()));
    }

    /** @return array<string, mixed> */
    private static function map_product(WC_Product $product): array
    {
        $images = [];
        foreach (array_unique(array_filter(array_merge([$product->get_image_id()], $product->get_gallery_image_ids()))) as $image_id) {
            $url = wp_get_attachment_image_url((int) $image_id, 'large');
            if ($url) {
                $images[] = $url;
            }
        }
        $categories = wp_get_post_terms($product->get_id(), 'product_cat', ['fields' => 'all']);
        $brands = taxonomy_exists('pa_brand') ? wp_get_post_terms($product->get_id(), 'pa_brand', ['fields' => 'all']) : [];
        return [
            'id' => $product->get_id(),
            'name' => self::clean_text($product->get_name()),
            'slug' => $product->get_slug(),
            'sku' => $product->get_sku(),
            'brand' => !is_wp_error($brands) && isset($brands[0]) ? self::clean_text($brands[0]->name) : '',
            'categories' => is_wp_error($categories) ? [] : array_map(static fn(WP_Term $term): array => [
                'id' => $term->term_id,
                'name' => self::clean_text($term->name),
                'slug' => $term->slug,
            ], $categories),
            'shortDescription' => self::clean_text($product->get_short_description()),
            'description' => self::clean_text($product->get_description()),
            'images' => $images,
            'price' => $product->get_price() === '' ? null : (float) $product->get_price(),
            'regularPrice' => $product->get_regular_price() === '' ? null : (float) $product->get_regular_price(),
            'salePrice' => $product->get_sale_price() === '' ? null : (float) $product->get_sale_price(),
            'currencyCode' => get_woocommerce_currency(),
            'currencySymbol' => html_entity_decode(get_woocommerce_currency_symbol(), ENT_QUOTES | ENT_HTML5, 'UTF-8'),
            'onSale' => $product->is_on_sale(),
            'inStock' => $product->is_in_stock(),
            'stockStatus' => $product->get_stock_status(),
            'purchasable' => $product->is_purchasable(),
            'permalink' => get_permalink($product->get_id()),
        ];
    }

    public static function categories(): WP_REST_Response
    {
        return self::cacheable_response(['items' => self::get_categories()], time(), 300);
    }

    /** @return array<int, array<string, mixed>> */
    private static function get_categories(): array
    {
        $terms = get_terms(['taxonomy' => 'product_cat', 'hide_empty' => true, 'orderby' => 'name']);
        if (is_wp_error($terms)) {
            return [];
        }
        return array_values(array_map(static function (WP_Term $term): array {
            $thumbnail_id = (int) get_term_meta($term->term_id, 'thumbnail_id', true);
            return [
                'id' => $term->term_id,
                'name' => self::clean_text($term->name),
                'slug' => $term->slug,
                'parentId' => $term->parent,
                'count' => $term->count,
                'imageUrl' => $thumbnail_id ? (wp_get_attachment_image_url($thumbnail_id, 'medium') ?: '') : '',
            ];
        }, $terms));
    }

    public static function brands(): WP_REST_Response
    {
        return self::cacheable_response(['items' => self::get_brands()], time(), 300);
    }

    public static function projects(WP_REST_Request $request): WP_REST_Response
    {
        $page = max(1, absint($request->get_param('page') ?: 1));
        $page_size = min(30, max(1, absint($request->get_param('pageSize') ?: 12)));
        $query = new WP_Query([
            'post_type' => post_type_exists('portfolio') ? 'portfolio' : 'post',
            'post_status' => 'publish',
            'paged' => $page,
            'posts_per_page' => $page_size,
            'orderby' => 'menu_order date',
            'order' => 'DESC',
        ]);
        $items = array_map(static function (WP_Post $post): array {
            $content = apply_filters('the_content', $post->post_content);
            $images = [];
            if (class_exists('DOMDocument') && trim($content) !== '') {
                $document = new DOMDocument('1.0', 'UTF-8');
                libxml_use_internal_errors(true);
                $document->loadHTML('<?xml encoding="UTF-8">' . $content, LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD);
                libxml_clear_errors();
                foreach ($document->getElementsByTagName('img') as $image) {
                    $url = $image->getAttribute('src');
                    if ($url !== '' && !in_array($url, $images, true)) {
                        $images[] = esc_url_raw($url);
                    }
                }
            }
            $featured = get_the_post_thumbnail_url($post, 'large') ?: '';
            if ($featured !== '') {
                array_unshift($images, $featured);
            }
            return [
                'id' => $post->ID,
                'name' => self::clean_text(get_the_title($post)),
                'description' => self::clean_text(get_the_excerpt($post)),
                'content' => self::clean_text(wp_strip_all_tags($content)),
                'imageUrl' => $images[0] ?? '',
                'images' => array_values(array_unique($images)),
                'url' => get_permalink($post),
                'updatedAt' => get_post_modified_time(DATE_ATOM, true, $post),
            ];
        }, $query->posts);

        return self::cacheable_response([
            'items' => $items,
            'page' => $page,
            'pageSize' => $page_size,
            'total' => (int) $query->found_posts,
            'totalPages' => (int) $query->max_num_pages,
        ], time(), 300);
    }

    private static function page_collection(string $landing_slug): WP_REST_Response
    {
        $landing = get_page_by_path($landing_slug, OBJECT, 'page');
        if (!$landing instanceof WP_Post || $landing->post_status !== 'publish') {
            return new WP_REST_Response(['message' => 'Content page is not configured.'], 503);
        }
        $content = apply_filters('the_content', $landing->post_content);
        $page_ids = [];
        if (class_exists('DOMDocument')) {
            $document = new DOMDocument('1.0', 'UTF-8');
            libxml_use_internal_errors(true);
            $document->loadHTML('<?xml encoding="UTF-8">' . $content, LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD);
            libxml_clear_errors();
            foreach ($document->getElementsByTagName('a') as $anchor) {
                $page_id = url_to_postid($anchor->getAttribute('href'));
                if ($page_id > 0 && $page_id !== $landing->ID && get_post_type($page_id) === 'page') {
                    $page_ids[] = $page_id;
                }
            }
        }
        $items = [];
        foreach (array_values(array_unique($page_ids)) as $page_id) {
            $page = get_post($page_id);
            if ($page instanceof WP_Post && $page->post_status === 'publish') {
                $items[] = self::map_content_page($page);
            }
        }
        return self::cacheable_response([
            'schemaVersion' => 1,
            'updatedAt' => get_post_modified_time(DATE_ATOM, true, $landing),
            'sourceUrl' => get_permalink($landing),
            'items' => $items,
        ], (int) get_post_modified_time('U', true, $landing), 300);
    }

    /** @return array<string, mixed> */
    private static function map_content_page(WP_Post $page): array
    {
        $html = apply_filters('the_content', $page->post_content);
        $images = [];
        $featured = get_the_post_thumbnail_url($page, 'large') ?: '';
        if ($featured !== '') {
            $images[] = $featured;
        }
        if (class_exists('DOMDocument') && trim($html) !== '') {
            $document = new DOMDocument('1.0', 'UTF-8');
            libxml_use_internal_errors(true);
            $document->loadHTML('<?xml encoding="UTF-8">' . $html, LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD);
            libxml_clear_errors();
            foreach ($document->getElementsByTagName('img') as $image) {
                $url = esc_url_raw($image->getAttribute('src'));
                if ($url !== '' && !in_array($url, $images, true)) {
                    $images[] = $url;
                }
            }
        }
        $plain = self::clean_text(wp_strip_all_tags($html));
        return [
            'id' => $page->ID,
            'title' => self::clean_text(get_the_title($page)),
            'summary' => self::clean_text(get_the_excerpt($page)) ?: mb_substr($plain, 0, 280),
            'body' => $plain,
            'imageUrl' => $images[0] ?? '',
            'images' => $images,
            'url' => get_permalink($page),
            'updatedAt' => get_post_modified_time(DATE_ATOM, true, $page),
        ];
    }

    /** @return array<int, array<string, mixed>> */
    private static function get_brands(): array
    {
        if (!taxonomy_exists('pa_brand')) {
            return [];
        }
        $terms = get_terms(['taxonomy' => 'pa_brand', 'hide_empty' => true, 'orderby' => 'name']);
        if (is_wp_error($terms)) {
            return [];
        }
        return array_values(array_map(static fn(WP_Term $term): array => [
            'id' => $term->term_id,
            'name' => self::clean_text($term->name),
            'slug' => $term->slug,
            'count' => $term->count,
        ], $terms));
    }

    /** @return array{minPrice: float|null, maxPrice: float|null, inStockCount: int} */
    private static function get_catalog_stats(): array
    {
        global $wpdb;
        $table = $wpdb->prefix . 'wc_product_meta_lookup';
        $row = $wpdb->get_row("SELECT MIN(min_price) AS min_price, MAX(max_price) AS max_price, SUM(stock_status = 'instock') AS in_stock_count FROM {$table}", ARRAY_A);
        return [
            'minPrice' => isset($row['min_price']) ? (float) $row['min_price'] : null,
            'maxPrice' => isset($row['max_price']) ? (float) $row['max_price'] : null,
            'inStockCount' => isset($row['in_stock_count']) ? (int) $row['in_stock_count'] : 0,
        ];
    }

    public static function verify_internal_request(WP_REST_Request $request): bool
    {
        $secret = defined('TECHNOCARE_APP_SHARED_SECRET') ? (string) TECHNOCARE_APP_SHARED_SECRET : '';
        $timestamp = (string) $request->get_header('x-technocare-timestamp');
        $nonce = sanitize_key((string) $request->get_header('x-technocare-nonce'));
        $signature = (string) $request->get_header('x-technocare-signature');
        if ($secret === '' || $timestamp === '' || $nonce === '' || $signature === '' || abs(time() - (int) $timestamp) > self::SESSION_TTL) {
            return false;
        }
        $nonce_key = 'technocare_app_nonce_' . hash('sha256', $nonce);
        if (get_transient($nonce_key)) {
            return false;
        }
        $expected = hash_hmac('sha256', $timestamp . '.' . $nonce . '.' . $request->get_body(), $secret);
        if (!hash_equals($expected, $signature)) {
            return false;
        }
        set_transient($nonce_key, 1, self::SESSION_TTL);
        return true;
    }

    public static function checkout_session(WP_REST_Request $request): WP_REST_Response
    {
        if (!function_exists('wc_get_product')) {
            return new WP_REST_Response(['message' => 'WooCommerce is unavailable.'], 503);
        }
        $data = (array) $request->get_json_params();
        $app_user_id = sanitize_text_field((string) ($data['appUserId'] ?? ''));
        $email = sanitize_email((string) ($data['email'] ?? ''));
        $requested_items = is_array($data['items'] ?? null) ? $data['items'] : [];
        if ($app_user_id === '' || $requested_items === []) {
            return new WP_REST_Response(['message' => 'A user and at least one item are required.'], 422);
        }

        $items = [];
        foreach ($requested_items as $requested) {
            $product_id = absint($requested['productId'] ?? 0);
            $quantity = min(99, max(1, absint($requested['quantity'] ?? 1)));
            $product = wc_get_product($product_id);
            if (!$product || !$product->is_purchasable() || !$product->is_in_stock()) {
                return new WP_REST_Response(['message' => sprintf('Product %d is unavailable.', $product_id)], 409);
            }
            if (!$product->has_enough_stock($quantity)) {
                return new WP_REST_Response(['message' => sprintf('Product %d does not have enough stock.', $product_id)], 409);
            }
            $items[] = ['productId' => $product_id, 'quantity' => $quantity];
        }

        $token = wp_generate_password(48, false, false);
        set_transient('technocare_app_checkout_' . hash('sha256', $token), [
            'appUserId' => $app_user_id,
            'email' => $email,
            'items' => $items,
        ], self::SESSION_TTL);

        return new WP_REST_Response([
            'checkoutUrl' => add_query_arg('tc_session', rawurlencode($token), home_url('/app-checkout/')),
            'expiresAt' => gmdate(DATE_ATOM, time() + self::SESSION_TTL),
        ]);
    }

    public static function restore_checkout_session(): void
    {
        if (!str_starts_with(trim((string) wp_parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH), '/'), 'app-checkout')) {
            return;
        }
        $token = sanitize_text_field(wp_unslash($_GET['tc_session'] ?? ''));
        $key = 'technocare_app_checkout_' . hash('sha256', $token);
        $payload = $token !== '' ? get_transient($key) : false;
        if (!is_array($payload) || !function_exists('WC')) {
            wp_die(esc_html__('Checkout session is invalid or expired.', 'technocare-app-api'), '', ['response' => 410]);
        }
        delete_transient($key);

        if (null === WC()->session) {
            WC()->initialize_session();
        }
        if (null === WC()->cart) {
            wc_load_cart();
        }
        WC()->cart->empty_cart();
        foreach ($payload['items'] as $item) {
            $product = wc_get_product((int) $item['productId']);
            $quantity = (int) $item['quantity'];
            if (!$product || !$product->is_purchasable() || !$product->is_in_stock() || !$product->has_enough_stock($quantity) || !WC()->cart->add_to_cart($product->get_id(), $quantity)) {
                WC()->cart->empty_cart();
                wp_die(esc_html__('A product changed or is no longer available. Return to the app and refresh your cart.', 'technocare-app-api'), '', ['response' => 409]);
            }
        }
        WC()->session->set('technocare_app_user_id', $payload['appUserId']);
        WC()->session->set('technocare_app_email', $payload['email']);
        if ($payload['email'] !== '' && WC()->customer) {
            WC()->customer->set_billing_email($payload['email']);
            WC()->customer->save();
        }
        wp_safe_redirect(wc_get_checkout_url());
        exit;
    }

    public static function attach_app_user_to_order(WC_Order $order, array $data): void
    {
        if (!function_exists('WC') || !WC()->session) {
            return;
        }
        $app_user_id = sanitize_text_field((string) WC()->session->get('technocare_app_user_id'));
        if ($app_user_id !== '') {
            $order->update_meta_data('_technocare_app_user_id', $app_user_id);
            $order->update_meta_data('_technocare_app_order', 'yes');
        }
    }

    public static function render_app_return(int $order_id): void
    {
        $order = wc_get_order($order_id);
        if (!$order || $order->get_meta('_technocare_app_order') !== 'yes') {
            return;
        }
        $url = 'technocare://checkout/success?orderId=' . rawurlencode((string) $order_id);
        echo '<p><a class="button" href="' . esc_attr($url) . '">' . esc_html__('Return to Technocare app', 'technocare-app-api') . '</a></p>';
        echo '<script>window.setTimeout(function(){window.location.href=' . wp_json_encode($url) . ';},1200);</script>';
    }

    public static function app_cancel_url(string $url, WC_Order $order): string
    {
        if ($order->get_meta('_technocare_app_order') !== 'yes') {
            return $url;
        }
        return 'technocare://checkout/cancel?orderId=' . rawurlencode((string) $order->get_id());
    }

    public static function orders(WP_REST_Request $request): WP_REST_Response
    {
        $data = (array) $request->get_json_params();
        $app_user_id = sanitize_text_field((string) ($data['appUserId'] ?? ''));
        $page = max(1, absint($data['page'] ?? 1));
        if ($app_user_id === '') {
            return new WP_REST_Response(['message' => 'appUserId is required.'], 422);
        }
        $query = wc_get_orders([
            'limit' => 20,
            'page' => $page,
            'paginate' => true,
            'meta_query' => [[
                'key' => '_technocare_app_user_id',
                'value' => $app_user_id,
                'compare' => '=',
            ]],
            'orderby' => 'date',
            'order' => 'DESC',
        ]);
        $items = array_map(static function (WC_Order $order): array {
            return [
                'id' => $order->get_id(),
                'number' => $order->get_order_number(),
                'status' => $order->get_status(),
                'createdAt' => $order->get_date_created()?->date(DATE_ATOM),
                'currencyCode' => $order->get_currency(),
                'total' => (float) $order->get_total(),
                'items' => array_values(array_map(static fn(WC_Order_Item_Product $item): array => [
                    'productId' => $item->get_product_id(),
                    'name' => self::clean_text($item->get_name()),
                    'quantity' => $item->get_quantity(),
                    'total' => (float) $item->get_total(),
                ], $order->get_items())),
            ];
        }, $query->orders);
        return new WP_REST_Response([
            'items' => $items,
            'page' => $page,
            'pageSize' => 20,
            'total' => (int) $query->total,
            'totalPages' => (int) $query->max_num_pages,
        ]);
    }

    /** @param array<string, mixed> $payload */
    private static function cacheable_response(array $payload, int $last_modified, int $max_age = 300): WP_REST_Response
    {
        $etag = '"' . hash('sha256', wp_json_encode($payload)) . '"';
        $if_none_match = trim((string) ($_SERVER['HTTP_IF_NONE_MATCH'] ?? ''));
        $response = new WP_REST_Response($if_none_match === $etag ? null : $payload, $if_none_match === $etag ? 304 : 200);
        $response->header('Cache-Control', 'public, max-age=' . $max_age . ', stale-if-error=86400');
        $response->header('ETag', $etag);
        $response->header('Last-Modified', gmdate('D, d M Y H:i:s', $last_modified) . ' GMT');
        return $response;
    }

    /** @return array<string, array{enabled: bool, order: int}> */
    private static function section_config(): array
    {
        $saved = get_option(self::SECTION_CONFIG_OPTION, []);
        $config = [];
        foreach (self::SECTION_TYPES as $index => $type) {
            $entry = is_array($saved[$type] ?? null) ? $saved[$type] : [];
            $config[$type] = [
                'enabled' => !isset($entry['enabled']) || (bool) $entry['enabled'],
                'order' => isset($entry['order']) ? (int) $entry['order'] : $index,
            ];
        }
        return $config;
    }

    public static function register_settings_page(): void
    {
        add_options_page('Technocare App API', 'Technocare App', 'manage_options', 'technocare-app-api', [self::class, 'settings_page']);
    }

    public static function register_settings(): void
    {
        register_setting('technocare_app_api', self::HOME_PAGE_OPTION, ['type' => 'integer', 'sanitize_callback' => 'absint']);
        register_setting('technocare_app_api', self::SECTION_CONFIG_OPTION, ['type' => 'array', 'sanitize_callback' => [self::class, 'sanitize_section_config']]);
    }

    /** @return array<string, array{enabled: bool, order: int}> */
    public static function sanitize_section_config($value): array
    {
        $result = [];
        foreach (self::SECTION_TYPES as $index => $type) {
            $entry = is_array($value[$type] ?? null) ? $value[$type] : [];
            $result[$type] = [
                'enabled' => !empty($entry['enabled']),
                'order' => isset($entry['order']) ? (int) $entry['order'] : $index,
            ];
        }
        return $result;
    }

    public static function settings_page(): void
    {
        if (!current_user_can('manage_options')) {
            return;
        }
        $page_id = (int) get_option(self::HOME_PAGE_OPTION, (int) get_option('page_on_front'));
        $config = self::section_config();
        ?>
        <div class="wrap">
            <h1>Technocare Mobile App</h1>
            <p>The app reads content from the published WordPress page and WooCommerce. Use this screen only to control which supported sections appear in the app and their order.</p>
            <form method="post" action="options.php">
                <?php settings_fields('technocare_app_api'); ?>
                <table class="form-table" role="presentation">
                    <tr>
                        <th scope="row"><label for="technocare_app_home_page_id">Homepage</label></th>
                        <td><?php wp_dropdown_pages(['name' => self::HOME_PAGE_OPTION, 'id' => 'technocare_app_home_page_id', 'selected' => $page_id, 'show_option_none' => '— Select —']); ?></td>
                    </tr>
                </table>
                <h2>App sections</h2>
                <table class="widefat striped">
                    <thead><tr><th>Section</th><th>Visible</th><th>Order</th></tr></thead>
                    <tbody>
                    <?php foreach (self::SECTION_TYPES as $type): ?>
                        <tr>
                            <td><code><?php echo esc_html($type); ?></code></td>
                            <td><input type="checkbox" name="<?php echo esc_attr(self::SECTION_CONFIG_OPTION); ?>[<?php echo esc_attr($type); ?>][enabled]" value="1" <?php checked($config[$type]['enabled']); ?>></td>
                            <td><input type="number" min="0" max="99" name="<?php echo esc_attr(self::SECTION_CONFIG_OPTION); ?>[<?php echo esc_attr($type); ?>][order]" value="<?php echo esc_attr((string) $config[$type]['order']); ?>"></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
                <?php submit_button(); ?>
            </form>
        </div>
        <?php
    }
}

Technocare_App_API::boot();
