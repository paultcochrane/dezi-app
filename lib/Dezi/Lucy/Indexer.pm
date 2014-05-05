package Dezi::Lucy::Indexer;
use Moose;
extends 'Dezi::Indexer';

use Dezi::Lucy::InvIndex;

use Lucy::Index::Indexer;
use Lucy::Plan::Schema;
use Lucy::Plan::FullTextType;
use Lucy::Plan::StringType;
use Lucy::Analysis::PolyAnalyzer;

use Carp;
use SWISH::3 qw( :constants );
use Scalar::Util qw( blessed );
use Data::Dump qw( dump );
use Search::Tools::UTF8;
use Path::Class::File::Lockable;
use Sys::Hostname qw( hostname );

our $VERSION = '0.001';

has 'highlightable_fields' =>
    ( is => 'rw', isa => 'Bool', default => sub {0} );

=head1 NAME

Dezi::Lucy::Indexer - Dezi::App Apache Lucy indexer

=head1 SYNOPSIS

 use Dezi::Lucy::Indexer;
 my $indexer = Dezi::Lucy::Indexer->new(
    config               => Dezi::Indexer::Config->new(),
    invindex             => Dezi::Lucy::InvIndex->new(),
    highlightable_fields => 0,
 );

=head1 DESCRIPTION

Dezi::Lucy::Indexer is an Apache Lucy based indexer
class based on L<SWISH::3>.

=head1 CONSTANTS

All the L<SWISH::3> constants are imported into this namespace,
including:

=head2 SWISH_DOC_PROP_MAP

=head1 METHODS

Only new and overridden methods are documented here. See
the L<Dezi::Indexer> documentation.

=head2 BUILD

Implements basic object set up. Called internally by new().

In addition to the attributes documented in Dezi::Indexer,
this class implements the following attributes:

=over

=item highlightable_fields

Value should be 0 or 1. Default is 0. Passed directly to the
constructor for Lucy::Plan::FullTextField objects as the value
for the C<highlightable> option.

=back

=cut

sub BUILD {
    my $self = shift;

    unless ( $self->invindex->isa('Dezi::Lucy::InvIndex') ) {
        confess ref($self) . " requires Dezi::Lucy::InvIndex-derived object";
    }

    $self->_build_lucy_delegates();
}

