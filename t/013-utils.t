#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 5;

use_ok('Dezi::Utils');

my $utils = 'Dezi::Utils';    # static methods only

is( $utils->mime_type('foo.json'), "application/json", "got json mime type" );
is( $utils->mime_type('foo.yml'), "application/x-yaml",
    "got yaml mime type" );
is( $utils->parser_for('foo.json'), "HTML*", "json -> HTML* parser" );

# override default
{
    no warnings;
    $Dezi::Utils::ParserTypes{'application/json'} = 'XML*';
}
is( $utils->parser_for('foo.json'),
    "XML*", "json -> XML* parser, overriden via package hash" );
