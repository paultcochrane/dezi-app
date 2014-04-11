package Dezi::Test::Results;
use Moose;
extends 'Dezi::Results';
use Dezi::Test::Result;
use namespace::sweep;

sub next {
    my $self    = shift;
    my $idx_doc = shift @{ $self->payload->docs } or return;
    my $res     = Dezi::Test::Result->new(
        doc          => $idx_doc,
        score        => $self->payload->scores->{ $idx_doc->uri },
        property_map => $self->property_map,
    );
    return $res;
}

1;
