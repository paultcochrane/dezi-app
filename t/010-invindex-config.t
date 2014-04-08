use strict;
use warnings;
use Test::More tests => 6;

use_ok('Dezi');
use_ok('Dezi::Indexer::Config');
use_ok('Dezi::Test::Indexer');

SKIP: {

    # is executable present?
    my $test = Dezi::Test::Indexer->new;
    if ( !$test->swish_check ) {
        skip "swish-e not installed", 3;
    }

    ok( my $config = Dezi::Indexer::Config->new('t/test.conf'),
        "config from t/test.conf" );

    $config->IndexFile("foo/bar");

    ok( my $prog = Dezi->new( config => $config, ),
        "new prog object" );

    is( $prog->indexer->invindex->path, "foo/bar",
        "ad hoc IndexFile config" );

}
