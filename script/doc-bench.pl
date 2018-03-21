#!/usr/bin/env perl
use strict;
use warnings;

use SWISH::Prog::Doc;
use Dezi::Indexer::Doc;

use Benchmark qw(:all);

cmpthese(
    100_000,
    {   'SWISH::Prog::Doc->new' => sub {
            SWISH::Prog::Doc->new(

            );
        },
        'Dezi::Indexer::Doc->new' => sub {
            Dezi::Indexer::Doc->new();
        },
    }
);
