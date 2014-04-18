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
    via { _coerce_indexer_config($_) } =>
    from 'Str' => via { _coerce_indexer_config($_) };

# InvIndex
subtype 'Dezi::Type::InvIndex' => as class_type 'Dezi::InvIndex';
coerce 'Dezi::Type::InvIndex'  => from 'Path::Class::File' =>
    via { _coerce_invindex($_) } => from 'Str' =>
    via { _coerce_invindex($_) } => from 'Undef' =>
    via { Dezi::InvIndex->new() };
subtype 'Dezi::Type::InvIndexArr' => as 'ArrayRef[Dezi::Type::InvIndex]';
coerce 'Dezi::Type::InvIndexArr' => from 'ArrayRef' => via {
    [ map { _coerce_invindex($_) } @$_ ];
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

sub _coerce_indexer_config {
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

sub _coerce_invindex {
    my $inv = shift or confess "InvIndex required";

    require Dezi::InvIndex;

    if ( blessed($inv) and $inv->isa('Path::Class::Dir') ) {
        return Dezi::InvIndex->new("$inv");
    }
    return Dezi::InvIndex->new("$inv");
}

1;

__END__

=head1 NAME

Dezi::Types - Moose type constraints for Dezi::App components

=head1 SYNOPSIS

 package MySearchThing;
 use Moose;
 use Dezi::Types;

 has 'invindex' => (
    is       => 'rw',
    isa      => 'Dezi::Type::InvIndexArr',
    required => 1,
    coerce   => 1,
 );

=head1 TYPES

The following types are defined:

=over

=item

Dezi::Type::Indexer::Config

=item

Dezi::Type::InvIndex

=item

Dezi::Type::InvIndexArr

=item

Dezi::Type::FileOrCodeRef

=item

Dezi::Type::File::Rules

=item

Dezi::Type::Uri

=item

Dezi::Type::Epoch

=item

Dezi::Type::LogLevel

=back

=head1 AUTHOR

Peter Karman, E<lt>karpet@dezi.orgE<gt>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dezi-app at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dezi-App>.  
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dezi::Types

You can also look for information at:

=over 4

=item * Website

L<http://dezi.org/>

=item * IRC

#dezisearch at freenode

=item * Mailing list

L<https://groups.google.com/forum/#!forum/dezi-search>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dezi-App>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dezi-App>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dezi-App>

=item * Search CPAN

L<https://metacpan.org/dist/Dezi-App/>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2014 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the terms of the GPL v2 or later.

=head1 SEE ALSO

L<http://dezi.org/>, L<http://swish-e.org/>, L<http://lucy.apache.org/>

