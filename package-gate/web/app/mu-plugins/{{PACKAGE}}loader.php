<?php

/**
 * Plugin Name: {{PACKAGE}} (working copy)
 * Description: The gate's loader shim — loads the package from the repo root, the code being
 * edited, never a composer-installed copy under mu-plugins/. Committed; the rest of web/ is not.
 */

defined('ABSPATH') || exit;

require_once dirname(__DIR__, 3) . '/{{PACKAGE}}.php';
