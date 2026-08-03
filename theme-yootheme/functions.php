<?php
/**
 * {{SLUG_TITLE}} Theme — Functions
 *
 * Clean Bedrock starter wired into ntdst-core (Tailwind + Alpine + Vite).
 *
 * Wiring pattern (mirrors stridence, minus all LMS/domain code):
 *   1. Define theme constants.
 *   2. Load helper functions.
 *   3. Register NTDST_Bootstrap from theme-config.php, boot core @5 / features @15.
 *   4. Hand theme setup (menus, image sizes, support, ...) to NTDST_Theme.
 *   5. Bind the frontend hook classes to the theme.
 *
 * @package {{SLUG}}
 */

defined('ABSPATH') || exit;

// ========================================
// CONSTANTS
// ========================================

define('{{SLUG_CONST}}_VERSION', '1.0.0');
define('{{SLUG_CONST}}_DIR', get_stylesheet_directory());
define('{{SLUG_CONST}}_URI', get_stylesheet_directory_uri());

// ========================================
// LOAD HELPERS
// ========================================

require_once {{SLUG_CONST}}_DIR . '/helpers/icons.php';
require_once {{SLUG_CONST}}_DIR . '/helpers/formatting.php';
require_once {{SLUG_CONST}}_DIR . '/helpers/templates.php';

// ========================================
// BOOTSTRAP (NTDST Core Integration)
// ========================================

$config = require {{SLUG_CONST}}_DIR . '/theme-config.php';

// Create and register bootstrap instance (from ntdst-core)
if (class_exists('NTDST_Bootstrap')) {
    $bootstrap = new NTDST_Bootstrap($config);
    $bootstrap->register();
    ntdst_set(NTDST_Bootstrap::class, fn() => $bootstrap);

    // Boot core services (priority 5)
    add_action('after_setup_theme', fn() => $bootstrap->bootCore(), 5);

    // Boot feature services (priority 15)
    add_action('after_setup_theme', fn() => $bootstrap->bootFeatures(), 15);
}

// Hand theme setup to NTDST_Theme: title-tag, html5, custom-logo,
// menus, image sizes, sidebars, excerpt and content width are all
// driven by theme-config.php.
if (class_exists('NTDST_Theme')) {
    new NTDST_Theme([
        'textdomain'    => $config['theme']['textdomain'] ?? '{{SLUG}}',
        'content_width' => $config['theme']['content_width'] ?? 1280,
        'theme_support' => $config['support'] ?? [],
        'image_sizes'   => $config['image_sizes'] ?? [],
        'menus'         => $config['menus'] ?? [],
        'sidebars'      => $config['sidebars'] ?? [],
        'excerpt'       => $config['excerpt'] ?? ['length' => 55, 'more' => ''],
        'assets'        => $config['assets'] ?? ['styles' => [], 'scripts' => []],
    ]);
}

// ========================================
// HOOKS (bound to NTDST_Theme)
// ========================================

require_once __DIR__ . '/services/frontend/hooks/AssetHooks.php';

if (class_exists('NTDST_Theme')) {
    $theme = ntdst_get(\NTDST_Theme::class);
    (new \{{SLUG_SNAKE}}\services\frontend\hooks\AssetHooks())->bind($theme);
}

// ========================================
// PARENT (YOOtheme) STYLESHEET
// ========================================

/**
 * Load the parent (YOOtheme) stylesheet, then this child's own style.css after
 * it. Priority 20 so it lands after YOOtheme's own enqueues.
 *
 * NOTE: brand fonts are NOT enqueued here. They are picked in
 * Customizer -> Theme -> Style -> Fonts, and YOOtheme's StyleFontLoader
 * downloads and SELF-HOSTS the woff2 files. A wp_enqueue_style for the same
 * families would load them twice, and from Google's CDN instead of this server.
 */
add_action('wp_enqueue_scripts', static function (): void {
    wp_enqueue_style(
        'yootheme',
        get_template_directory_uri() . '/style.css',
        [],
        wp_get_theme(get_template())->get('Version') ?: null,
    );

    $child_css = {{SLUG_CONST}}_DIR . '/style.css';
    wp_enqueue_style(
        '{{SLUG}}-child',
        {{SLUG_CONST}}_URI . '/style.css',
        ['yootheme'],
        file_exists($child_css) ? (string) filemtime($child_css) : {{SLUG_CONST}}_VERSION,
    );
}, 20);