sub _build_lucy_delegates {
    my $self     = shift;
    my $s3config = $self->swish3->config;
    my $lang     = $s3config->get_index->get( SWISH_INDEX_STEMMER_LANG() )
        || 'none';
    $self->{_lang} = $lang;    # cache for finish()
    my $schema = Lucy::Plan::Schema->new();
    my $analyzer;
    if ( $lang and $lang =~ m/^\w\w$/ ) {
        $analyzer = Lucy::Analysis::PolyAnalyzer->new( language => $lang, );
    }
    else {
        my $case_folder = Lucy::Analysis::CaseFolder->new;
        my $tokenizer   = Lucy::Analysis::RegexTokenizer->new;
        $analyzer = Lucy::Analysis::PolyAnalyzer->new(
            analyzers => [ $case_folder, $tokenizer, ], );
    }

    # build the Lucy fields, which are a merger of MetaNames+PropertyNames
    my %fields;

    my $built_in_props = SWISH_DOC_PROP_MAP();

    my $metanames = $s3config->get_metanames;
    my $meta_keys = $metanames->keys;
    for my $name (@$meta_keys) {
        my $mn    = $metanames->get($name);
        my $alias = $mn->alias_for;
        $fields{$name}->{is_meta}       = 1;
        $fields{$name}->{is_meta_alias} = $alias;
        $fields{$name}->{bias}          = $mn->bias;
        if ( exists $built_in_props->{$name} ) {
            $fields{$name}->{is_prop}  = 1;
            $fields{$name}->{sortable} = 1;
        }
    }

    my $properties    = $s3config->get_properties;
    my $property_keys = $properties->keys;
    for my $name (@$property_keys) {
        if ( exists $built_in_props->{$name} ) {
            croak
                "$name is a built-in PropertyName and should not be defined in config";
        }
        my $property = $properties->get($name);
        my $alias    = $property->alias_for;
        $fields{$name}->{is_prop}       = 1;
        $fields{$name}->{is_prop_alias} = $alias;
        if ( $property->sort ) {
            $fields{$name}->{sortable} = 1;
        }
    }

    $self->{_fields} = \%fields;

    my $property_only = Lucy::Plan::StringType->new( sortable => 1, );
    my $store_no_sort = Lucy::Plan::StringType->new(
        sortable => 0,
        stored   => 1,
    );

    for my $name ( keys %fields ) {
        my $field = $fields{$name};
        my $key   = $name;

        # if a field is purely an alias, skip it.
        if (    defined $field->{is_meta_alias}
            and defined $field->{is_prop_alias} )
        {
            $field->{store_as}->{ $field->{is_meta_alias} } = 1;
            $field->{store_as}->{ $field->{is_prop_alias} } = 1;
            next;
        }

        if ( $field->{is_meta} and !$field->{is_prop} ) {
            if ( defined $field->{is_meta_alias} ) {
                $key = $field->{is_meta_alias};
                $field->{store_as}->{$key} = 1;
                next;
            }

            #warn "spec meta $name";
            $schema->spec_field(
                name => $name,
                type => Lucy::Plan::FullTextType->new(
                    analyzer      => $analyzer,
                    stored        => 0,
                    boost         => $field->{bias} || 1.0,
                    highlightable => $self->highlightable_fields,
                ),
            );
        }

        # this is the trickiest case, because the field
        # is both prop+meta and could be an alias for one
        # and a real for the other.
        # NOTE we have already eliminated (above) the case where
        # the field is an alias for both.
        elsif ( $field->{is_meta} and $field->{is_prop} ) {
            if ( defined $field->{is_meta_alias} ) {
                $key = $field->{is_meta_alias};
                $field->{store_as}->{$key} = 1;
            }
            elsif ( defined $field->{is_prop_alias} ) {
                $key = $field->{is_prop_alias};
                $field->{store_as}->{$key} = 1;
            }

            #warn "spec meta+prop $name";
            $schema->spec_field(
                name => $name,
                type => Lucy::Plan::FullTextType->new(
                    analyzer      => $analyzer,
                    highlightable => $self->highlightable_fields,
                    sortable      => $field->{sortable},
                    boost         => $field->{bias} || 1.0,
                ),
            );
        }
        elsif (!$field->{is_meta}
            and $field->{is_prop}
            and !$field->{sortable} )
        {
            if ( defined $field->{is_prop_alias} ) {
                $key = $field->{is_prop_alias};
                $field->{store_as}->{$key} = 1;
                next;
            }

            #warn "spec prop !sort $name";
            $schema->spec_field(
                name => $name,
                type => $store_no_sort
            );
        }
        elsif (!$field->{is_meta}
            and $field->{is_prop}
            and $field->{sortable} )
        {
            if ( defined $field->{is_prop_alias} ) {
                $key = $field->{is_prop_alias};
                $field->{store_as}->{$key} = 1;
                next;
            }

            #warn "spec prop sort $name";
            $schema->spec_field(
                name => $name,
                type => $property_only
            );
        }
        $field->{store_as}->{$name} = 1;
    }

    for my $name ( keys %$built_in_props ) {
        if ( exists $fields{$name} ) {
            my $field = $fields{$name};

            #carp "found $name in built-in props: " . dump($field);

            # in theory this should never happen.
            if ( !$field->{is_prop} ) {
                croak
                    "$name is a built-in PropertyName but not defined as a PropertyName in config";
            }
        }

        # default property
        else {
            $schema->spec_field( name => $name, type => $property_only );
        }
    }

    #dump( \%fields );

    # TODO can pass lucy in? make 'lucy' attribute public?
    my $hostname = hostname() or confess "Can't get unique hostname";
    my $manager = Lucy::Index::IndexManager->new( host => $hostname );
    $self->{lucy} ||= Lucy::Index::Indexer->new(
        schema  => $schema,
        index   => $self->invindex->path,
        create  => 1,
        manager => $manager,
    );

    # cache our objects in case we later
    # need to create any fields on-the-fly
    $self->{__lucy}->{analyzer} = $analyzer;
    $self->{__lucy}->{schema}   = $schema;

}

sub _add_new_field {
    my ( $self, $metaname, $propname ) = @_;
    my $fields = $self->{_fields};
    my $alias  = $metaname->alias_for;
    my $name   = $metaname->name;
    if ( !exists $fields->{$name} ) {
        $fields->{$name} = {};
    }
    my $field = $fields->{$name};
    $field->{is_meta}           = 1;
    $field->{is_meta_alias}     = $alias;
    $field->{bias}              = $metaname->bias;
    $field->{store_as}->{$name} = 1;

    if ($propname) {
        my $prop_alias = $propname->alias_for;
        $field->{is_prop}       = 1;
        $field->{is_prop_alias} = $prop_alias;
        if ( $propname->sort ) {
            $field->{sortable} = 1;
        }
    }

    # a newly defined MetaName matching an already-defined PropertyName
    # or a new MetaName+PropertyName
    if ( $field->{is_prop} ) {
        $self->{__lucy}->{schema}->spec_field(
            name => $name,
            type => Lucy::Plan::FullTextType->new(
                analyzer      => $self->{__lucy}->{analyzer},
                highlightable => $self->highlightable_fields,
                sortable      => $field->{sortable},
                boost         => $field->{bias} || 1.0,
            ),
        );
    }

    # just a new MetaName
    else {

        $self->{__lucy}->{schema}->spec_field(
            name => $name,
            type => Lucy::Plan::FullTextType->new(
                analyzer      => $self->{__lucy}->{analyzer},
                stored        => 0,
                boost         => $field->{bias} || 1.0,
                highlightable => $self->highlightable_fields,
            ),
        );

    }

    #warn "Added new field $name: " . dump( $field );

    return $field;
}

my $doc_prop_map = SWISH_DOC_PROP_MAP();

=head2 swish3_handler( I<swish3_data> )

