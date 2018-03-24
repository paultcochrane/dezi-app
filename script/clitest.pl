#!/usr/bin/env perl

use strict;
use warnings;

{

    package MyCLI;
    use Moose;

    use Getopt::Long qw(:config no_ignore_case no_bundling );
    with 'MooseX::Getopt';

    #use Types::Standard qw(:all);
    use Data::Dump qw( dump );
    use Carp;

    #MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
    #    ArrayRef => '=s@',
    #    Bool     => '=i',
    #);

    our $VERSION = '0.001';

    has 'debug' => (
        is          => 'rw',
        isa         => 'Bool',
        traits      => ['Getopt'],
        #cmd_flag    => 'debug',
        cmd_aliases => [qw(debug d D)],
    );

    sub run {
        my $self = shift;
        dump $self;

    }

    sub new_with_go {
        my $self = shift->new();
        GetOptions( $self, 'debug!' ) or die "error!";
        return $self;
    }

}

#my $app = MyCLI->new_with_go();
my $app = MyCLI->new_with_options();
Data::Dump::dump($app);
$app->run();

