<?php

declare(strict_types=1);

define('ABSPATH', __DIR__ . '/');

function add_action(...$_arguments): void {}
function add_filter(...$_arguments): void {}
function home_url(string $path = ''): string { return 'https://technocare.az' . $path; }
function wp_parse_url(string $url, int $component = -1) { return parse_url($url, $component); }
function esc_url_raw(string $url): string { return $url; }
function set_url_scheme(string $url, string $scheme): string { return preg_replace('#^https?://#', $scheme . '://', $url) ?? $url; }
function url_to_postid(string $_url): int { return 0; }
function get_post(int $_id) { return null; }
function get_post_modified_time(string $format, bool $_gmt, WP_Post $_post) { return $format === DATE_ATOM ? '2026-09-01T00:00:00+00:00' : 1788220800; }
function wp_strip_all_tags(string $value): string { return strip_tags($value); }
function get_post_meta(int $_id, string $_key, bool $_single = false): string { return ''; }
function get_the_post_thumbnail_url(WP_Post $_post, string $_size): string { return ''; }
function apply_filters(string $_hook, string $value): string { return $value; }
function get_the_excerpt(WP_Post $_post): string { return ''; }

class WP_Post
{
    public int $ID = 2829;
    public string $post_status = 'publish';
    public string $post_content = '';
}

require dirname(__DIR__) . '/technocare-app-api.php';

$fixture = <<<'HTML'
<main>
  <div class="e-con e-child">
    <div><img data-lazy-src="/wp-content/uploads/project-one.webp" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP" /></div>
    <h2><a href="https://technocare.az/layiheler/project-one">Birinci layihə</a></h2>
    <p>Birinci layihənin təsviri.</p>
  </div>
  <div class="e-con e-child">
    <picture><img src="//technocare.az/wp-content/uploads/project-two.jpg" /></picture>
    <h3><a href="/top-level-project-two">İkinci layihə</a></h3>
    <p>İkinci layihənin təsviri.</p>
  </div>
  <h2><a href="https://technocare.az/layiheler/project-one">Birinci layihə təkrar</a></h2>
</main>
HTML;

$method = new ReflectionMethod(Technocare_App_API::class, 'extract_project_cards');
$method->setAccessible(true);
$items = $method->invoke(null, $fixture, new WP_Post());

$assert = static function (bool $condition, string $message): void {
    if (!$condition) {
        fwrite(STDERR, $message . PHP_EOL);
        exit(1);
    }
};

$assert(count($items) === 2, 'Expected two unique project cards.');
$assert($items[0]['name'] === 'Birinci layihə', 'First project title was not extracted.');
$assert($items[0]['imageUrl'] === 'https://technocare.az/wp-content/uploads/project-one.webp', 'Lazy image URL was not normalized.');
$assert($items[1]['url'] === 'https://technocare.az/top-level-project-two', 'Top-level project URL was rejected.');
$assert($items[1]['imageUrl'] === 'https://technocare.az/wp-content/uploads/project-two.jpg', 'Protocol-relative image URL was not normalized.');

fwrite(STDOUT, "Project parser smoke test passed.\n");
