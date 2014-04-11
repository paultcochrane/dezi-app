package Dezi::Test::Searcher;
use Moose;
extends 'Dezi::Searcher';
use Carp;
use Data::Dump qw( dump );
use Scalar::Util qw( blessed );
use Dezi::Searcher::SearchOpts;
use Dezi::Test::Results;
use Dezi::Test::ResultsPayload;

# need this to build property_map
has 'swish3_config' =>
    ( is => 'rw', isa => 'SWISH::3::Config', required => 1 );

sub _cache_property_map {
    my $self = shift;
    my %prop_map;
    my $props = $self->swish3_config->get_properties;
    for my $name ( @{ $props->keys } ) {
        my $prop  = $props->get($name);
        my $alias = $prop->alias_for;
        if ($alias) {
            $prop_map{$name} = $alias;
        }
    }
    $self->{property_map} = \%prop_map;
}

sub invindex_class {'Dezi::Test::InvIndex'}

sub search {
    my $self = shift;
    my ( $query, $opts ) = @_;
    if ($opts) {
        $opts = $self->_coerce_search_opts($opts);
    }
    if ( !defined $query ) {
        confess "query required";
    }
    elsif ( !blessed($query) ) {
        $query = $self->qp->parse($query)
            or confess "Invalid query: " . $self->qp->error;
    }

    #dump $self->invindex;

    my $hits = $self->invindex->[0]->search($query);

    # sort by number of matches per doc
    my @urls;
    my %scores;
    for my $url ( sort { $hits->{$b} <=> $hits->{$a} } keys %$hits ) {
        push @urls, $url;
        $scores{$url} = $hits->{$url};
    }

    # look up the doc object for each hit
    my @docs;
    for my $url (@urls) {
        push @docs, $self->invindex->[0]->get_doc($url);
    }

    #dump $self->invindex->[0];
    my $results = Dezi::Test::Results->new(
        query   => $query,
        hits    => scalar(@urls),
        payload => Dezi::Test::ResultsPayload->new(
            docs   => \@docs,
            urls   => \@urls,
            scores => \%scores,
        ),
        property_map => $self->property_map,
    );

    #dump $results;
    return $results;
}

1;
