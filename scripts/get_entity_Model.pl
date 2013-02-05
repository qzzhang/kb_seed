use strict;
use Data::Dumper;
use Bio::KBase::Utilities::ScriptThing;
use Carp;

#
# This is a SAS Component
#

=head1 NAME

get_entity_Model

=head1 SYNOPSIS

get_entity_Model [-c N] [-a] [--fields field-list] < ids > table.with.fields.added

=head1 DESCRIPTION

A model specifies a relationship between sets of features and
reactions in a cell. It is used to simulate cell growth and gene
knockouts to validate annotations.

Example:

    get_entity_Model -a < ids > table.with.fields.added

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

The Model entity has the following relationship links:

=over 4
    
=item HasRequirementOf ReactionInstance

=item IsDividedInto LocationInstance

=item Manages Biomass

=item Models Genome


=back

=head1 COMMAND-LINE OPTIONS

Usage: get_entity_Model [arguments] < ids > table.with.fields.added

    -a		    Return all available fields.
    -c num          Select the identifier from column num.
    -i filename     Use filename rather than stdin for input.
    --fields list   Choose a set of fields to return. List is a comma-separated list of strings.
    -a		    Return all available fields.
    --show-fields   List the available fields.

The following fields are available:

=over 4    

=item mod_date

date and time of the last change to the model data

=item name

descriptive name of the model

=item version

revision number of the model

=item type

string indicating where the model came from (e.g. single genome, multiple genome, or community model)

=item status

indicator of whether the model is stable, under construction, or under reconstruction

=item reaction_count

number of reactions in the model

=item compound_count

number of compounds in the model

=item annotation_count

number of features associated with one or more reactions in the model


=back

=head1 AUTHORS

L<The SEED Project|http://www.theseed.org>

=cut


our $usage = <<'END';
Usage: get_entity_Model [arguments] < ids > table.with.fields.added

    -c num          Select the identifier from column num
    -i filename     Use filename rather than stdin for input
    --fields list   Choose a set of fields to return. List is a comma-separated list of strings.
    -a		    Return all available fields.
    --show-fields   List the available fields.

The following fields are available:

    mod_date
        date and time of the last change to the model data
    name
        descriptive name of the model
    version
        revision number of the model
    type
        string indicating where the model came from (e.g. single genome, multiple genome, or community model)
    status
        indicator of whether the model is stable, under construction, or under reconstruction
    reaction_count
        number of reactions in the model
    compound_count
        number of compounds in the model
    annotation_count
        number of features associated with one or more reactions in the model
END



use Bio::KBase::CDMI::CDMIClient;
use Getopt::Long;

#Default fields

my @all_fields = ( 'mod_date', 'name', 'version', 'type', 'status', 'reaction_count', 'compound_count', 'annotation_count' );
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
	print STDERR "get_entity_Model: unknown fields @err. Valid fields are: @all_fields\n";
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
    my $h = $geO->get_entity_Model(\@h, \@fields);
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
