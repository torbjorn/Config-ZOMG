#!/bin/sh

perl -Mlib=../Config-Loader/lib  -e 'use Package::Alias "Config::ZOMG" => "Config::Loader"; do q{t/12-loader-file.t}'
