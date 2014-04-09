package Dezi::Test::InvIndex;
use Moose;
extends 'Dezi::InvIndex';
use Carp;
use Dezi::Cache;

# in memory invindex
has 'cache' =>
    ( is => 'rw', isa => 'Dezi::Cache', default => sub { Dezi::Cache->new } );

sub open {

    # currently no-op
}

1;
