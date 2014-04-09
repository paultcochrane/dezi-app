package Dezi::Searcher;
use Moose;
with 'Dezi::Role';
use Dezi::Types;
use Carp;
use Scalar::Util qw( blessed );
use Class::Load;
use Search::Query;
use Search::Query::Parser;
use namespace::sweep;

our $VERSION = '0.001';

has 'max_hits' => ( is => 'rw', isa => 'Int', default => 1000 );
has 'invindex' => (
    is       => 'rw',
    isa      => 'Dezi::Type::InvIndexArr',
    required => 1,
    coerce   => 1,
);
has 'qp_config' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'qp' => ( is => 'rw', isa => 'Search::Query::Parser' );

=head1 NAME

Dezi::Searcher - base searcher class

=head1 SYNOPSIS

 my $searcher = Dezi::Searcher->new(
                    invindex        => 'path/to/index',
                    max_hits        => 1000,
                );
                
 my $results = $searcher->search( 'foo bar' );
 while (my $result = $results->next) {
     printf("%4d %s\n", $result->score, $result->uri);
 }

=head1 DESCRIPTION

Dezi::Searcher is a base searcher class. It defines
the APIs that all Dezi storage backends adhere to in
returning results from a Dezi::InvIndex.

=head1 METHODS

=head2 BUILD

Build searcher object. Called internally by new().

=head2 invindex

A Dezi::InvIndex object or directory path. Required. Set in new().

May be a single value or an array ref of values (for searching multiple
indexes at once).

=head2 max_hits

The maximum number of hits to return. Optional. Default is 1000.

=head2 qp_config

Optional hashref passed to Search::Query::Parser->new().

=cut

sub BUILD {
    my $self = shift;

    for my $invindex ( @{ $self->{invindex} } ) {

        # make sure invindex is blessed into invindex_class
        # and re-bless if necessary
        if ( !$invindex->isa( $self->invindex_class ) ) {
            Class::Load::load_class( $self->invindex_class );
            $invindex = $self->invindex_class->new( path => "$invindex" );
        }

        $invindex->open_ro;
    }

    # init query parser
    $self->{qp} ||= Search::Query::Parser->new( %{ $self->qp_config } );
}

sub invindex_class {'Dezi::InvIndex'}

=head2 search( I<query>, I<opts> )

Returns a Dezi::Results object.

I<query> should be a L<Search::Query::Dialect> object or a string parse-able
by L<Search::Query::Parser>.

I<opts> should be a Dezi::SearchOpts object or a hashref.

=cut

sub search {
    my $self = shift;
    my ( $query, $opts ) = @_;

    confess "$self does not implement search() method";
}

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>perl@peknet.comE<gt>

=head1 BUGS

Please report any bugs or feature requests to C<bug-swish-prog at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dezi-App>.  
I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dezi::Searcher


You can also look for information at:

=over 4

=item * Mailing list

L<http://lists.swish-e.org/listinfo/users>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dezi-App>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dezi-App>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dezi-App>

=item * Search CPAN

L<http://search.cpan.org/dist/Dezi-App/>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 SEE ALSO

L<http://swish-e.org/>
