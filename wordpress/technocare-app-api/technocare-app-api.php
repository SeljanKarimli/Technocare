<?php
/**
 * Plugin Name: Technocare App API
 * Description: Versioned, mobile-friendly content, catalogue and checkout endpoints for the Technocare Flutter app.
 * Version: 1.1.0
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
    private const SEARCH_INDEX_VERSION = '1.0';
    private const SEARCH_INDEX_VERSION_OPTION = 'technocare_app_search_index_version';
    private const SEARCH_INDEX_READY_OPTION = 'technocare_app_search_index_ready';

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
        add_action('init', [self::class, 'ensure_search_index'], 5);
        add_action('technocare_app_rebuild_search_index', [self::class, 'rebuild_search_index_batch'], 10, 1);
        add_action('save_post_product', [self::class, 'index_saved_product'], 20, 3);
        add_action('woocommerce_product_set_stock', [self::class, 'index_stock_product'], 20, 1);
        add_action('set_object_terms', [self::class, 'index_product_terms'], 20, 6);
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

        register_rest_route(self::NAMESPACE, '/suggestions', [
            'methods' => WP_REST_Server::READABLE,
            'callback' => [self::class, 'suggestions'],
            'permission_callback' => '__return_true',
            'args' => [
                'q' => ['sanitize_callback' => 'sanitize_text_field', 'required' => true],
                'limit' => ['sanitize_callback' => 'absint', 'default' => 5],
            ],
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
            'args' => [
                'q' => ['sanitize_callback' => 'sanitize_text_field', 'default' => ''],
                'page' => ['sanitize_callback' => 'absint', 'default' => 1],
                'pageSize' => ['sanitize_callback' => 'absint', 'default' => 12],
            ],
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

        $html = self::render_post_content($page);
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

    private static function render_post_content(WP_Post $post): string
    {
        $html = (string) apply_filters('the_content', $post->post_content);
        if (!class_exists('\\Elementor\\Plugin') || get_post_meta($post->ID, '_elementor_data', true) === '') {
            return $html;
        }
        try {
            $frontend = \Elementor\Plugin::instance()->frontend;
            if (is_object($frontend) && method_exists($frontend, 'get_builder_content_for_display')) {
                $elementor_html = (string) $frontend->get_builder_content_for_display($post->ID, false);
                if (trim($elementor_html) !== '') {
                    return $elementor_html;
                }
            }
        } catch (\Throwable $_exception) {
            // Keep the standard WordPress rendering as a safe fallback.
        }
        return $html;
    }

    public static function ensure_search_index(): void
    {
        if (!function_exists('wc_get_product')) {
            return;
        }
        if ((string) get_option(self::SEARCH_INDEX_VERSION_OPTION, '') === self::SEARCH_INDEX_VERSION) {
            return;
        }

        global $wpdb;
        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        $table = self::search_index_table();
        $charset = $wpdb->get_charset_collate();
        dbDelta("CREATE TABLE {$table} (
            product_id bigint(20) unsigned NOT NULL,
            sku varchar(191) NOT NULL DEFAULT '',
            normalized_sku varchar(191) NOT NULL DEFAULT '',
            name text NOT NULL,
            normalized_name varchar(255) NOT NULL DEFAULT '',
            brand varchar(191) NOT NULL DEFAULT '',
            normalized_brand varchar(191) NOT NULL DEFAULT '',
            categories text NOT NULL,
            normalized_categories text NOT NULL,
            description longtext NOT NULL,
            normalized_description longtext NOT NULL,
            image_url text NOT NULL,
            price decimal(20,6) NULL,
            on_sale tinyint(1) NOT NULL DEFAULT 0,
            in_stock tinyint(1) NOT NULL DEFAULT 0,
            popularity bigint(20) NOT NULL DEFAULT 0,
            updated_at datetime NOT NULL,
            PRIMARY KEY  (product_id),
            KEY ix_tc_search_sku (normalized_sku),
            KEY ix_tc_search_name (normalized_name(100)),
            KEY ix_tc_search_brand (normalized_brand(100)),
            KEY ix_tc_search_updated (updated_at)
        ) {$charset};");
        update_option(self::SEARCH_INDEX_VERSION_OPTION, self::SEARCH_INDEX_VERSION, false);
        delete_option(self::SEARCH_INDEX_READY_OPTION);
        if (!wp_next_scheduled('technocare_app_rebuild_search_index', [0])) {
            wp_schedule_single_event(time() + 5, 'technocare_app_rebuild_search_index', [0]);
        }
    }

    public static function rebuild_search_index_batch(int $offset = 0): void
    {
        if (!function_exists('wc_get_product')) {
            return;
        }
        $batch_size = 200;
        $ids = get_posts([
            'post_type' => 'product',
            'post_status' => 'publish',
            'fields' => 'ids',
            'posts_per_page' => $batch_size,
            'offset' => max(0, $offset),
            'orderby' => 'ID',
            'order' => 'ASC',
            'no_found_rows' => true,
        ]);
        foreach ($ids as $product_id) {
            self::index_product((int) $product_id);
        }
        if (count($ids) === $batch_size) {
            wp_schedule_single_event(time() + 2, 'technocare_app_rebuild_search_index', [$offset + $batch_size]);
            return;
        }
        update_option(self::SEARCH_INDEX_READY_OPTION, gmdate(DATE_ATOM), false);
    }

    public static function index_saved_product(int $post_id, WP_Post $post, bool $update): void
    {
        if (wp_is_post_revision($post_id) || wp_is_post_autosave($post_id)) {
            return;
        }
        self::index_product($post_id);
    }

    /** @param mixed $product */
    public static function index_stock_product($product): void
    {
        if (!is_object($product) || !method_exists($product, 'get_id')) {
            return;
        }
        $product_id = (int) $product->get_id();
        if (method_exists($product, 'get_parent_id') && (int) $product->get_parent_id() > 0) {
            $product_id = (int) $product->get_parent_id();
        }
        self::index_product($product_id);
    }

    /** @param int[] $terms @param int[] $term_taxonomy_ids */
    public static function index_product_terms(int $object_id, $terms, $term_taxonomy_ids, string $taxonomy, bool $append, $old_term_taxonomy_ids): void
    {
        if (in_array($taxonomy, ['product_cat', 'pa_brand'], true) && get_post_type($object_id) === 'product') {
            self::index_product($object_id);
        }
    }

    private static function index_product(int $product_id): void
    {
        global $wpdb;
        $table = self::search_index_table();
        $product = function_exists('wc_get_product') ? wc_get_product($product_id) : false;
        if (!$product || $product->get_status() !== 'publish') {
            $wpdb->delete($table, ['product_id' => $product_id], ['%d']);
            return;
        }
        $brand_terms = taxonomy_exists('pa_brand') ? wp_get_post_terms($product_id, 'pa_brand', ['fields' => 'names']) : [];
        $category_terms = wp_get_post_terms($product_id, 'product_cat', ['fields' => 'names']);
        $brand = is_wp_error($brand_terms) ? '' : self::clean_text(implode(' ', $brand_terms));
        $categories = is_wp_error($category_terms) ? '' : self::clean_text(implode(' ', $category_terms));
        $description = self::clean_text($product->get_short_description() . ' ' . $product->get_description());
        $image_url = $product->get_image_id() ? (wp_get_attachment_image_url($product->get_image_id(), 'medium') ?: '') : '';
        $wpdb->replace($table, [
            'product_id' => $product_id,
            'sku' => (string) $product->get_sku(),
            'normalized_sku' => self::normalize_search_text((string) $product->get_sku()),
            'name' => self::clean_text($product->get_name()),
            'normalized_name' => self::normalize_search_text($product->get_name()),
            'brand' => $brand,
            'normalized_brand' => self::normalize_search_text($brand),
            'categories' => $categories,
            'normalized_categories' => self::normalize_search_text($categories),
            'description' => $description,
            'normalized_description' => self::normalize_search_text($description),
            'image_url' => $image_url,
            'price' => $product->get_price() === '' ? null : (float) $product->get_price(),
            'on_sale' => $product->is_on_sale() ? 1 : 0,
            'in_stock' => $product->is_in_stock() ? 1 : 0,
            'popularity' => (int) $product->get_total_sales(),
            'updated_at' => current_time('mysql', true),
        ]);
    }

    public static function suggestions(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;
        $query = self::normalize_search_text((string) $request->get_param('q'));
        $limit = min(10, max(1, absint($request->get_param('limit') ?: 5)));
        if (mb_strlen($query) < 2) {
            return self::cacheable_response(['items' => []], time(), 60);
        }
        $table = self::search_index_table();
        $exact = $query;
        $prefix = $wpdb->esc_like($query) . '%';
        $contains = '%' . $wpdb->esc_like($query) . '%';
        $sql = $wpdb->prepare(
            "SELECT product_id, sku, name, brand, image_url, price, on_sale, in_stock
             FROM {$table}
             WHERE normalized_sku LIKE %s OR normalized_name LIKE %s OR normalized_brand LIKE %s OR normalized_categories LIKE %s OR normalized_description LIKE %s
             ORDER BY CASE
                WHEN normalized_sku = %s THEN 0
                WHEN normalized_sku LIKE %s THEN 1
                WHEN normalized_name = %s THEN 2
                WHEN normalized_name LIKE %s THEN 3
                WHEN normalized_brand LIKE %s OR normalized_categories LIKE %s THEN 4
                ELSE 5 END ASC,
                popularity DESC, product_id DESC
             LIMIT %d",
            $contains,
            $contains,
            $contains,
            $contains,
            $contains,
            $exact,
            $prefix,
            $exact,
            $prefix,
            $contains,
            $contains,
            $limit
        );
        $rows = $wpdb->get_results($sql, ARRAY_A);
        $items = array_map(static fn(array $row): array => [
            'id' => (int) $row['product_id'],
            'name' => (string) $row['name'],
            'sku' => (string) $row['sku'],
            'brand' => (string) $row['brand'],
            'imageUrl' => (string) $row['image_url'],
            'price' => $row['price'] === null ? null : (float) $row['price'],
            'onSale' => (bool) $row['on_sale'],
            'inStock' => (bool) $row['in_stock'],
        ], is_array($rows) ? $rows : []);
        return self::cacheable_response(['items' => $items], time(), 300);
    }

    private static function search_index_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'technocare_product_search';
    }

    private static function normalize_search_text(string $value): string
    {
        $value = strtr($value, [
            'Ə' => 'e', 'ə' => 'e', 'I' => 'i', 'İ' => 'i', 'ı' => 'i',
            'Ş' => 's', 'ş' => 's', 'Ç' => 'c', 'ç' => 'c', 'Ö' => 'o',
            'ö' => 'o', 'Ü' => 'u', 'ü' => 'u', 'Ğ' => 'g', 'ğ' => 'g',
        ]);
        $value = remove_accents(mb_strtolower($value, 'UTF-8'));
        return trim((string) preg_replace('/[^a-z0-9]+/u', ' ', $value));
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
        $normalized = self::normalize_search_text((string) $term);
        $like = '%' . $wpdb->esc_like($normalized) . '%';
        $table = self::search_index_table();
        return $wpdb->prepare(
            " AND EXISTS (SELECT 1 FROM {$table} tc_search WHERE tc_search.product_id = {$wpdb->posts}.ID AND (tc_search.normalized_sku LIKE %s OR tc_search.normalized_name LIKE %s OR tc_search.normalized_brand LIKE %s OR tc_search.normalized_categories LIKE %s OR tc_search.normalized_description LIKE %s)) ",
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
        $term = self::normalize_search_text((string) $query->get('technocare_search'));
        if ($term === '') {
            return $clauses;
        }
        $table = self::search_index_table();
        $prefix = $wpdb->esc_like($term) . '%';
        $contains = '%' . $wpdb->esc_like($term) . '%';
        $clauses['join'] .= " INNER JOIN {$table} tc_rank_search ON tc_rank_search.product_id = {$wpdb->posts}.ID ";
        $clauses['orderby'] = $wpdb->prepare(
            "CASE
                WHEN tc_rank_search.normalized_sku = %s THEN 0
                WHEN tc_rank_search.normalized_sku LIKE %s THEN 1
                WHEN tc_rank_search.normalized_name = %s THEN 2
                WHEN tc_rank_search.normalized_name LIKE %s THEN 3
                WHEN tc_rank_search.normalized_brand LIKE %s OR tc_rank_search.normalized_categories LIKE %s THEN 4
                WHEN tc_rank_search.normalized_description LIKE %s THEN 5
                ELSE 6 END ASC, tc_rank_search.popularity DESC, {$wpdb->posts}.post_date DESC",
            $term,
            $prefix,
            $term,
            $prefix,
            $contains,
            $contains,
            $contains
        );
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
        $search = self::normalize_search_text((string) $request->get_param('q'));
        $landing = get_page_by_path('layiheler', OBJECT, 'page');
        if ($landing instanceof WP_Post && $landing->post_status === 'publish') {
            $content = self::render_post_content($landing);
            $projects = self::extract_project_cards($content, $landing);
            if ($projects !== []) {
                if ($search !== '') {
                    $projects = array_values(array_filter($projects, static function (array $project) use ($search): bool {
                        $haystack = self::normalize_search_text(
                            (string) ($project['name'] ?? '') . ' ' .
                            (string) ($project['description'] ?? '') . ' ' .
                            (string) ($project['content'] ?? '')
                        );
                        return str_contains($haystack, $search);
                    }));
                }
                $total = count($projects);
                $total_pages = (int) ceil($total / $page_size);
                $items = array_slice($projects, ($page - 1) * $page_size, $page_size);
                return self::cacheable_response([
                    'items' => array_values($items),
                    'page' => $page,
                    'pageSize' => $page_size,
                    'total' => $total,
                    'totalPages' => $total_pages,
                ], (int) get_post_modified_time('U', true, $landing), 300);
            }
        }

        // Compatibility fallback for installations where projects are real
        // portfolio posts instead of Elementor cards on the projects page.
        $query = new WP_Query([
            'post_type' => post_type_exists('portfolio') ? 'portfolio' : 'post',
            'post_status' => 'publish',
            'paged' => $page,
            'posts_per_page' => $page_size,
            'orderby' => 'menu_order date',
            'order' => 'DESC',
            's' => $search,
        ]);
        $items = array_map(static function (WP_Post $post): array {
            $content = self::render_post_content($post);
            $images = self::project_page_images($post, $content);
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

    /** @return array<int, array<string, mixed>> */
    private static function extract_project_cards(string $html, WP_Post $landing): array
    {
        if (!class_exists('DOMDocument') || trim($html) === '') {
            return [];
        }

        $document = new DOMDocument('1.0', 'UTF-8');
        libxml_use_internal_errors(true);
        $document->loadHTML('<?xml encoding="UTF-8">' . $html, LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD);
        libxml_clear_errors();
        $xpath = new DOMXPath($document);
        $items = [];
        $seen = [];

        foreach ($xpath->query('//h1[a[@href]]|//h2[a[@href]]|//h3[a[@href]]|//h4[a[@href]]') ?: [] as $heading) {
            if (!$heading instanceof DOMElement) {
                continue;
            }
            $anchor = $xpath->query('.//a[@href]', $heading)?->item(0);
            if (!$anchor instanceof DOMElement) {
                continue;
            }
            $url = self::normalize_public_url($anchor->getAttribute('href'));
            if (!self::is_project_detail_url($url) || isset($seen[$url])) {
                continue;
            }
            $title = self::clean_text($heading->textContent ?? '');
            if ($title === '') {
                continue;
            }

            $container = $heading;
            $candidate = $heading->parentNode;
            for ($depth = 0; $depth < 7 && $candidate instanceof DOMElement; $depth++) {
                $container = $candidate;
                if (($xpath->query('.//img', $candidate)?->length ?? 0) > 0) {
                    break;
                }
                $candidate = $candidate->parentNode;
            }

            $card_image = '';
            foreach ($xpath->query('.//img', $container) ?: [] as $image) {
                if ($image instanceof DOMElement) {
                    $card_image = self::image_url_from_element($image);
                    if ($card_image !== '') {
                        break;
                    }
                }
            }

            $description = '';
            foreach ($xpath->query('.//p', $container) ?: [] as $paragraph) {
                $value = self::clean_text($paragraph->textContent ?? '');
                if ($value !== '' && $value !== $title) {
                    $description = $value;
                    break;
                }
            }

            $project_id = url_to_postid($url);
            $project_page = $project_id > 0 ? get_post($project_id) : null;
            $images = $card_image !== '' ? [$card_image] : [];
            $content = '';
            $updated_at = get_post_modified_time(DATE_ATOM, true, $landing);
            if ($project_page instanceof WP_Post && $project_page->post_status === 'publish') {
                $detail_html = $project_page->post_content !== ''
                    ? apply_filters('the_content', $project_page->post_content)
                    : '';
                $images = array_values(array_unique(array_merge(
                    $images,
                    self::project_page_images($project_page, $detail_html)
                )));
                $content = self::clean_text(wp_strip_all_tags($detail_html));
                if ($description === '') {
                    $description = self::clean_text(get_the_excerpt($project_page));
                }
                $updated_at = get_post_modified_time(DATE_ATOM, true, $project_page);
            }

            $items[] = [
                'id' => $project_id > 0 ? $project_id : -abs(crc32($url)),
                'name' => $title,
                'description' => $description,
                'content' => $content,
                'imageUrl' => $images[0] ?? '',
                'images' => array_slice($images, 0, 30),
                'url' => $url,
                'updatedAt' => $updated_at,
            ];
            $seen[$url] = true;
        }

        return $items;
    }

    /** @return string[] */
    private static function project_page_images(WP_Post $post, string $html = ''): array
    {
        $images = [];
        $featured = get_the_post_thumbnail_url($post, 'full') ?: '';
        self::append_image_url($images, $featured);

        if (class_exists('DOMDocument') && trim($html) !== '') {
            $document = new DOMDocument('1.0', 'UTF-8');
            libxml_use_internal_errors(true);
            $document->loadHTML('<?xml encoding="UTF-8">' . $html, LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD);
            libxml_clear_errors();
            foreach ($document->getElementsByTagName('img') as $image) {
                if ($image instanceof DOMElement) {
                    self::append_image_url($images, self::image_url_from_element($image));
                }
            }
        }

        $elementor_data = json_decode((string) get_post_meta($post->ID, '_elementor_data', true), true);
        if (is_array($elementor_data)) {
            self::collect_elementor_image_urls($elementor_data, $images);
        }
        return array_values($images);
    }

    /** @param mixed $value @param string[] $images */
    private static function collect_elementor_image_urls($value, array &$images): void
    {
        if (is_string($value)) {
            self::append_image_url($images, $value);
            return;
        }
        if (!is_array($value)) {
            return;
        }
        foreach ($value as $child) {
            self::collect_elementor_image_urls($child, $images);
        }
    }

    /** @param string[] $images */
    private static function append_image_url(array &$images, string $candidate): void
    {
        $url = self::normalize_public_url($candidate);
        $path = strtolower((string) wp_parse_url($url, PHP_URL_PATH));
        if ($url === '' || !preg_match('/\.(?:avif|gif|jpe?g|png|svg|webp)$/', $path)) {
            return;
        }
        if (!in_array($url, $images, true)) {
            $images[] = $url;
        }
    }

    private static function image_url_from_element(DOMElement $image): string
    {
        foreach (['data-lazy-src', 'data-src', 'src'] as $attribute) {
            $url = self::normalize_public_url($image->getAttribute($attribute));
            if ($url !== '' && !str_starts_with($url, 'data:')) {
                return $url;
            }
        }
        return '';
    }

    private static function normalize_public_url(string $candidate): string
    {
        $url = trim(html_entity_decode($candidate, ENT_QUOTES | ENT_HTML5, 'UTF-8'));
        if ($url === '' || str_starts_with($url, 'data:') || str_starts_with($url, 'javascript:')) {
            return '';
        }
        if (str_starts_with($url, '//')) {
            $scheme = (string) wp_parse_url(home_url('/'), PHP_URL_SCHEME);
            $url = ($scheme !== '' ? $scheme : 'https') . ':' . $url;
        } elseif (str_starts_with($url, '/')) {
            $url = home_url($url);
        } elseif (!preg_match('#^https?://#i', $url)) {
            $url = home_url('/' . ltrim($url, '/'));
        }
        $home_host = strtolower((string) wp_parse_url(home_url('/'), PHP_URL_HOST));
        $url_host = strtolower((string) wp_parse_url($url, PHP_URL_HOST));
        if (wp_parse_url(home_url('/'), PHP_URL_SCHEME) === 'https' && $home_host !== '' && $url_host === $home_host) {
            $url = set_url_scheme($url, 'https');
        }
        return esc_url_raw($url);
    }

    private static function is_project_detail_url(string $url): bool
    {
        if ($url === '') {
            return false;
        }
        $home_host = strtolower((string) wp_parse_url(home_url('/'), PHP_URL_HOST));
        $url_host = strtolower((string) wp_parse_url($url, PHP_URL_HOST));
        $path = '/' . trim((string) wp_parse_url($url, PHP_URL_PATH), '/');
        // Most project details live below /layiheler/, but some newer cards are
        // regular top-level pages. The project-card heading and image checks in
        // extract_project_cards provide the structural boundary here.
        return $url_host === $home_host && $path !== '/' && strtolower($path) !== '/layiheler';
    }

    private static function page_collection(string $landing_slug): WP_REST_Response
    {
        $landing = get_page_by_path($landing_slug, OBJECT, 'page');
        if (!$landing instanceof WP_Post || $landing->post_status !== 'publish') {
            return new WP_REST_Response(['message' => 'Content page is not configured.'], 503);
        }
        $content = self::render_post_content($landing);
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
        $seen_keys = [];
        foreach (array_values(array_unique($page_ids)) as $page_id) {
            $page = get_post($page_id);
            if ($page instanceof WP_Post && $page->post_status === 'publish') {
                $item = self::map_content_page($page);
                $key = self::collection_item_key($landing_slug, $item['title']);
                if ($key !== null && isset($seen_keys[$key])) {
                    continue;
                }
                $items[] = $item;
                if ($key !== null) {
                    $seen_keys[$key] = true;
                }
            }
        }
        foreach (self::extract_inline_collection_items($content, $landing_slug, $landing) as $item) {
            $key = self::collection_item_key($landing_slug, $item['title']);
            if ($key !== null && isset($seen_keys[$key])) {
                continue;
            }
            $items[] = $item;
            if ($key !== null) {
                $seen_keys[$key] = true;
            }
        }
        return self::cacheable_response([
            'schemaVersion' => 1,
            'updatedAt' => get_post_modified_time(DATE_ATOM, true, $landing),
            'sourceUrl' => get_permalink($landing),
            'items' => $items,
        ], (int) get_post_modified_time('U', true, $landing), 300);
    }

    /** @return array<int, array<string, mixed>> */
    private static function extract_inline_collection_items(string $html, string $landing_slug, WP_Post $landing): array
    {
        if (!class_exists('DOMDocument') || trim($html) === '') {
            return [];
        }
        $document = new DOMDocument('1.0', 'UTF-8');
        libxml_use_internal_errors(true);
        $document->loadHTML('<?xml encoding="UTF-8">' . $html, LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD);
        libxml_clear_errors();
        $xpath = new DOMXPath($document);
        $items = [];
        $seen = [];
        foreach ($xpath->query('//h2|//h3|//h4') ?: [] as $heading) {
            if (!$heading instanceof DOMElement) {
                continue;
            }
            $title = self::clean_text($heading->textContent ?? '');
            $key = self::collection_item_key($landing_slug, $title);
            if ($key === null || isset($seen[$key])) {
                continue;
            }

            $container = $heading;
            $candidate = $heading->parentNode;
            for ($depth = 0; $depth < 6 && $candidate instanceof DOMElement; $depth++) {
                $candidate_text = self::clean_text($candidate->textContent ?? '');
                $container = $candidate;
                if (mb_strlen($candidate_text) > mb_strlen($title) + 20) {
                    break;
                }
                $candidate = $candidate->parentNode;
            }

            $plain = self::clean_text($container->textContent ?? '');
            if (str_starts_with($plain, $title)) {
                $plain = trim(mb_substr($plain, mb_strlen($title)));
            }
            $image_url = '';
            foreach ($xpath->query('.//img', $container) ?: [] as $image) {
                if (!$image instanceof DOMElement) {
                    continue;
                }
                $source = $image->getAttribute('data-lazy-src') ?: $image->getAttribute('src');
                if ($source !== '' && !str_starts_with($source, 'data:')) {
                    $image_url = esc_url_raw($source);
                    break;
                }
            }

            $url = get_permalink($landing);
            foreach ($xpath->query('.//a[@href]', $container) ?: [] as $anchor) {
                if (!$anchor instanceof DOMElement) {
                    continue;
                }
                $href = trim($anchor->getAttribute('href'));
                if ($href === '') {
                    continue;
                }
                if (str_starts_with($href, '#')) {
                    $url = get_permalink($landing) . $href;
                } elseif (str_starts_with($href, 'http://') || str_starts_with($href, 'https://')) {
                    $url = esc_url_raw($href);
                } else {
                    $url = esc_url_raw(home_url('/' . ltrim($href, '/')));
                }
                break;
            }

            $items[] = [
                'id' => -abs(crc32($landing_slug . '|' . $key)),
                'title' => $title,
                'summary' => mb_substr($plain !== '' ? $plain : $title, 0, 280),
                'body' => $plain,
                'imageUrl' => $image_url,
                'images' => $image_url !== '' ? [$image_url] : [],
                'url' => $url,
                'updatedAt' => get_post_modified_time(DATE_ATOM, true, $landing),
            ];
            $seen[$key] = true;
        }
        return $items;
    }

    private static function collection_item_key(string $landing_slug, string $title): ?string
    {
        $value = strtr(mb_strtolower(self::clean_text($title), 'UTF-8'), [
            'ə' => 'e', 'ı' => 'i', 'ş' => 's', 'ç' => 'c', 'ö' => 'o', 'ü' => 'u', 'ğ' => 'g',
        ]);
        $value = trim((string) preg_replace('/[^a-z0-9]+/', ' ', $value));
        if ($landing_slug === 'xidmetler') {
            if ($value === 'avtomatika' || str_starts_with($value, 'avtomatika xidmet')) {
                return 'automation';
            }
            if ($value === 'elektronika' || str_starts_with($value, 'elektronika xidmet')) {
                return 'electronics';
            }
            if ($value === 'energetika' || str_starts_with($value, 'energetika xidmet') || str_starts_with($value, 'enerji xidmet')) {
                return 'energy';
            }
        }
        if ($landing_slug === 'tedris') {
            if (str_contains($value, 'avtomatika muhendisliyi')) {
                return 'automation';
            }
            if (str_contains($value, 'elektronika muhendisliyi')) {
                return 'electronics';
            }
            if (str_contains($value, 'elektrik muhendisliyi')) {
                return 'electrical';
            }
        }
        return null;
    }

    /** @return array<string, mixed> */
    private static function map_content_page(WP_Post $page): array
    {
        $html = self::render_post_content($page);
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
