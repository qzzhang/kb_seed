use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#


=head1 all_entities_Variant

Return all instances of the Variant entity.

Each subsystem may include the designation of distinct variants.  Thus,
there may be three closely-related, but distinguishable forms of histidine
degradation.  Each form would be called a "variant", with an associated code,
and all genomes implementing a specific variant can easily be accessed.


Example:

    all_entities_Variant -a 

would retrieve all entities of type Variant and include all fields
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

=item role_rule

=item code

=item type

=item comment

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

my @all_fields = ( 'role_rule', 'code', 'type', 'comment' );
my %all_fields = map { $_ => 1 } @all_fields;

my $usage = "usage: all_entities_Variant [-show-fields] [-a | -f field list] > entity.data";

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
	print STDERR "all_entities_Variant: unknown fields @err. Valid fields are: @all_fields\n";
	exit 1;
    }
}

my $start = 0;
my $count = 1000;

my $h = $geO->all_entities_Variant($start, $count, \@fields );

while (%$h)
{
    while (my($k, $v) = each %$h)
    {
	print join("\t", $k, @$v{@fields}), "\n";
    }
    $start += $count;
    $h = $geO->all_entities_Variant($start, $count, \@fields);
}
