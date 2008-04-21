#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Config::JFDI' );
}

diag( "Testing Config::JFDI $Config::JFDI::VERSION, Perl $], $^X" );
