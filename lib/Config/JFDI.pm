package Config::JFDI;

use warnings;
use strict;

=head1 NAME

Config::JFDI - 

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use Moose;
use Path::Class;
use Config::Any;
use List::MoreUtils qw/any/;
use Carp::Clan;
use Clone qw//;

has name => qw/is ro isa Str/; # Actually, required unless ->file is given
has path => qw/is ro isa Str/, default => "./"; # Can actually be a path (./my/, ./my) OR a bonafide file (i.e./my.yaml)
has driver => qw/is ro required 1 lazy 1/, default => sub { {} };
has local_suffix => qw/is ro required 1 lazy 1/, default => "local";

has loaded => qw/is ro required 1/, default => 0;
has load_once => qw/is ro required 1/, default => 1;

has _config => qw/is ro required 1 lazy 1/, default => sub { {} };

# TODO Maybe in the... future-ure-ure-ure...
#has driver_name => qw/is ro isa Str/;
#has driver_class => qw/is ro isa Str/;

# TODO Put into Hash::Merge::Simple
# Merge with right-most precedence
sub _merge (@);
sub _merge (@) {
    my ($left, @right) = @_;

    return $left unless @right;

    return _merge($left, _merge(@right)) if @right > 1;

    my ($right) = @right;

    my %merge = %$left;

    for my $key (keys %$right) {
        my $hr = (ref $right->{$key} || '') eq 'HASH';
        my $hl  = ((exists $left->{$key} && ref $left->{$key}) || '') eq 'HASH';

        if ($hr and $hl){
            $merge{$key} = _merge($left->{$key}, $right->{$key});
        }
        else {
            $merge{$key} = $right->{$key};
        }
    }
    
    return \%merge;
}

sub _env(@) {
    my $name = uc join "_", @_;
    $name =~ s/\W/_/g;
    return $ENV{$name};
}

sub BUILD {
    my $self = shift;
    my $given = shift;

    if ($given->{file}) {
        $self->{path} = $given->{file};
    }
    elsif ($given->{name}) {
    }
    else {
        croak "At minimum, either a name or a file is required";
    }
}

sub clone {
    my $self = shift;
    return Clone::clone($self->config);
}

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

sub reload {
    my $self = shift;
    $self->{loaded} = 0;
    return $self->load;
}

sub _load {
    my $self = shift;
    my $cfg = shift;

    my ($file, $hash) = %$cfg;

    $self->{_config} = _merge($self->_config, $hash);
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
        # TODO C::P::ConfigLoader does a next here!
        # TODO Make sure DBIC can handle ->create({}) case ("INSERT INTO xyzzy () VALUES ()")
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
    $path = _env($name, 'CONFIG') if $name;
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
    $suffix = _env($self->name, 'CONFIG_LOCAL_SUFFIX') if $name;
    $suffix ||= $self->local_suffix;

    return $suffix;
}

sub _get_extensions {
    return @{ Config::Any->extensions }
}

=head1 SYNOPSIS

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

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

