<?php

/**
 * Plugin Name: NTDST Core Loader
 * Description: Loads the NTDST Core framework (composer package
 * netdust/ntdst-core) from its subdirectory.
 * Version: 1.1.0
 * Author: Netdust
 *
 * mu-plugins cannot live in subdirectories on their own, so this thin shim
 * requires the real entrypoint.
 *
 * The framework is composer-installed and GITIGNORED in consumer projects,
 * which means a deploy bundle carries this shim but not the package. If
 * `composer install` has not run — or could not run, e.g. the server has no
 * SSH key with read access to the private netdust org — the target file does
 * not exist. A bare `require_once` then fatals inside `wp-settings.php`, and
 * because mu-plugins load before everything, the result is a white screen
 * across the whole site INCLUDING wp-admin, with no way back in without shell
 * access. The guard below turns that into a site that still boots and says
 * why. Never remove it in the name of brevity.
 *
 * phpcs:disable PSR1.Files.SideEffects
 */

defined('ABSPATH') || exit;

if (!file_exists(__DIR__ . '/ntdst-core/ntdst-core.php')) {
    error_log(
        'ntdst-coreloader: netdust/ntdst-core is not installed at '
        . __DIR__ . '/ntdst-core/ — run `composer install`. '
        . 'The framework is NOT loaded; anything depending on it will fail.'
    );

    add_action('admin_notices', static function (): void {
        echo '<div class="notice notice-error"><p><strong>NTDST Core is missing.</strong> '
            . 'The <code>netdust/ntdst-core</code> composer package is not installed, so the '
            . 'framework did not load. Run <code>composer install</code> on this server.</p></div>';
    });

    return;
}

require_once __DIR__ . '/ntdst-core/ntdst-core.php';
