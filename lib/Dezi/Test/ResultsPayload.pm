package Dezi::Test::ResultsPayload;
use Moose;
with 'Dezi::Role';
use Carp;
use namespace::sweep;

has 'docs'   => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'urls'   => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'scores' => ( is => 'ro', isa => 'HashRef',  required => 1 );

1;
