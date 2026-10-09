<?php

/**
 * Override keys of a Joomla configuration.php with a JSON object read from
 * stdin, keeping every other setting as it was.
 *
 * Usage: php joomla_config_set.php /path/to/configuration.php < overrides.json
 */

$path = $argv[1];
require $path;

$overrides = json_decode(stream_get_contents(STDIN), true, 512, JSON_THROW_ON_ERROR);
$settings = array_merge(get_object_vars(new JConfig()), $overrides);

$lines = array_map(
    fn ($key, $value) => "\tpublic \$$key = " . var_export($value, true) . ';',
    array_keys($settings),
    $settings
);

file_put_contents($path, "<?php\nclass JConfig {\n" . implode("\n", $lines) . "\n}\n");
