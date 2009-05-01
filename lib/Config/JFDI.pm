package Config::JFDI;

use warnings;
use strict;

=head1 NAME

Config::JFDI - Just * Do it: A Catalyst::Plugin::ConfigLoader-style layer over Config::Any

=head1 VERSION

Version 0.05

=cut

our $VERSION = '0.05';

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

use Moose;

use Config::JFDI::Source::Loader;

use Path::Class;
use Config::Any;
use Hash::Merge::Simple;
use Carp::Clan;
use Sub::Install;
use Data::Visitor::Callback;
use Clone qw//;

has package => qw/is ro isa Str/;

has reader => qw/is ro/, handles => [qw/ driver local_suffix no_env env_lookup path /];

#has driver => qw/is ro lazy_build 1/;
#sub _build_driver {
#    return {};
#}

#has local_suffix => qw/is ro required 1 lazy 1 default local/;

#has no_env => qw/is ro required 1/, default => 0;

#has env_lookup => qw/is ro/, default => sub { [] };

has load_once => qw/is ro required 1/, default => 1;

has loaded => qw/is ro required 1/, default => 0;

has substitution => qw/reader _substitution lazy_build 1 isa HashRef/;
sub _build_substitution {
    return {};
}

has default => qw/is ro lazy_build 1 isa HashRef/;
sub _build_default {
    return {};
}

has path_to => qw/reader _path_to lazy_build 1 isa Str/;
sub _build_path_to {
    my $self = shift;
    return $self->config->{home} if $self->config->{home};
    return $self->{path} if -d $self->{path};
    return '.';
}

has _config => qw/is rw isa HashRef/;

=head2 my $config = Config::JFDI->new(...)

You can configure the $config object by passing the following to new:

    name                The name specifying the prefix of the configuration file to look for and 
                        the ENV variable to read. This can be a package name. In any case,
                        :: will be substituted with _ in <name> and the result will be lowercased.

                        To prevent modification of <name>, pass it in as a scalar reference.

    path                The directory to search in

    file                Directly read the configuration from this file. Config::Any must recognize
                        the extension. Setting this will override path

    local_suffix        The suffix to match when looking for a local configuration. "local" By default
                        ("config_local_suffix" will also work so as to be drop-in compatible with C::P::CL)

    env_lookup          Additional ENV to check if $ENV{<NAME>...} is not found

    no_env              Set this to 1 to disregard anything in the ENV. Off by default

    driver              A hash consisting of Config:: driver information. This is passed directly through
                        to Config::Any

    install_accessor    Set this to 1 to install a Catalyst-style accessor as <name>::config
                        You can also specify the package name directly by setting install_accessor to it 
                        (e.g. install_accessor => "My::Application")

    substitute          A hash consisting of subroutines called during the substitution phase of configuration
                        preparation. ("substitutions" will also work so as to be drop-in compatible with C::P::CL)
                        A substitution subroutine has the following signature: ($config, [ $argument1, $argument2, ... ])

    path_to             The path to dir to use for the __path_to(...)__ substitution. If nothing is given, then the 'home'
                        config value will be used ($config->get->{home}). Failing that, the current directory will be used.

    default             A hash filled with default keys/values

Returns a new Config::JFDI object

=cut

sub BUILD {
    my $self = shift;
    my $given = shift;

    $self->{package} = $given->{name} if defined $given->{name} && ! defined $self->{package} && ! ref $given->{name};

    my $reader;
    if ($given->{file}) {
        carp "Warning, overriding path setting with file (\"$given->{file}\" instead of \"$given->{path}\")" if $given->{path};
        $given->{path} = $given->{file};
        # TODO Do ::Read parsing
    }

    {
        my %any;
        for (qw/
            name
            path
            driver
            local_suffix
            no_env
            env_lookup
        /) {
            $any{$_} = $given->{$_} if exists $given->{$_};
        }

        $any{local_suffix} = $given->{config_local_suffix} if $given->{config_local_suffix};

        $reader = Config::JFDI::Source::Loader->new( %any );
    }

    $self->{reader} = $reader;

    for (qw/substitute substitutes substitutions substitution/) {
        if ($given->{$_}) {
            $self->{substitution} = $given->{$_};
            last;
        }
    }

    if (my $package = $given->{install_accessor}) {
        $package = $self->package if $package eq 1;
        Sub::Install::install_sub({
            code => sub {
                return $self->config;
            },
            into => $package,
            as => "config"
        });

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
    # TODO Expand to allow dotted key access (?)
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

    $self->_config($self->default);

    {
        my @read = $self->reader->read;

        $self->_load($_) for @read;
    }

    $self->{loaded} = 1;

    {
        my $visitor = Data::Visitor::Callback->new(
            plain_value => sub {
                return unless defined $_;
                $self->substitute($_);
            }
        );
        $visitor->visit($self->config);

    }

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

=head2 $config->substitute( <value>, <value>, ... )

For each given <value>, if <value> looks like a substitution specification, then run
the substitution macro on <value> and store the result.

There are three default substitutions (the same as L<Catalyst::Plugin::ConfigLoader>)

=over 4

=item * C<__HOME__> - replaced with C<$c-E<gt>path_to('')>

=item * C<__path_to(foo/bar)__> - replaced with C<$c-E<gt>path_to('foo/bar')>

=item * C<__literal(__FOO__)__> - leaves __FOO__ alone (allows you to use
C<__DATA__> as a config value, for example)

=back

The parameter list is split on comma (C<,>).

You can define your own substitutions by supplying the substitute option to ->new

=cut

sub substitute {
    my $self = shift;

    my $substitution = $self->_substitution;
    $substitution->{ HOME }    ||= sub { shift->path_to( '' ); };
    $substitution->{ path_to } ||= sub { shift->path_to( @_ ); };
    $substitution->{ literal } ||= sub { return $_[ 1 ]; };
    my $matcher = join( '|', keys %$substitution );

    for ( @_ ) {
        s{__($matcher)(?:\((.+?)\))?__}{ $substitution->{ $1 }->( $self, $2 ? split( /,/, $2 ) : () ) }eg;
    }
}

sub path_to {
    my $self = shift;
    my @path = @_;

    my $path_to = $self->_path_to;

    my $path = Path::Class::Dir->new( $path_to, @path );
    if ( -d $path ) {
        return $path;
    }
    else {
        return Path::Class::File->new( $path_to, @path );
    }
}

sub _load {
    my $self = shift;
    my $cfg = shift;

    my ($file, $hash) = %$cfg;

    $self->{_config} = Hash::Merge::Simple->merge($self->_config, $hash);
}

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

=head1 SEE ALSO

L<Catalyst::Plugin::ConfigLoader>, L<Config::Any>, L<Catalyst>

=head1 SOURCE

You can contribute or fork this project via GitHub:

L<http://github.com/robertkrimen/config-jfdi/tree/master>

    git clone git://github.com/robertkrimen/config-jfdi.git PACKAGE

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
