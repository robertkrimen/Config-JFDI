package t::Test;

use strict;
use warnings;

sub deprecation_flag {
    # Probably won't work on win32 :)
    return ! $ENV{TEST_NO_AUTHOR} && -e 'inc/.author' ? () : (quiet_deprecation => 1);
}

1;