Called by the SWISH::3::handler() function for every document being
indexed.

=cut

sub swish3_handler {
    my ( $self, $data ) = @_;
    my $config     = $data->config;
    my $conf_props = $config->get_properties;
    my $conf_metas = $config->get_metanames;

    # will hold all the parsed text, keyed by field name
    my %doc;

    # Swish built-in fields first
    for my $propname ( keys %$doc_prop_map ) {
        my $attr = $doc_prop_map->{$propname};
        $doc{$propname} = [ $data->doc->$attr ];
    }

    # fields parsed from document
    my $props = $data->properties;
    my $metas = $data->metanames;

    # field def cache
    my $fields = $self->{_fields};

    # may need to add newly-discovered fields from $metas
    # that were added via UndefinedMetaTags e.g.
    for my $mname ( keys %$metas ) {
        if ( !exists $fields->{$mname} ) {

            #warn "New field: $mname\n";
            my $prop;
            if ( exists $props->{$mname} ) {
                $prop = $conf_props->get($mname);
            }
            $self->_add_new_field( $conf_metas->get($mname), $prop );
        }
    }

    #dump $fields;
    #dump $props;
    #dump $metas;
    for my $fname ( sort keys %$fields ) {
        my $field = $self->{_fields}->{$fname};
        next if $field->{is_prop_alias};
        next if $field->{is_meta_alias};

        my @keys = keys %{ $field->{store_as} };

        for my $key (@keys) {

            # prefer properties over metanames because
            # properties have verbatim flag, which affects
            # the stored whitespace.

            if ( $field->{is_prop} and !exists $doc_prop_map->{$fname} ) {
                push( @{ $doc{$key} }, @{ $props->{$fname} } );
            }
            elsif ( $field->{is_meta} ) {
                push( @{ $doc{$key} }, @{ $metas->{$fname} } );
            }
            else {
                croak "field '$fname' is neither a PropertyName nor MetaName";
            }
        }
    }

    # serialize the doc with our tokenpos_bump char
    for my $k ( keys %doc ) {
        $doc{$k} = to_utf8( join( "\003", @{ $doc{$k} } ) );
    }

    $self->debug and carp dump \%doc;

    # make sure we delete any existing doc with same URI
    $self->{lucy}->delete_by_term(
        field => 'swishdocpath',
        term  => $doc{swishdocpath}
    );

    $self->{lucy}->add_doc( \%doc );
}

=head2 finish

Calls commit() on the internal Lucy::Indexer object,
writes the C<swish.xml> header file and calls the superclass finish()
method.

=cut

my @chars = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );

around finish => sub {
    my $super_method = shift;
    my $self         = shift;

    return 0 if $self->{_is_finished};

    my $doc_count = $self->_finish_lucy();
    $super_method->( $self, @_ );
    $self->{_is_finished} = 1;

    return $doc_count;
};

sub _finish_lucy {
    my $self = shift;

    # get a lock on our header file till
    # this entire transaction is complete.
    # Note that we trust the Lucy locking feature
    # to have prevented any other process
    # from getting a lock on the invindex itself,
    # but we want to make sure nothing interrupts
    # us from writing our own header after calling ->commit().
    my $invindex  = $self->invindex;
    my $header    = $invindex->header_file->stringify;
    my $lock_file = Path::Class::File::Lockable->new($header);
    if ( $lock_file->locked ) {
        croak "Lock file found on $header -- cannot commit indexing changes";
    }
    $lock_file->lock;

    # commit our changes
    $self->{lucy}->commit();

    # get total doc count
    my $polyreader = Lucy::Index::PolyReader->open( index => "$invindex", );
    my $doc_count = $polyreader->doc_count();

    # write header
    # the current config should contain any existing header + runtime config
    my $idx_cfg = $self->swish3->config->get_index;

    # poor man's uuid
    my $uuid = join( "", @chars[ map { rand @chars } ( 1 .. 24 ) ] );

    $idx_cfg->set( SWISH_INDEX_NAME(),         "$invindex" );
    $idx_cfg->set( SWISH_INDEX_FORMAT(),       'Lucy' );
    $idx_cfg->set( SWISH_INDEX_STEMMER_LANG(), $self->{_lang} );
    $idx_cfg->set( "DocCount",                 $doc_count );
    $idx_cfg->set( "UUID",                     $uuid );

    $self->swish3->config->write($header);

    # transaction complete
    $lock_file->unlock;

    $self->debug and carp "wrote $header with uuid $uuid";
    $self->debug and carp "$doc_count docs indexed";
    $self->swish3(undef);    # invalidate this indexer

    return $doc_count;
}

=head2 get_lucy

Returns the internal Lucy::Index::Indexer object.

=cut

sub get_lucy {
    return shift->{lucy};
}

=head2 abort

Sets the internal Lucy::Index::Indexer to undef,
which should release any locks on the index.
Also flags the Dezi::Lucy::Indexer object
as stale.

=cut

sub abort {
    my $self = shift;
    $self->{lucy}         = undef;
    $self->{_is_finished} = 1;
    $self->swish3(undef);
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

