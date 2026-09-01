<?php

declare(strict_types=1);

define('ABSPATH', __DIR__ . '/');

function add_action(...$_arguments): void {}
function add_filter(...$_arguments): void {}
function remove_accents(string $value): string
{
    return strtr($value, ['ə' => 'e', 'Ə' => 'E', 'ı' => 'i', 'İ' => 'I', 'ş' => 's', 'Ş' => 'S', 'ç' => 'c', 'Ç' => 'C', 'ö' => 'o', 'Ö' => 'O', 'ü' => 'u', 'Ü' => 'U', 'ğ' => 'g', 'Ğ' => 'G']);
}
function sanitize_text_field(string $value): string { return trim($value); }

require dirname(__DIR__) . '/technocare-app-api.php';

$method = new ReflectionMethod(Technocare_App_API::class, 'normalize_search_text');
$method->setAccessible(true);

$actual = $method->invoke(null, '  SƏNAYE Şalteri – İdarəetmə  ');
if ($actual !== 'senaye salteri idareetme') {
    fwrite(STDERR, "Azerbaijani normalization failed: {$actual}\n");
    exit(1);
}

fwrite(STDOUT, "Search normalization smoke test passed.\n");
