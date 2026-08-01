<?php
/**
 * 404 Template
 *
 * @package {{SLUG}}
 */

defined('ABSPATH') || exit;

get_header();
?>

<div class="container py-16">
    <?php
    {{SLUG_SNAKE}}_template_part('partials/empty-state', null, [
        'icon'    => 'search',
        'title'   => __('Pagina niet gevonden', '{{SLUG}}'),
        'message' => __('De pagina die je zoekt bestaat niet of is verplaatst.', '{{SLUG}}'),
        'action'  => __('Terug naar home', '{{SLUG}}'),
        'url'     => home_url('/'),
    ]);
    ?>
</div>

<?php
get_footer();
