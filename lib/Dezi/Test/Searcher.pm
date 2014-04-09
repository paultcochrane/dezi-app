package Dezi::Test::Searcher;
use Moose;
extends 'Dezi::Searcher';

sub invindex_class { 'Dezi::Test::InvIndex' }

1;
