use strict;
use warnings;

use Test::More;
plan qw/no_plan/;

use lib '../Config-Loader/lib';
use Config::Loader;
my $config;

$config = Config::Loader->new(
    qw{ name default path t/assets },
    default => {
        home => 'a-galaxy-far-far-away',
        test => 'alpha',
    },
);

is($config->load->{home}, 'a-galaxy-far-far-away');
is($config->load->{path_to}, '__path_to(tatooine)__');
is($config->load->{test}, 'beta');
