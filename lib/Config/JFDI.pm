package Config::JFDI;

use warnings;
use strict;

=head1 NAME

Config::JFDI - Just * Do it: A Catalyst::Plugin::ConfigLoader-style layer over Config::Any

=head1 VERSION

Version 0.01

=head1 SYNPOSIS 

    use Config::JFDI;

    my $config = Config::JFDI->new(name => "my_application", path => "path/to/my/application");
    my $config_hash = $config->get;

This will look for something like (depending on what Config::Any will find):

    path/to/my/application/my_application_local.{yml,yaml,cnf,conf,jsn,json,...} AND

    path/to/my/application/my_application.{yml,yaml,cnf,conf,jsn,json,...}

... and load the found configuration information appropiately, with _local taking precedence.

You can also specify a file directly:

    my $config = Config::JFDI->new(file => "/path/to/my/application/my_application.cnf");

To later reload your configuration, fresh from disk:
    
    $config->reload;

=head1 DESCRIPTION

Config::JFDI is an implementation of L<Catalyst::Plugin::ConfigLoader> that exists outside of L<Catalyst>.

Essentially, Config::JFDI will scan a directory for files matching a certain name. If such a file is found which also matches an extension
that Config::Any can read, then the configuration from that file will be loaded.

Config::JFDI will also look for special files that end with a "_local" suffix. Files with this special suffix will take
precedence over any other existing configuration file, if any. The precedence takes place by merging the local configuration with the
"standard" configuration via L<Hash::Merge::Simple>.

Finally, you can override/modify the path search from outside your application, by setting the <NAME>_CONFIG variable outside your application (where <NAME>
is the uppercase version of what you passed to Config::JFDI->new).

=head1 METHODS

=cut

our $VERSION = '0.01';

use Moose;
use Path::Class;
use Config::Any;
use List::MoreUtils qw/any/;
use Hash::Merge::Simple;
use Carp::Clan;
use Clone qw//;

has name => qw/is ro isa Str/; # Actually, required unless ->file is given
has path => qw/is ro isa Str/, default => "./"; # Can actually be a path (./my/, ./my) OR a bonafide file (i.e./my.yaml)
has driver => qw/is ro required 1 lazy 1/, default => sub { {} };
has local_suffix => qw/is ro required 1 lazy 1/, default => "local";
has no_env => qw/is ro required 1/, default => 0;
has load_once => qw/is ro required 1/, default => 1;

has loaded => qw/is ro required 1/, default => 0;
has _config => qw/is ro required 1 lazy 1/, default => sub { {} };

# TODO Maybe in the... future-ure-ure-ure...
#has driver_name => qw/is ro isa Str/;
#has driver_class => qw/is ro isa Str/;

sub _env(@) {
    my $name = uc join "_", @_;
    $name =~ s/\W/_/g;
    return $ENV{$name};
}

=head2 my $config = Config::JFDI->new(...)

You can configure the $config object by passing the following to new:

    name                The name specifying the prefix of the configuration file to look for and 
                        the ENV variable to read

    path                The directory to search in

    file                Directly read the configuration from this file. Config::Any must recognize
                        the extension. Setting this will override path

    local_suffix        The suffix to match when looking for a local configuration. "local" By default

    no_env              Set this to 1 to disregard anything in the ENV. Off by default

    driver              A hash consisting of Config:: driver information. This is passed directly through
                        to Config::Any

Returns a new Config::JFDI object

=cut

sub BUILD {
    my $self = shift;
    my $given = shift;

    if ($given->{file}) {
        warn "Warning, overriding path setting with file (\"$given->{file}\" instead of \"$given->{path}\")" if $given->{path};
        $self->{path} = $given->{file};
    }
    elsif ($given->{name}) {
    }
    else {
        croak "At minimum, either a name or a file is required";
    }
}

=head2 $config->get

=head2 $config->config

=head2 $config->load

Load a config as specified by ->new(...) and ENV and return a hash

These will only load the configuration once, so it's safe to call them multiple times without incurring any loading-time penalty

=cut

sub get {
    my $self = shift;
    my $config = $self->config;
    return $config;
    # TODO Expand to allow dotted key access
}

sub config {
    my $self = shift;
    return $self->_config if $self->loaded;
    return $self->load;
}

sub load {
    my $self = shift;
    if ($self->loaded && $self->load_once) {
        return $self->get;
    }
    $self->{_config} = {};
    my @files = $self->_find_files;
    my $cfg = $self->_load_files(\@files);

    my (@cfg, @local_cfg);
    {
        # Anything that is local takes precedence
        my $local_suffix = $self->_get_local_suffix;
        for (@$cfg) {
            if ((keys %$_)[0] =~ m{$local_suffix\.}xms) {
                push @local_cfg, $_;
            }
            else {
                push @cfg, $_;
            }
        }
    }

    $self->_load($_) for @cfg, @local_cfg;

    $self->{loaded} = 1;

    return $self->config;
}

