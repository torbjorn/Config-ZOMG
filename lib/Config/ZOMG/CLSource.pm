package Config::ZOMG::CLSource;

use lib '../Config-Loader/lib';

use Moo;
extends "Config::Loader::Source::Profile::Default";

has name => (
   is => 'rw',
);

with "Config::Loader::SourceRole::FileHelper";
with "Config::Loader::SourceRole::FileFromEnv";

## DEV AT HERE; CONTINUE MERGING MAIN CLASS INTO THIS, PREFERABLY AS
## NOT TOO COMPLEX ROLES

1;
