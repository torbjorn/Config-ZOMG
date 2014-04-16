package Config::ZOMG::CLSource;

use Moo;
use MooX::HandlesVia;
use namespace::clean;

use File::Basename qw/fileparse/;
use File::Spec::Functions qw/catfile/;
use Sub::Quote 'quote_sub';

use Carp;

extends "Config::Loader::Source::Merged";

has default => (
   is => 'ro',
   default => quote_sub q[ {} ],
);
has name => (
   is => 'rw',
);
has path => (
   is => 'ro',
   default => quote_sub q{ '.' },
);
has path_is_file => (
   is => 'ro',
   default => quote_sub q{ 0 },
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
has '+sources' => (
    lazy => 1,
    builder => \&_build_sources,
);

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
sub _local_suffixed_filepath {

    my ($file,$local_suffix) = (shift,shift);

    die "local_suffix must be provided" unless defined $local_suffix;

    ## This assumes $file is a file or a stem. Cases where it
    ## is a directory needs to be explored later
    my( $name, $dirs, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

    my $new_with_local = $name . "_" . $local_suffix;

    my $new_local_file = catfile( $dirs, $new_with_local );

    $new_local_file .= $suffix ? $suffix : "";

    return $new_local_file;

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

sub _build_sources {

    my $self = shift;

    my $path = $self->_env_lookup('CONFIG') unless $self->no_env;
    $path ||= $self->path;

    my @sources;

    if ( $self->path_is_file ) {
        return [] unless -r $path;
        @sources = ( [File => { file => $path }] );
    }
    else {

        if (-d $path) {
            $path = catfile( $path, $self->name );
        }
        @sources = ( [File => { file => $path }] );

        if ( not $self->no_local ) {

            my $local_suffix = $self->_get_local_suffix;
            push @sources, [
                File => { file => _local_suffixed_filepath($path,$local_suffix) }
            ];

        }

    }

    return \@sources;

}

around BUILDARGS => sub {

    my ($orig,$self) = (shift,shift);

    my $args = $orig->($self,@_);

    if ( delete $args->{sources} ) {
        carp "Providing sources through constructor is not supported. Any values passed will be discarded.";
    }


    if ($args->{file}) {

        $args->{path_is_file} = 1;
        $args->{path} = delete $args->{file};

        if ( exists $args->{local_suffix} ) {
            carp "Warning, 'local_suffix' will be ignored if 'file' is given, use 'path' instead";
        }

    }

    if ( defined( my $name = $args->{name} )) {
        if (ref $name eq "SCALAR") {
            $name = $$name;
        } else {
            $name =~ s/::/_/g;
            $name = lc $name;
        }
        $args->{name} = $name;
    }

    return $args;

};

## Needed for _find_files
sub file_extension ($) {
    my $path = shift;
    return if -d $path;
    my ($extension) = $path =~ m{\.([^/\.]{1,4})$};
    return $extension;
}
sub _find_files { # Doesn't really find files...hurm...
    my $self = shift;

    if ($self->path_is_file) {
        my $path = $self->_env_lookup('CONFIG') unless $self->no_env;
        $path ||= $self->path;
        return ($path);
    }
    else {
        my ($path, $extension) = $self->_get_path;
        my $local_suffix = $self->_get_local_suffix;
        my @extensions = $self->_get_extensions;
        my $no_local = $self->no_local;

        my @files;
        if ($extension) {
            die "Can't handle file extension $extension" unless first { $_ eq $extension } @extensions;
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

        return @files;
    }
}
sub _get_extensions { @{ Config::Any->extensions } }
sub _get_path {
    my $self = shift;

    my $name = $self->name;
    my $path;
    $path = $self->_env_lookup('CONFIG') unless $self->no_env;
    $path ||= $self->path;

    my $extension = file_extension $path;

    if (-d $path) {
        $path =~ s{[\/\\]$}{}; # Remove any trailing slash, e.g. apple/ or apple\ => apple
        $path .= "/$name"; # Look for a file in path with $self->name, e.g. apple => apple/name
    }

    return ($path, $extension);
}
1;