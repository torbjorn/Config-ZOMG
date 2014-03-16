#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Warn;

use lib '../Config-Loader/lib';
use Config::Loader;

warning_is { Config::Loader->new( local_suffix => 'local' ) } undef;
warning_like { Config::Loader->new( file => 'xyzzy',local_suffix => 'local' ) } qr/will be ignored if 'file' is given, use 'path' instead/;

done_testing;
