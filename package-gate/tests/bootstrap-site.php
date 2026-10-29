<?php

/**
 * The fixture site a package boots on: tests/Integration/site.php, when the package has one,
 * is the NTDST_Bootstrap config, booted with a site's hook timing. A package without that
 * file runs its integration suite on plain WordPress.
 *
 * phpcs:disable PSR1.Files.SideEffects
 */

declare(strict_types=1);

$ntdstPackageDir = dirname(__DIR__);

if (!is_file($ntdstPackageDir . '/tests/Integration/site.php')) {
    return;
}

// tests_add_filter() comes from here; wp-phpunit's bootstrap require_once's it again.
require_once getenv('WP_PHPUNIT__DIR') . '/includes/functions.php';

tests_add_filter('plugins_loaded', static function () use ($ntdstPackageDir): void {
    $bootstrap = new NTDST_Bootstrap(require $ntdstPackageDir . '/tests/Integration/site.php');
    $bootstrap->register();
    ntdst_set(NTDST_Bootstrap::class, static fn() => $bootstrap);

    add_action('after_setup_theme', static function () use ($bootstrap): void {
        $bootstrap->bootCore();
    }, 5);
    add_action('after_setup_theme', static function () use ($bootstrap): void {
        $bootstrap->bootFeatures();
    }, 15);
}, 20);
