#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;

plan qw/no_plan/;

use Config::JFDI;

my $config = Config::JFDI->new( name => '' );
warning_is { $config->_path_to } undef;
