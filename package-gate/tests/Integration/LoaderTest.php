<?php

declare(strict_types=1);

namespace NtdstTests\Integration;

use WP_UnitTestCase;

/**
 * The package shape's own proof: the suite runs on the dedicated wptests database, and the
 * loader shim loaded the working copy at the repo root — never a composer-installed copy.
 */
final class LoaderTest extends WP_UnitTestCase
{
    public function test_suite_runs_against_the_dedicated_wptests_database(): void
    {
        global $wpdb;

        $this->assertSame(
            'wptests',
            $wpdb->dbname,
            'Integration suite must run against wptests — never the dev database.',
        );
        $this->assertStringStartsWith('wptests_', $wpdb->posts);
    }

    public function test_the_loader_shim_loaded_the_working_copy(): void
    {
        $this->assertContains(
            realpath(dirname(ABSPATH, 2) . '/{{PACKAGE}}.php'),
            array_map('realpath', get_included_files()),
        );
        $this->assertContains(
            realpath(WPMU_PLUGIN_DIR . '/{{PACKAGE}}loader.php'),
            array_map('realpath', wp_get_mu_plugins()),
        );
    }
}
