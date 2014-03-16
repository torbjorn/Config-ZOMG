#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Warn;

use lib '../Config-Loader/lib';
use Config::Loader;

my $config = Config::Loader->new( name => '' );
warning_is { $config->_path_to } undef;

done_testing;
