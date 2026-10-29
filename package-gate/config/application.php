<?php

/**
 * The gate's bedrock-lite configuration for a package: WordPress boots from the package's own
 * root on the package's own DDEV project and reads only DDEV's environment — no .env, no
 * dotenv. A site keeps Bedrock's config/; this file exists so a package can host the gate.
 *
 * phpcs:disable PSR1.Files.SideEffects
 */

use Roots\WPConfig\Config;

$root_dir = dirname(__DIR__);
$webroot_dir = $root_dir . '/web';

$home = getenv('DDEV_PRIMARY_URL')
    ?: exit('package gate: DDEV_PRIMARY_URL is not set — this WordPress runs on the package\'s DDEV project only.');

define('WP_ENV', 'development');
Config::define('WP_ENVIRONMENT_TYPE', WP_ENV);

Config::define('WP_HOME', $home);
Config::define('WP_SITEURL', $home . '/wp');

Config::define('CONTENT_DIR', '/app');
Config::define('WP_CONTENT_DIR', $webroot_dir . Config::get('CONTENT_DIR'));
Config::define('WP_CONTENT_URL', Config::get('WP_HOME') . Config::get('CONTENT_DIR'));

Config::define('DB_NAME', 'db');
Config::define('DB_USER', 'db');
Config::define('DB_PASSWORD', 'db');
Config::define('DB_HOST', 'db');
Config::define('DB_CHARSET', 'utf8mb4');
Config::define('DB_COLLATE', '');
$table_prefix = 'wp_';

// Composer owns the WordPress under web/; deps:latest is the only update path.
Config::define('AUTOMATIC_UPDATER_DISABLED', true);
Config::define('DISALLOW_FILE_MODS', true);

Config::define('WP_DEBUG', true);
Config::define('WP_DEBUG_LOG', true);
Config::define('WP_DEBUG_DISPLAY', true);
Config::define('SCRIPT_DEBUG', true);
Config::define('WP_DISABLE_FATAL_ERROR_HANDLER', true);
ini_set('display_errors', '1');

Config::apply();

if (!defined('ABSPATH')) {
    define('ABSPATH', $webroot_dir . '/wp/');
}
