package Dezi::App;
use Moose;
with 'Dezi::Role';
use Carp;
use Data::Dump qw( dump );
use Scalar::Util qw( blessed );
use Class::Load ();
use Dezi::Types;
use Dezi::ReplaceRules;
use namespace::sweep;

our $VERSION = '0.001';

has 'aggregator' => ( is => 'rw', );    # we do our own isa check
has 'aggregator_opts' => ( is => 'rw', isa => 'HashRef' );
has 'config' =>
    ( is => 'rw', isa => 'Dezi::Type::Indexer::Config', coerce => 1, );
has 'indexer' => ( is => 'rw', );       # we do our own isa check
has 'indexer_opts' => ( is => 'rw', isa => 'HashRef' );
has 'invindex' => (
    is       => 'rw',
    isa      => 'Dezi::Type::InvIndex',
    required => 1,
    coerce   => 1,
);
has 'filter' => ( is => 'rw', isa => 'Dezi::Type::FileOrCodeRef' );
has 'test_mode' => ( is => 'rw', isa => 'Bool', default => 0 );

# allow for short names. we map to class->new
my %ashort = (
    fs     => 'Dezi::Aggregator::FS',
    mail   => 'Dezi::Aggregator::Mail',
    mailfs => 'Dezi::Aggregator::MailFS',
    dbi    => 'Dezi::Aggregator::DBI',
    spider => 'Dezi::Aggregator::Spider',
    object => 'Dezi::Aggregator::Object',
);
my %ishort = (
    xapian => 'Dezi::Xapian::Indexer',
    lucy   => 'Dezi::Lucy::Indexer',
    dbi    => 'Dezi::DBI::Indexer',
    test   => 'Dezi::Test::Indexer',
);

sub BUILD {
    my $self = shift;

    # need to make sure we have an aggregator.
    # indexer and/or config might already be set in aggregator
    # but if set here, we override.

    my ( $aggregator, $indexer );

    # ok if undef
    my $config = $self->{config};

    # get indexer
    $indexer = $self->{indexer} || 'lucy';
    if ( $self->{aggregator} and blessed( $self->{aggregator} ) ) {
        $indexer = $self->{aggregator}->indexer;
        $config  = $self->{aggregator}->config;
    }
    if ( !blessed($indexer) ) {

        if ( exists $ishort{$indexer} ) {
            $indexer = $ishort{$indexer};
        }

        $self->debug and warn "creating indexer: $indexer";
        Class::Load::load_class($indexer);

        my %indexer_opts = (
            debug     => $self->debug,
            invindex  => $self->{invindex},    # may be undef
            verbose   => $self->verbose,
            config    => $config,              # may be undef
            test_mode => $self->test_mode,
            %{ $self->indexer_opts || {} },
        );

        $self->debug and warn "indexer opts: " . dump( \%indexer_opts );

        $indexer = $indexer->new(%indexer_opts);
    }
    elsif ( !$indexer->isa('Dezi::Indexer') ) {
        confess "$indexer is not a Dezi::Indexer-derived object";
    }

    $aggregator = $self->{aggregator} || 'fs';
    my $aggregator_opts = $self->aggregator_opts || {};

    if ( !blessed($aggregator) ) {

        if ( exists $ashort{$aggregator} ) {
            $aggregator = $ashort{$aggregator};
        }

        $self->debug and warn "creating aggregator: $aggregator";
        Class::Load::load_class($aggregator);

        my %aggr_opts = (
            indexer   => $indexer,
            debug     => $self->debug,
            verbose   => $self->verbose,
            test_mode => $self->test_mode,
            %$aggregator_opts,
        );

        $self->debug and warn "aggregator opts: " . dump( \%aggr_opts );

        $aggregator = $aggregator->new(%aggr_opts);
    }
    elsif ( !$aggregator->isa('Dezi::Aggregator') ) {
        confess "$aggregator is not a Dezi::Aggregator-derived object";
    }

    # set these now so we can call $self->config
    $self->{aggregator} = $aggregator;
    $self->{indexer}    = $indexer;

    if ( $indexer and $indexer->config and $indexer->config->ReplaceRules ) {

        # create a CODE ref that uses the ReplaceRules
        my $rr    = $indexer->config->ReplaceRules;
        my $rules = Dezi::ReplaceRules->new(@$rr);
        if ( $self->filter ) {
            my $filter_copy = $self->filter;
            $self->filter(
                sub {
                    $_[0]->url( $rules->apply( $_[0]->url ) );
                    $filter_copy->( $_[0] );
                }
            );
        }
        else {
            $self->filter(
                sub {
                    $_[0]->url( $rules->apply( $_[0]->url ) );
                }
            );
        }
    }

    if ( $self->filter ) {
        $aggregator->set_filter( $self->filter );
    }

    $indexer->{test_mode} = $self->{test_mode}
        unless exists $indexer->{test_mode};
    $aggregator->{test_mode} = $self->{test_mode}
        unless exists $aggregator->{test_mode};

    $self->debug and carp dump $self;

    return $self;
}

sub run {
    my $self = shift;
    my $aggregator = $self->aggregator or confess 'aggregator required';
    unless ( $aggregator->isa('Dezi::Aggregator') ) {
        croak "aggregator is not a Dezi::Aggregator";
    }

    $aggregator->indexer->start;
    $aggregator->crawl(@_);
    $aggregator->indexer->finish;
    return $aggregator->indexer->count;
}

=head2 count

Returns the indexer's count. B<NOTE> This is the number of documents
actually indexed, not counting the number of documents considered and
discarded by the aggregator. If you want the number of documents
the aggregator looked at, regardless of whether they were indexed,
use the aggregator's count() method.

=cut

sub count {
    shift->indexer->count;
}

1;

__END__

=head1 AUTHOR

Peter Karman, E<lt>karpet@dezi.orgE<gt>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dezi-app at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dezi-App>.  
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dezi::App

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
