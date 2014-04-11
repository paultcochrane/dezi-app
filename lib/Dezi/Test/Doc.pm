package Dezi::Test::Doc;
use Moose;
with 'Dezi::Role';
use SWISH::3 qw( :constants );

# make accessor all built-ins
for my $attr ( keys %{ SWISH_DOC_PROP_MAP() } ) {
    has $attr => ( is => 'ro', isa => 'Str' );
}

# and any we use in our tests
my @attrs = qw( swishdefault swishtitle swishdescription );
for my $attr (@attrs) {
    has $attr => ( is => 'ro', isa => 'Str' );
}

sub uri { shift->swishdocpath }

sub property {
    my $self = shift;
    my $prop = shift or confess "property required";
    return $self->$prop;
}

1;
