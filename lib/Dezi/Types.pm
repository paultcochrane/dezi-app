package Dezi::Types;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class;
use Carp;
use File::Rules;
use HTTP::Date;

# Indexer::Config
subtype 'Dezi::Type::Indexer::Config' => as class_type
    'Dezi::Indexer::Config';
coerce 'Dezi::Type::Indexer::Config' => from 'Path::Class::File' =>
    via { coerce_indexer_config($_) } =>
    from 'Str' => via { coerce_indexer_config($_) };

# InvIndex
subtype 'Dezi::Type::InvIndex' => as class_type 'Dezi::InvIndex';
coerce 'Dezi::Type::InvIndex'  => from 'Path::Class::File' =>
    via { coerce_invindex($_) } => from 'Str' =>
    via { coerce_invindex($_) } => from 'Undef' =>
    via { Dezi::InvIndex->new() };
subtype 'Dezi::Type::InvIndexArr' => as 'ArrayRef[Dezi::Type::InvIndex]';
coerce 'Dezi::Type::InvIndexArr' => from 'ArrayRef' => via {
    [ map { coerce_invindex($_) } @$_ ];
} => from 'Dezi::Type::InvIndex' => via { [$_] };

# filter
subtype 'Dezi::Type::FileOrCodeRef' => as 'CodeRef';
coerce 'Dezi::Type::FileOrCodeRef' => from 'Str' => via {
    if ( -s $_ and -r $_ ) { return do $_ }
};

# File::Rules
subtype 'Dezi::Type::File::Rules' => as class_type 'File::Rules';
coerce 'Dezi::Type::File::Rules'  => from 'ArrayRef' =>
    via { File::Rules->new($_) };

# URI (coerce to Str)
subtype 'Dezi::Type::Uri' => as 'Str';
coerce 'Dezi::Type::Uri' => from 'Object' => via {"$_"};

# Epoch
subtype 'Dezi::Type::Epoch' => as 'Maybe[Int]';
coerce 'Dezi::Type::Epoch' => from 'Defined' => via {
    m/\D/ ? str2time($_) : $_;
};

# LogLevel
subtype 'Dezi::Type::LogLevel' => as 'Int';
coerce 'Dezi::Type::LogLevel' => from 'Undef' => via {0};

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
        $config2_object = Dezi::Indexer::Config->new( file => $config2 );
    }
    elsif ( !blessed($config2) && ref $config2 eq 'HASH' ) {
        $config2_object = Dezi::Indexer::Config->new($config2);
    }
    elsif ( blessed($config2) ) {
        if ( $config2->isa('Path::Class::File') ) {
            $config2_object = Dezi::Indexer::Config->new( file => $config2 );
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
