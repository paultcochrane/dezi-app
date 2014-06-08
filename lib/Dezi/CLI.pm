package Dezi::CLI;
use Moose;
with 'MooseX::Getopt';

use Types::Standard qw( Bool );
use Data::Dump qw( dump );
use Carp;

use Dezi::App;

our $VERSION = '0.001';
my $CLI_NAME = 'dezcli';

has 'debug'   => ( is => 'rw', isa => Bool, );

=head2 run

Main method. Calls commands passed via @ARGV.

=cut

sub _getopt_full_usage {
    my ( $self, $usage ) = @_;
    $usage->die( { post_text => $self->commands } );
}

sub _usage_format {
    return "usage: %c command %o";
}

sub run {
    my $self = shift;

    $self->debug and dump $self;

    my @cmds = @{ $self->extra_argv };

    if ( !@cmds or $self->help_flag ) {
        $self->usage->die( { post_text => $self->commands } );
    }

    for my $cmd (@cmds) {
        if ( !$self->can($cmd) ) {
            warn "No such command $cmd\n";
            $self->usage->die();
        }
        $self->$cmd();
    }

}

sub commands {
    my $self = shift;
    my $usage = <<EOF;
 synopsis:
    $CLI_NAME [-E N] [-i dir file ... ] [-S aggregator] [-c file] [-f invindex] [-l] [-v (num)] [-I name=val]
    $CLI_NAME -q 'word1 word2 ...' [-f file1 file2 ...] 
          [-s sortprop1 [asc|desc] ...] 
          [-H num]
          [-m num] 
          [-x output_format] 
          [-L prop low high]
    $CLI_NAME -N path/to/compare/file or date
    $CLI_NAME -V
    $CLI_NAME -h
    $CLI_NAME -D n

 options: defaults are in brackets
 # commented options are not yet supported

 indexing options:
    -A : name=value passed directly to Aggregator
    -c : configuration file
    -D : Debug mode
   --doc_filter : doc_filter
    -E : next param is total expected files (generates progress bar)
    -f : invindex dir to create or search from [dezi.index]
    -F : next param is invindex format (lucy, xapian, or dbi) [lucy]
    -h : print this usage statement
    -i : create an index from the specified files
        for "-S fs" - specify a list of files or directories
        for "-S spider" - specify a list of URLs
    -I : name=value passed directly to Indexer
    -l : follow symbolic links when indexing
    -N : index only files with a modification date newer than path or date
         if no argument, defaults to [indexdir/swish_last_start]
    -S : specify which aggregator to use.
        Valid options are:
         "fs" - local files in your File System
         "spider" - web site files using a web crawler
        The default value is: "fs"
    -v : indexing verbosity level (0 to 3) [-v 1]
    -W : next param is ParserWarnLevel [-W 2]

 search options:
    -b : begin results at this number
    -f : invindex dir to create or search from [dezi.index]
    -F : next param is invindex format (ks, lucy, xapian, native, or dbi) [native]
    -h : print this usage statement
    -H : "Result Header Output": verbosity (0 to 9)  [1].
    -L : Limit results to a range of property values
    -m : the maximum number of results to return [defaults to all results]
    -n : query parser special NULL term
    -R : next param is Rank Scheme number (0 to 1)  [0].
    -s : sort by these document properties in the output "prop1 prop2 ..."
    -V : prints the current version
    -v : indexing verbosity level (0 to 3) [-v 1]
    -w : search for words "word1 word2 ..."
    -x : "Extended Output Format": Specify the output format.

             version : $VERSION
  Dezi::App::VERSION : $Dezi::App::VERSION
                docs : http://dezi.org/

EOF
    return $usage;
}

1;
