package Config::ZOMG;

# ABSTRACT: Yet Another Catalyst::Plugin::ConfigLoader-style layer over Config::Any

use Moo;
use Sub::Quote 'quote_sub';

use Carp;
use Config::ZOMG::CLSource;
use Config::Any;

use MooX::HandlesVia;

has package => (
   is => 'ro',
);

has load_once => (
   is => 'ro',
   default => quote_sub q{ 1 },
);

has path_to => (
   is => 'ro',
   reader => '_path_to',
   lazy => 1,
   builder => sub { $_[0]->load->{home} ||
                   !$_[0]->source->path_is_file && $_[0]->source->path ||
                    "."
                },
);

has source => (
    is => 'ro',
    clearer => 1,
    predicate => 1,
    lazy => 1,
    handles => [qw/default load_config/],
    builder => sub { $_[0]->source_builder->() },
);

has source_builder => (
    is => 'ro'
);

has driver => (
   is => 'ro',
   default => quote_sub q[ {} ],
);
has _config => (
   is => 'rw',
);

### Functions from API ###
sub clone {
    require Clone;
    Clone::clone($_[0]->config);
}

sub reload {
    my $self = shift;
    $self->clear_source;
    return $self->load;
}

sub open {
    unless ( ref $_[0] ) {
        my $class = shift;
        return $class->new( @_ == 1 ? (file => $_[0]) : @_ )->open;
    }
    my $self = shift;
    carp "You called ->open on an instantiated object with arguments" if @_;
    my $config_hash = $self->load;
    return unless $self->found;
    return wantarray ? ($config_hash, $self) : $config_hash;
}

## Files found after loading
sub found {
    my $self = shift;
    return unless $self->has_source;
    return @{ $self->source->files_loaded };
}

## Any files that would be found
sub find {
    my $self = shift;
    my $clear_it_after = not $self->has_source;
    my @files = grep -f, $self->source->_find_files;
    $self->clear_source if $clear_it_after;
    return @files;
}

sub load {
    my $self = shift;
    return $self->_config if $self->load_once and $self->has_source;
    $self->_config( $self->load_config );
    return $self->_config;
}

## Functions for internal use

sub BUILD {

    my ($self,$args) = (shift,shift);

    my $source_builder = sub {

        my @params = qw/name path file path_is_file local_suffix
                        no_env no_local env_lookup default/;
        my %source_args = map { $_, $args->{$_} } grep exists $args->{$_}, @params;

        return Config::ZOMG::CLSource->new(%source_args);

    };

    $self->{source_builder} = $source_builder;

    ## This builder allows the source to be cleared and rebuilt later,
    ## it needs this to support ->reload. C::L sources do not easily
    ## clear their sources. Recreating seems the best option.  The
    ## MooX::ObjectBuilder that tobyink released now can take care of
    ## this without needing an extra attribute to hold the sub.
}

1;

=head1 SYNPOSIS

 use Config::ZOMG;

 my $config = Config::ZOMG->new(
   name => 'my_application',
   path => 'path/to/my/application',
 );
 my $config_hash = $config->load;

This will look for something like (depending on what L<Config::Any> will find):

 path/to/my/application/my_application_local.{yml,yaml,cnf,conf,jsn,json,...}

and

 path/to/my/application/my_application.{yml,yaml,cnf,conf,jsn,json,...}

... and load the found configuration information appropiately, with C<_local>
taking precedence.

You can also specify a file directly:

 my $config = Config::ZOMG->new(file => '/path/to/my/application/my_application.cnf');

To later reload your configuration:

 $config->reload;

=head1 DESCRIPTION

C<Config::ZOMG> is a fork of L<Config::JFDI>.  It removes a couple of unusual
features and passes the same tests three times faster than L<Config::JFDI>.

C<Config::ZOMG> is an implementation of L<Catalyst::Plugin::ConfigLoader>
that exists outside of L<Catalyst>.

C<Config::ZOMG> will scan a directory for files matching a certain name. If
such a file is found which also matches an extension that L<Config::Any> can
read, then the configuration from that file will be loaded.

C<Config::ZOMG> will also look for special files that end with a C<_local>
suffix. Files with this special suffix will take precedence over any other
existing configuration file, if any. The precedence takes place by merging
the local configuration with the "standard" configuration via
L<Hash::Merge::Simple>.

Finally you can override/modify the path search from outside your application,
by setting the C<< ${NAME}_CONFIG >> variable outside your application (where
C<$NAME> is the uppercase version of what you passed to
L<< Config::ZOMG->new|/new >>).

=head1 METHODS

=head2 new

 $config = Config::ZOMG->new(...)

Returns a new C<Config::ZOMG> object

You can configure the C<$config> object by passing the following to new:

=over 2

=item name

The name specifying the prefix of the configuration file to look for and
the ENV variable to read. This can be a package name. In any case, ::
will be substituted with _ in C<name> and the result will be lowercased.
To prevent modification of C<name>, pass it in as a scalar reference.

=item C<path>

The directory to search in

=item C<file>

Directly read the configuration from this file. C<Config::Any> must recognize
the extension. Setting this will override C<path>

=item C<no_local>

Disable lookup of a local configuration. The C<local_suffix> option will be
ignored. Off by default

=item C<local_suffix>

The suffix to match when looking for a local configuration. C<local> by default

=item C<no_env>

Set this to ignore ENV. C<env_lookup> will be ignored. Off by default

=item C<env_lookup>

Additional ENV to check if C<< $ENV{<NAME>...} >> is not found

=item C<driver>

A hash consisting of C<Config::> driver information. This is passed directly
through to C<Config::Any>

=item C<default>

A hash filled with default keys/values

=back

=head2 open

 $config_hash = Config::ZOMG->open( ... )

As an alternative way to load a config C<open> will pass given arguments to
L</new> then attempt to do L</load>

Unlike L</load> if no configuration files are found C<open> will return
C<undef> (or the empty list)

This is so you can do something like:

 my $config_hash = Config::ZOMG->open( '/path/to/application.cnf' )
   or die "Couldn't find config file!"

In scalar context C<open> will return the config hash, B<not> the config
object. If you want the config object call C<open> in list context:

    my ($config_hash, $config) = Config::ZOMG->open( ... )

You can pass any arguments to C<open> that you would to L</new>

=head2 load

 $config->load

Load a config as specified by L</new> and C<ENV> and return a hash

This will only load the configuration once, so it's safe to call multiple
times without incurring any loading-time penalty

=head2 found

 $config->found

Returns a list of files found

If the list is empty then no files were loaded/read

=head2 find

  $config->find

Returns a list of files that configuration will be loaded from. Use this method
to check whether configuration files have changed, without actually reloading.

=head2 clone

 $config->clone

Return a clone of the configuration hash using L<Clone>

This will load the configuration first, if it hasn't already

=head2 reload

 $config->reload

Reload the configuration, examining ENV and scanning the path anew

Returns a hash of the configuration

=head1 SEE ALSO

L<Config::JFDI>

L<Catalyst::Plugin::ConfigLoader>

L<Config::Any>

L<Catalyst>

L<Config::Merge>

L<Config::General>

=cut
