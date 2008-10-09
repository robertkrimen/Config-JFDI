use strict;
use warnings;

use Test::More;
plan qw/no_plan/;

use Config::JFDI;

my $config = Config::JFDI->new(file => "t/assets/some_random_file.pl");

ok($config->get);
is($config->get->{'Controller::Foo'}->{foo},       'bar');
is($config->get->{'Model::Baz'}->{qux},            'xyzzy');
is($config->get->{'view'},                         'View::TT');
is($config->get->{'random'},                        1);
#is($config->get->{'foo_sub'},                      '__foo(x,y)__' );
#is($config->get->{'literal_macro'},                '__literal(__DATA__)__');
