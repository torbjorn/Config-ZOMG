package Config::ZOMG;

# ABSTRACT: Yet Another Catalyst::Plugin::ConfigLoader-style layer over Config::Any

use Moo;
use Sub::Quote 'quote_sub';

## Makes hacking easier, shouldn't hurt anyone
use lib '../Config-Loader/lib';
use Config::Loader;

use Config::Any;

use MooX::HandlesVia;

has package => (
   is => 'ro',
);

has load_once => (
   is => 'ro',
   default => quote_sub q{ 1 },
);

has default => (
   is => 'ro',
   default => quote_sub q[ {} ],
);

has path_to => (
   is => 'ro',
   reader => '_path_to',
   lazy => 1,
   builder => sub { $_[0]->load->{home} ||
                   !$_[0]->path_is_file && $_[0]->path ||
                    "."
                },
);

has source => (
    is => 'lazy',
    clearer => 1,
    predicate => 1,
    builder => sub {

        my $self = shift;

        # my @sources = map {
        #     [ File => { file => $_ } ],
        # } $self->_find_files;

        return Config::Loader->new_source
            ( "Files",
              default => $self->default,
              files => [ $self->_find_files ],
          );

      },
);

## Moo attributes from the original ::Loader

has name => (
   is => 'rw',
);

has path => (
   is => 'ro',
   default => quote_sub q{ '.' },
);

has driver => (
   is => 'ro',
   default => quote_sub q[ {} ],
);

has local_suffix => (
   is => 'ro',
   default => quote_sub q{ 'local' },
);

has no_env => (
   is => 'ro',
   default => quote_sub q{ 0 },
);

has no_local => (
   is => 'ro',
   default => quote_sub q{ 0 },
);

has env_lookup => (
   is => 'ro',
   ## puts it in an array ref if receives a scalar
   coerce => sub { ref $_[0] eq "ARRAY" && $_[0] || [$_[0]] },
   handles_via => "Array",
   handles => { "env_lookups" => "elements" },
   default => quote_sub q{ [] },
);

has path_is_file => (
   is => 'ro',
   default => quote_sub q{ 0 },
);

has _config => (
   is => 'rw',
);

sub BUILD {
    my $self = shift;
    my $given = shift;

    if ($given->{file}) {

        $self->{path_is_file} = 1;
        $self->{path} = $given->{file};

        if ( exists $given->{local_suffix} ) {
            warn "Warning, 'local_suffix' will be ignored if 'file' is given, use 'path' instead"
        }

    }

}

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
    warn "You called ->open on an instantiated object with arguments" if @_;
    my $config_hash = $self->load;
    return unless $self->found;
    return wantarray ? ($config_hash, $self) : $config_hash;
}

## Files found after loading
sub found {
    my $self = shift;
    return unless $self->has_source;
    return ( map { $_->[1]{file} } @{ $self->source->sources } );
}

## Any files that would be found
sub find {
    my $self = shift;
    return grep -f, $self->_find_files;
}

sub load {
    my $self = shift;
    return $self->_config if $self->has_source && $self->load_once;
    $self->_config( $self->source->load_config );
    return $self->_config;
}

## Functions for internal use
sub _find_files { # Doesn't really find files...hurm...
    my $self = shift;

    if ( $self->path_is_file ) {
        my $path = $self->_env_lookup('CONFIG') unless $self->no_env;
        $path ||= $self->path;
        return (grep -r, $path);
    }
    else {
        my ($path, $extension) = $self->_get_path;
        my $local_suffix = $self->_get_local_suffix;
        my @extensions = @{ Config::Any->extensions };
        my $no_local = $self->no_local;

        my @files;
        if ($extension) {
            die "Can't handle file extension $extension" unless grep { $_ eq $extension } @extensions;
            push @files, $path;
            unless ($no_local) {
                (my $local_path = $path) =~ s{\.$extension$}{_$local_suffix.$extension};
                push @files, $local_path;
            }
        }
        else {
            push @files, map { "$path.$_" } @extensions;
            push @files, map { "${path}_${local_suffix}.$_" } @extensions unless $no_local;
        }

        my (@cfg, @local_cfg);
        for (sort @files) {

            if (m{$local_suffix\.}ms) {
                push @local_cfg, $_;
            } else {
                push @cfg, $_;
            }

        }

        my @final_files = $no_local ?
            @cfg : (@cfg, @local_cfg);

        @final_files = grep -r, @final_files;

        return @final_files;
    }
}
sub _get_local_suffix {
    my $self = shift;

    my $name = $self->name;
    my $suffix;
    $suffix = $self->_env_lookup('CONFIG_LOCAL_SUFFIX') unless
        $self->no_env;
    $suffix ||= $self->local_suffix;

    return $suffix;
}
sub _env_lookup {
    my $self = shift;
    my @suffix = @_;

    for my $prefix ( grep defined, ($self->name,$self->env_lookups)) {
        my $value = _env($prefix, @suffix);
        return $value if defined $value;
    }

    return;
}
sub _env (@) {
    my $key = uc join "_", @_;
    $key =~ s/::/_/g;
    $key =~ s/\W/_/g;
    return $ENV{$key};
}
sub _get_path {
    my $self = shift;

    my $name = $self->name;
    my $path;
    $path = $self->_env_lookup('CONFIG') unless $self->no_env;
    $path ||= $self->path;

    my $extension = file_extension( $path );

    if (-d $path) {
        $path =~ s{[\/\\]$}{}; # Remove any trailing slash, e.g. apple/ or apple\ => apple
        $path .= "/$name"; # Look for a file in path with $self->name, e.g. apple => apple/name
    }

    return ($path, $extension);
}
sub file_extension ($) {
    my $path = shift;
    return if -d $path;
    my ($extension) = $path =~ m{\.([^/\.]{1,4})$};
    return $extension;
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
