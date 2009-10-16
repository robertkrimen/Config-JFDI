use strict;
use warnings;

use Test::More;
plan qw/no_plan/;

use Config::JFDI::Source::Loader;

sub file_extension ($) { Config::JFDI::Source::Loader::file_extension shift }

is( file_extension 'test.conf', 'conf' );
is( file_extension '...', undef );
is( file_extension '../.', undef );
is( file_extension '.../.', undef );
is( file_extension 't/assets/order/..', undef );
is( file_extension 't/assets/dir.cnf', undef );

1;
