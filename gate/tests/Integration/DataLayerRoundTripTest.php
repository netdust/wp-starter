<?php

declare(strict_types=1);

namespace NtdstTests\Integration;

use WP_Post;
use WP_UnitTestCase;

/**
 * Integration tier: exercises the ntdst-core Data layer against REAL
 * WordPress and the real (dedicated) wptests database.
 *
 * Every assertion here is behavior the unit tier's Brain Monkey explicitly
 * cannot provide: real wp_insert_post persistence, real prefixed post-meta
 * storage read back through WordPress itself, and the real hook dispatcher
 * firing the model's lifecycle action.
 */
final class DataLayerRoundTripTest extends WP_UnitTestCase
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

    public function test_data_model_create_persists_post_and_prefixed_meta_in_the_real_database(): void
    {
        $model = ntdst_data()->register('gate_item', [
            'label'       => 'Gate Item',
            'fields'      => ['score' => ['type' => 'int', 'required' => true]],
            'meta_prefix' => 'gate_',
        ]);

        // ntdst-core fires slash-separated lifecycle actions —
        // `ntdst/model/created`, never the underscore form. The listener takes
        // the real first argument so a changed signature surfaces here instead
        // of being swallowed by a zero-argument closure.
        $listener_calls = 0;
        $listener_post_type = null;
        add_action(
            'ntdst/model/created',
            function (string $post_type) use (&$listener_calls, &$listener_post_type): void {
                $listener_calls++;
                $listener_post_type = $post_type;
            }
        );

        $created = $model->create(['title' => 'Pilot item', 'score' => 42]);

        $this->assertNotWPError($created);

        // Persistence proven through WordPress itself, not the model's own
        // read path: the post row and the prefixed meta row really exist.
        $stored = get_post($created->ID);
        $this->assertInstanceOf(WP_Post::class, $stored);
        $this->assertSame('gate_item', $stored->post_type);
        $this->assertSame('Pilot item', $stored->post_title);
        $this->assertSame(42, (int) get_post_meta($created->ID, 'gate_score', true));

        // The REAL hook dispatcher fired the lifecycle action exactly once, and
        // handed it the post type it created.
        $this->assertSame(1, $listener_calls);
        $this->assertSame('gate_item', $listener_post_type);
    }

    public function test_create_rejects_missing_required_field_and_persists_nothing(): void
    {
        $model = ntdst_data()->register('gate_item', [
            'label'       => 'Gate Item',
            'fields'      => ['score' => ['type' => 'int', 'required' => true]],
            'meta_prefix' => 'gate_',
        ]);

        $result = $model->create(['title' => 'Item without a score']);

        $this->assertWPError($result);
        $this->assertSame('validation_failed', $result->get_error_code());

        // Denial is not cosmetic: NOTHING was written to the database.
        $orphans = get_posts([
            'post_type'   => 'gate_item',
            'post_status' => 'any',
            'numberposts' => -1,
        ]);
        $this->assertCount(0, $orphans);
    }
}
