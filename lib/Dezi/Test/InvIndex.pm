package Dezi::Test::InvIndex;
use Moose;
extends 'Dezi::InvIndex';
use Carp;
use Dezi::Cache;
use Data::Dump qw( dump );

# in memory invindex
has 'term_cache' =>
    ( is => 'rw', isa => 'Dezi::Cache', default => sub { Dezi::Cache->new } );
has 'doc_cache' =>
    ( is => 'rw', isa => 'Dezi::Cache', default => sub { Dezi::Cache->new } );

sub open {
    my $self = shift;

    # no-op
}

sub search {
    my $self = shift;
    my ( $query, $opts ) = @_;
    if ( !defined $query ) {
        confess "query required";
    }
    my %hits;
    my $term_cache = $self->term_cache;

    # walk the query, matching terms against our cache
    $query->walk(
        sub {
            my ( $clause, $dialect, $sub, $prefix ) = @_;

            #dump $clause;
            return if $clause->is_tree;    # skip parents
            return unless $term_cache->has( $clause->value );
            if ( $clause->op eq "" or $clause->op eq "+" ) {

                # include
                for my $uri ( keys %{ $term_cache->get( $clause->value ) } ) {
                    $hits{$uri}++;
                }
            }
            else {

                # exclude
                for my $uri ( keys %{ $term_cache->get( $clause->value ) } ) {
                    delete $hits{$uri};
                }
            }
        }
    );

    #dump \%hits;

    return \%hits;
}

sub put_doc {
    my $self = shift;
    my $doc = shift or confess "doc required";
    $self->doc_cache->add( $doc->uri => $doc );
    return $doc;
}

sub get_doc {
    my $self = shift;
    my $uri = shift or confess "uri required";
    return $self->doc_cache->get($uri);
}

1;
