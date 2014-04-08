#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Dezi::Indexer' );
}

diag( "Testing Dezi::Indexer $Dezi::Indexer::VERSION, Perl $], $^X" );
