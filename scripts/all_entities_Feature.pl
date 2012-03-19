use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#


=head1 all_entities_Feature

Return all instances of the Feature entity.

A feature (sometimes also called a gene) is a part of a
genome that is of special interest. Features may be spread across
multiple DNA sequences (contigs) of a genome, but never across more
than one genome. Each feature in the database has a unique
ID that functions as its ID in this table.
Normally a Feature is just a single contigous region on a contig.
Features have types, and an appropriate choice of available types
allows the support of protein-encoding genes, exons, RNA genes,
binding sites, pathogenicity islands, or whatever.


Example:

    all_entities_Feature -a 

would retrieve all entities of type Feature and include all fields
in the entities in the output.


=head2 Command-Line Options

=over 4

=item -a

Return all fields.

=item -h

Display a list of the fields available for use.

=item -fields field-list

Choose a set of fields to return. Field-list is a comma-separated list of 
strings. The following fields are available:

=over 4

=item feature_type

=item source_id

=item sequence_length

=item function

=back    
   
=back

=head2 Output Format

The standard output is a tab-delimited file. It consists of the input
file with an extra column added for each requested field.  Input lines that cannot
be extended are written to stderr.  

=cut

use Bio::KBase::CDMI::CDMIClient;
use Getopt::Long;

#Default fields

my @all_fields = ( 'feature_type', 'source_id', 'sequence_length', 'function' );
my %all_fields = map { $_ => 1 } @all_fields;

my $usage = "usage: all_entities_Feature [-show-fields] [-a | -f field list] > entity.data";

my $a;
my $f;
my @fields;
my $show_fields;
my $geO = Bio::KBase::CDMI::CDMIClient->new_get_entity_for_script("a" 		=> \$a,
								  "show-fields" => \$show_fields,
								  "h" 		=> \$show_fields,
								  "fields=s"    => \$f);

if ($show_fields)
{
    print STDERR "Available fields: @all_fields\n";
    exit 0;
}

if (@ARGV != 0 || ($a && $f))
{
    print STDERR $usage, "\n";
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
	print STDERR "all_entities_Feature: unknown fields @err. Valid fields are: @all_fields\n";
	exit 1;
    }
}

my $start = 0;
my $count = 1000;

my $h = $geO->all_entities_Feature($start, $count, \@fields );

while (%$h)
{
    while (my($k, $v) = each %$h)
    {
	print join("\t", $k, @$v{@fields}), "\n";
    }
    $start += $count;
    $h = $geO->all_entities_Feature($start, $count, \@fields);
}
