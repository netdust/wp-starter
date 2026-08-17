<?php

/**
 * Plugin Name: NTDST Baseline Loader
 * Description: Loads the NTDST Baseline plugin (shared WordPress-gaps
 * baseline: security headers, head cleanup, SEO, schema, maintenance mode,
 * cache headers) from subdirectory.
 * Version: 1.1.0
 * Author: NTDST
 *
 * Mirrors the ntdst-core loader pattern: mu-plugins can't live in
 * subdirectories on their own, so this thin loader require's the real
 * plugin entrypoint. All baseline logic lives in ntdst-baseline/, keeping
 * it framework-agnostic and free of site-specific values.
 *
 * The package is composer-installed and gitignored in consumer projects, so a
 * deploy that could not run `composer install` leaves this shim pointing at a
 * file that is not there. A bare `require_once` fatals inside wp-settings.php
 * and white-screens the entire site, wp-admin included. The guard below is
 * what keeps a failed install recoverable — see ntdst-coreloader.php for the
 * full reasoning. Never remove it in the name of brevity.
 *
 * phpcs:disable PSR1.Files.SideEffects
 */

defined('ABSPATH') || exit;

// Load the actual plugin — only if it is really there. (Whether the FRAMEWORK
// is present is a separate question, and ntdst-baseline answers it itself: it
// skips its own boot silently when ntdst_get() is absent, per FR-20/AC-9.)
if (!file_exists(__DIR__ . '/ntdst-baseline/ntdst-baseline.php')) {
    error_log(
        'ntdst-baselineloader: netdust/ntdst-baseline is not installed at '
        . __DIR__ . '/ntdst-baseline/ — run `composer install`. '
        . 'Security headers, SEO tags, schema and cache headers are NOT active.'
    );

    add_action('admin_notices', static function (): void {
        echo '<div class="notice notice-error"><p><strong>NTDST Baseline is missing.</strong> '
            . 'The <code>netdust/ntdst-baseline</code> composer package is not installed, so '
            . 'security headers, SEO tags and schema are inactive. Run <code>composer install</code> '
            . 'on this server.</p></div>';
    });

    return;
}

require_once __DIR__ . '/ntdst-baseline/ntdst-baseline.php';
