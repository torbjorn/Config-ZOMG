#!/bin/sh

perl -Mlib=../Config-Loader/lib \
  -MPackage::Alias=Config::ZOMG,Config::Loader \
 t/10-loader.t