=head2 $config->clone

Return a clone of the configuration hash using L<Clone>

This will load the configuration first, if it hasn't already

=cut

sub clone {
    my $self = shift;
    return Clone::clone($self->config);
}

=head2 $config->reload

Reload the configuration, examining ENV and scanning the path anew

Returns a hash of the configuration

=cut 

sub reload {
    my $self = shift;
    $self->{loaded} = 0;
    return $self->load;
}

sub _load {
    my $self = shift;
    my $cfg = shift;

    my ($file, $hash) = %$cfg;

    $self->{_config} = Hash::Merge::Simple->merge($self->_config, $hash);
}

sub _load_files {
    my $self = shift;
    my $files = shift;
    return Config::Any->load_files({
        files => $files,
        use_ext => 1,
        driver_args => $self->driver,
    });
}

sub _find_files {
    my $self = shift;

    my ($path, $extension) = $self->_get_path;
    my $local_suffix = $self->_get_local_suffix;
    my @extensions = $self->_get_extensions;
    
    my @files;
    if ($extension) {
        # TODO Make sure DBIC can handle ->create({}) case ("INSERT INTO xyzzy () VALUES ()")
        # FIXME C::P::ConfigLoader does a next here!
        croak "Can't handle file extension $extension" unless any { $_ eq $extension } @extensions;
        (my $local_path = $path) =~ s{\.$extension$}{_$local_suffix.$extension};
        push @files, $path, $local_path;
    }
    else {
        @files = map { ( "$path.$_", "${path}_${local_suffix}.$_" ) } @extensions;
    }

    return @files;
}

sub _get_path {
    my $self = shift;

    my $name = $self->name;
    my $path;
    $path = _env($name, 'CONFIG') if $name && ! $self->no_env;
    $path ||= $self->path;

    # TODO Uhh, what if path is -d? 
    my ($extension) = ($path =~ m{\.(.{1,4})$});

    if (-d $path) {
        $path =~ s{[\/\\]$}{}; # Remove any trailing slash, e.g. apple/ or apple\ => apple
        $path .= "/$name"; # Look for a file in path with $self->name, e.g. apple => apple/name
    }

    return ($path, $extension);
}

sub _get_local_suffix {
    my $self = shift;

    my $name = $self->name;
    my $suffix;
    $suffix = _env($self->name, 'CONFIG_LOCAL_SUFFIX') if $name && ! $self->no_env;
    $suffix ||= $self->local_suffix;

    return $suffix;
}

sub _get_extensions {
    return @{ Config::Any->extensions }
}

=head1 SYNOPSIS

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

=head1 SEE ALSO

L<Catalyst::Plugin::ConfigLoader>, L<Config::Any>, L<Catalyst>

=head1 BUGS

Please report any bugs or feature requests to C<bug-config-jfdi at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Config-JFDI>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Config::JFDI


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Config-JFDI>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Config-JFDI>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Config-JFDI>

=item * Search CPAN

L<http://search.cpan.org/dist/Config-JFDI>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Robert Krimen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Config::JFDI

__END__

sub get_config_path {
    my $c = shift;

    # deprecation notice
    if ( exists $c->config->{ file } ) {
        $c->log->warn(
            q(*** "file" config parameter has been deprecated in favor of "$c->config->{ 'Plugin::ConfigLoader' }->{ file }")
        );
        sleep( 3 );
    }

    my $appname = ref $c || $c;
    my $prefix  = Catalyst::Utils::appprefix( $appname );
    my $path    = Catalyst::Utils::env_value( $c, 'CONFIG' )
        || $c->config->{ 'Plugin::ConfigLoader' }->{ file }
        || $c->config->{ file }    # to be removed next release
        || $c->path_to( $prefix );

    my ( $extension ) = ( $path =~ m{\.(.{1,4})$} );

    if ( -d $path ) {
        $path =~ s{[\/\\]$}{};
        $path .= "/$prefix";
    }

    return ( $path, $extension );

sub setup {
    my $c     = shift;
    my @files = $c->find_files;
    my $cfg   = Config::Any->load_files(
        {   files       => \@files,
            filter      => \&_fix_syntax,
            use_ext     => 1,
            driver_args => $c->config->{ 'Plugin::ConfigLoader' }->{ driver }
                || {},
        }
    );

    # split the responses into normal and local cfg
    my $local_suffix = $c->get_config_local_suffix;
    my ( @cfg, @localcfg );
    for ( @$cfg ) {
        if ( ( keys %$_ )[ 0 ] =~ m{ $local_suffix \. }xms ) {
            push @localcfg, $_;
        }
        else {
            push @cfg, $_;
        }
    }

    # load all the normal cfgs, then the local cfgs last so they can override
    # normal cfgs
    $c->load_config( $_ ) for @cfg, @localcfg;

    $c->finalize_config;
    $c->NEXT::setup( @_ );
}

