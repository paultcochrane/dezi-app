#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 38;

use_ok('Dezi');
use_ok('Dezi::Test::Indexer');
use_ok('Dezi::Aggregator::FS');
use_ok('Dezi::Indexer::Config');

SKIP: {

    # is executable present?
    my $test = Dezi::Test::Indexer->new;
    if ( !$test->swish_check ) {
        skip "swish-e not installed", 34;
    }

    ok( my $invindex
            = Dezi::Test::InvIndex->new( path => 't/testindex', ),
        "new invindex"
    );

    ok( my $config = Dezi::Indexer::Config->new('t/test.conf'),
        "config from t/test.conf" );

    # skip our local config test files
    $config->FileRules( 'dirname contains config',              1 );
    $config->FileRules( 'filename is swish.xml',                1 );
    $config->FileRules( 'filename contains \.t',                1 );
    $config->FileRules( 'dirname contains (testindex|\.index)', 1 );
    $config->FileRules( 'filename contains \.conf',             1 );
    $config->FileRules( 'dirname contains mailfs',              1 );

    ok( my $indexer = Dezi::Test::Indexer->new(
            invindex => $invindex,
            config   => $config
        ),
        "new indexer"
    );

    ok( my $aggregator = Dezi::Aggregator::FS->new(
            indexer => $indexer,

            #verbose => 1,
            #debug   => 1,
        ),
        "new filesystem aggregator"
    );

    ok( my $prog = Dezi->new(
            aggregator => $aggregator,

            #filter => sub { diag( "doc filter on " . $_[0]->url ) },

            #verbose    => 1,
        ),
        "new program"
    );

    ok( $prog->run('t/'), "run program" );

    is( $prog->count, 7, "indexed test docs" );

    # test with a search
SKIP: {

        eval { require Dezi::Test::Searcher; };
        if ($@) {
            skip "Cannot test Searcher without SWISH::API", 27;
        }
        ok( my $searcher
                = Dezi::Test::Searcher->new( invindex => $invindex,
                ),
            "new searcher"
        );

        my $query = 'foo or words';
        ok( my $results
                = $searcher->search( $query,
                { order => 'swishdocpath ASC' } ),
            "do search"
        );
        is( $results->hits, 5, "5 hits" );
        ok( my $result = $results->next, "results->next" );
        diag( $result->swishdocpath );
        is( $result->swishtitle, 'test gzip html doc', "get swishtitle" );
        is( $result->get_property('swishtitle'),
            $result->swishtitle, "get_property(swishtitle)" );

        # test all the built-in properties and their method shortcuts
        my @methods = qw(
            swishdocpath
            uri
            swishlastmodified
            mtime
            swishtitle
            title
            swishdescription
            summary
            swishrank
            score
        );

        for my $m (@methods) {
            ok( defined $result->$m,               "get $m" );
            ok( defined $result->get_property($m), "get_property($m)" );
        }

        # test an aliased property
        is( $result->get_property('lastmod'),
            $result->swishlastmodified, "aliased PropertyName fetched" );
    }

    # clean up index
    $invindex->path->rmtree;

}
