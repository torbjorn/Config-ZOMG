use strict;
use warnings;

use Test::More;
use Test::Warn;

use lib '../Config-Loader/lib';
use Config::Loader;

sub has_Config_General {
    return eval "require Config::General;";
}

{
    my $config = Config::Loader->open( 't/assets/some_random_file.pl' );
    ok( $config );
    ok( keys %{ $config } );
}

{
    my $config = Config::Loader->open( qw{ name xyzzy path t/assets } );
    ok( $config );
    ok( keys %{ $config } );
}

{
    my $config = Config::Loader->open( 't/assets/missing-file.pl' );
    ok( ! $config );
}

{
    my $config = Config::Loader->new(
        file => 't/assets/some_random_file.pl'
    );
    warning_like { $config->open( '...' ) } qr/You called ->open on an instantiated object with arguments/;
}

{
    my ($config_hash, $config) = Config::Loader->open( qw{ name xyzzy path t/assets } );
    ok( $config_hash );
    is( ref $config_hash, 'HASH' );
    ok( $config->isa('Config::Loader') );
}

done_testing;
