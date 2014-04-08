package Dezi::Results;
use strict;
use warnings;
use base qw( Dezi::Class );
use Carp;

our $VERSION = '0.001';

__PACKAGE__->mk_accessors(
    qw(
        hits
        query
        ),
);

=head1 NAME

Dezi::Results - base results class

=head1 SYNOPSIS

 my $searcher = Dezi::Searcher->new(
                    invindex        => 'path/to/index',
                    query_class     => 'Dezi::Query',
                    query_parser    => $swish_prog_queryparser,
                );
                
 my $results = $searcher->search( 'foo bar' );
 while (my $result = $results->next) {
     printf("%4d %s\n", $result->score, $result->uri);
 }

=head1 DESCRIPTION

Dezi::Results is a base results class. It defines
the APIs that all Dezi storage backends adhere to in
returning results from a Dezi::InvIndex.

=head1 METHODS

=head2 query

Should return the search query as it was evaluated by the Searcher.

=head2 hits

Returns the number of matching documents for the query.

=head2 next

Return the next Result.

=cut

sub next {
    croak "must override next() in your subclass";
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

    perldoc Dezi


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
