use strict;
use warnings;

use Test::Most;
plan qw/no_plan/;

use Config::JFDI;

my $config = Config::JFDI->new(
    qw{ name substitute path t/assets },
    substitute => {
        literal => sub {
            return "Literally, $_[1]!";
        },
        two_plus_two => sub {
            return 2 + 2;
        },
    },
);

ok($config->get);

is($config->get->{default}, "a-galaxy-far-far-away/");
is($config->get->{default_override}, "Literally, this!");
is($config->get->{original}, 4);
is($config->get->{original_embed}, "2 + 2 = 4");

