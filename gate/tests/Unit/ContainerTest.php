<?php

declare(strict_types=1);

namespace NtdstTests\Unit;

use NTDST_Container;
use RuntimeException;

/** Zero-dependency fixture for resolution tests. */
final class ContainerTestService
{
    public string $tag = 'default';
}

/** Depends on itself — the shape the circular-dependency guard exists for. */
final class ContainerCircularService
{
    public function __construct(ContainerCircularService $self)
    {
    }
}

/**
 * Behavioral contract of NTDST_Container (ntdst-core), exercised with
 * no WordPress and no database — the example unit for the PHP unit tier.
 *
 * Tracks the post-trim container: set, get, has. `make()` and `forget()` were
 * removed from ntdst-core in `feat(core-trim): T07 — Container keeps
 * set/get/has`, and the three tests covering them were obsolete rather than
 * failing — they errored against every 5.x install. Every assertion below is
 * derived from core/Container.php as it actually is; do not reinstate a test
 * for behaviour the framework dropped.
 */
final class ContainerTest extends TestCase
{
    private NTDST_Container $container;

    protected function setUp(): void
    {
        parent::setUp();
        $this->container = new NTDST_Container();
    }

    public function test_get_caches_the_resolved_instance_as_a_singleton(): void
    {
        $this->container->set(ContainerTestService::class);

        $first = $this->container->get(ContainerTestService::class);
        $second = $this->container->get(ContainerTestService::class);

        $this->assertSame($first, $second);
    }

    public function test_has_covers_registered_ids_and_autowirable_classes(): void
    {
        $this->container->set('registered.id', 'a primitive');

        $this->assertTrue($this->container->has('registered.id'));
        // PSR-11 semantics here: an unregistered class that exists can be
        // autowired, so has() promises get() will not throw for it.
        $this->assertTrue($this->container->has(ContainerTestService::class));
        $this->assertFalse($this->container->has('totally.unknown'));
    }

    public function test_factory_closure_receives_the_container_itself(): void
    {
        $received = null;
        $this->container->set('tagged.service', function (NTDST_Container $c) use (&$received): ContainerTestService {
            $received = $c;
            $service = new ContainerTestService();
            $service->tag = 'built-by-factory';

            return $service;
        });

        $resolved = $this->container->get('tagged.service');

        $this->assertSame($this->container, $received);
        $this->assertInstanceOf(ContainerTestService::class, $resolved);
        $this->assertSame('built-by-factory', $resolved->tag);
    }

    public function test_get_throws_for_an_unknown_service_id(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Service totally.unknown not found');

        $this->container->get('totally.unknown');
    }

    public function test_get_detects_a_circular_dependency(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Circular dependency detected');

        $this->container->get(ContainerCircularService::class);
    }

    public function test_a_binding_pointing_at_a_missing_class_fails_loudly(): void
    {
        // A typo'd class binding must not be mistaken for a primitive string
        // value — that distinction is what looksLikeClassName() is for.
        $this->container->set('mistyped.binding', 'NtdstTests\Unit\NoSuchService');

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('points to non-existent class');

        $this->container->get('mistyped.binding');
    }
}
