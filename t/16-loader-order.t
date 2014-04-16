use strict;
use warnings;

use Test::More;

plan skip_all => "Config::General is required for this test" unless eval "require Config::General;";

use Config::ZOMG;

$ENV{CONFIG_LOADER_SOURCE_FILE_MANY_FILES_ALLOW} = 1;

my $config = Config::ZOMG->new(qw{ name xyzzy path t/assets/order });

ok($config->load);
is($config->load->{'last'}, 'local_pl');
is($config->load->{$_}, 1) for qw/pl perl local_pl local_perl cnf local_cnf conf local_conf/;

done_testing;
