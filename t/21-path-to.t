use strict;
use warnings;

use Test::Most;
plan qw/no_plan/;

use Config::JFDI;
my $config;

$config = Config::JFDI->new(
    qw{ name path_to path t/assets },
);

is($config->get->{path_to}, 'a-galaxy-far-far-away/tatooine');

$config = Config::JFDI->new(
    qw{ name path_to path t/assets },
    path_to => 'a-long-time-ago',
);

is($config->get->{path_to}, 'a-long-time-ago/tatooine');
