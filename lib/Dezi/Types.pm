package Dezi::Types;
use Moose;
use Moose::Util::TypeConstraints;

subtype 'Dezi::Type::Indexer::Config' => as class_type
    'Dezi::Indexer::Config';
coerce 'Dezi::Type::Indexer::Config' => from 'Path::Class::File' =>
    via { coerce_indexer_config($_) } =>
    from 'Str' => via { coerce_indexer_config($_) };

subtype 'Dezi::Type::InvIndex' => as class_type 'Dezi::InvIndex';
coerce 'Dezi::Type::InvIndex'  => from 'Path::Class::File' =>
    via { coerce_invindex($_) } => from 'Str' => via { coerce_invindex($_) };

use namespace::sweep;

sub coerce_indexer_config {
    my $config2 = shift;

    require Dezi::Indexer::Config;

    #carp "verify_isa_config: $config2";

    my $config2_object;
    if ( !$config2 ) {
        $config2_object = Dezi::Indexer::Config->new();
    }
    elsif ( !blessed($config2) && -r $config2 ) {
        $config2_object = Dezi::Indexer::Config->new($config2);
    }
    elsif ( !blessed($config2) && ref $config2 eq 'HASH' ) {
        $config2_object = Dezi::Indexer::Config->new($config2);
    }
    elsif ( blessed($config2) ) {
        if ( $config2->isa('Path::Class::File') ) {
            $config2_object = Dezi::Indexer::Config->new("$config2");
        }
        elsif ( $config2->isa('Dezi::Indexer::Config') ) {
            $config2_object = $config2;
        }
        else {
            confess
                "config object does not inherit from Dezi::Indexer::Config: $config2";
        }
    }
    else {
        confess "$config2 is neither an object nor a readable file";
    }

    return $config2_object;
}

sub coerce_invindex {
    my $inv = shift or confess "InvIndex required";

    require Dezi::InvIndex;

    if ( blessed($inv) and $inv->isa('Path::Class::Dir') ) {
        return Dezi::InvIndex->new("$inv");
    }
    return Dezi::InvIndex->new("$inv");
}

1;
