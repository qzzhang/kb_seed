use strict;
use Data::Dumper;
use Bio::KBase::Utilities::ScriptThing;
use Carp;

#
# This is a SAS Component
#

=head1 NAME

get_entity_AlignmentRow

=head1 SYNOPSIS

get_entity_AlignmentRow [-c N] [-a] [--fields field-list] < ids > table.with.fields.added

=head1 DESCRIPTION

This entity represents a single row of an alignment.
In general, this corresponds to a sequence, but in a
concatenated alignment multiple sequences may be represented
here.

Example:

    get_entity_AlignmentRow -a < ids > table.with.fields.added

would read in a file of ids and add a column for each field in the entity.

The standard input should be a tab-separated table (i.e., each line
is a tab-separated set of fields).  Normally, the last field in each
line would contain the id. If some other column contains the id,
use

    -c N

where N is the column (from 1) that contains the id.

This is a pipe command. The input is taken from the standard input, and the
output is to the standard output.

=head2 Related entities

The AlignmentRow entity has the following relationship links:

=over 4
    
=item ContainsAlignedDNA ContigSequence

=item ContainsAlignedProtein ProteinSequence

=item IsAlignmentRowIn Alignment


=back

=head1 COMMAND-LINE OPTIONS

Usage: get_entity_AlignmentRow [arguments] < ids > table.with.fields.added

    -a		    Return all available fields.
    -c num          Select the identifier from column num.
    -i filename     Use filename rather than stdin for input.
    --fields list   Choose a set of fields to return. List is a comma-separated list of strings.
    -a		    Return all available fields.
    --show-fields   List the available fields.

The following fields are available:

=over 4    

=item row_number

1-based ordinal number of this row in the alignment

=item row_id

identifier for this row in the FASTA file for the alignment

=item row_description

description of this row in the FASTA file for the alignment

=item n_components

number of components that make up this alignment row; for a single-sequence alignment this is always "1"

=item beg_pos_aln

the 1-based column index in the alignment where this sequence row begins

=item end_pos_aln

the 1-based column index in the alignment where this sequence row ends

=item md5_of_ungapped_sequence

the MD5 of this row's sequence after gaps have been removed; for DNA and RNA sequences, the [b]U[/b] codes are also normalized to [b]T[/b] before the MD5 is computed

=item sequence

sequence for this alignment row (with indels)


=back

=head1 AUTHORS

L<The SEED Project|http://www.theseed.org>

=cut


our $usage = <<'END';
Usage: get_entity_AlignmentRow [arguments] < ids > table.with.fields.added

    -c num          Select the identifier from column num
    -i filename     Use filename rather than stdin for input
    --fields list   Choose a set of fields to return. List is a comma-separated list of strings.
    -a		    Return all available fields.
    --show-fields   List the available fields.

The following fields are available:

    row_number
        1-based ordinal number of this row in the alignment
    row_id
        identifier for this row in the FASTA file for the alignment
    row_description
        description of this row in the FASTA file for the alignment
    n_components
        number of components that make up this alignment row; for a single-sequence alignment this is always "1"
    beg_pos_aln
        the 1-based column index in the alignment where this sequence row begins
    end_pos_aln
        the 1-based column index in the alignment where this sequence row ends
    md5_of_ungapped_sequence
        the MD5 of this row's sequence after gaps have been removed; for DNA and RNA sequences, the [b]U[/b] codes are also normalized to [b]T[/b] before the MD5 is computed
    sequence
        sequence for this alignment row (with indels)
END



use Bio::KBase::CDMI::CDMIClient;
use Getopt::Long;

#Default fields

my @all_fields = ( 'row_number', 'row_id', 'row_description', 'n_components', 'beg_pos_aln', 'end_pos_aln', 'md5_of_ungapped_sequence', 'sequence' );
my %all_fields = map { $_ => 1 } @all_fields;

my $column;
my $a;
my $f;
my $i = "-";
my @fields;
my $help;
my $show_fields;
my $geO = Bio::KBase::CDMI::CDMIClient->new_get_entity_for_script('c=i'		 => \$column,
								  "all-fields|a" => \$a,
								  "help|h"	 => \$help,
								  "show-fields"	 => \$show_fields,
								  "fields=s"	 => \$f,
								  'i=s'		 => \$i);
if ($help)
{
    print $usage;
    exit 0;
}

if ($show_fields)
{
    print STDERR "Available fields:\n";
    print STDERR "\t$_\n" foreach @all_fields;
    exit 0;
}

if ($a && $f) 
{
    print STDERR "Only one of the -a and --fields options may be specified\n";
    exit 1;
} 
if ($a)
{
    @fields = @all_fields;
}
elsif ($f) {
    my @err;
    for my $field (split(",", $f))
    {
	if (!$all_fields{$field})
	{
	    push(@err, $field);
	}
	else
	{
	    push(@fields, $field);
	}
    }
    if (@err)
    {
	print STDERR "get_entity_AlignmentRow: unknown fields @err. Valid fields are: @all_fields\n";
	exit 1;
    }
} else {
    print STDERR $usage;
    exit 1;
}

my $ih;
if ($i eq '-')
{
    $ih = \*STDIN;
}
else
{
    open($ih, "<", $i) or die "Cannot open input file $i: $!\n";
}

while (my @tuples = Bio::KBase::Utilities::ScriptThing::GetBatch($ih, undef, $column)) {
    my @h = map { $_->[0] } @tuples;
    my $h = $geO->get_entity_AlignmentRow(\@h, \@fields);
    for my $tuple (@tuples) {
        my @values;
        my ($id, $line) = @$tuple;
        my $v = $h->{$id};
	if (! defined($v))
	{
	    #nothing found for this id
	    print STDERR $line,"\n";
     	} else {
	    foreach $_ (@fields) {
		my $val = $v->{$_};
		push (@values, ref($val) eq 'ARRAY' ? join(",", @$val) : $val);
	    }
	    my $tail = join("\t", @values);
	    print "$line\t$tail\n";
        }
    }
}
__DATA__
