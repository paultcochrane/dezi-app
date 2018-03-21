#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dump qw( dump );

package Foo;
sub new { my $cls = shift; bless {@_}, $cls; }
use overload (
    '%{}' => sub {
        my %hash;
        my $self = shift;
        tie %hash, ref $self, $self;
        return \%hash;
    },
    bool     => sub {1},
    fallback => 1,
);

sub TIEHASH { my $p = shift; bless \shift, $p }

sub FETCH {
    Data::Dump::dump \@_;
    my $self = shift;
    my $key  = shift;
    return $self->$key;
}

sub FIRSTKEY {}

sub bar { '456' }

package main;

my $foo = Foo->new( bar => 123 );
printf( "bar==%s\n", $foo->{bar} );

