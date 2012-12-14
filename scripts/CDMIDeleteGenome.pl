#!/usr/bin/perl -w

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

use strict;
use SeedUtils;
use Bio::KBase::CDMI::CDMI;
use Bio::KBase::CDMI::CDMILoader;
use Stats;

=head1 Delete Genome

    CDMIDeleteGenome [options] genomeID

This is a simple script that deletes one or more genomes.

=head2 Command-Line Options and Parameters

The command-line options are those specified in L<Bio::KBase::CDMI::CDMI/new_for_script>.
plus the following.

=over 4

=item file

If specified, the list of IDs for the genomes to delete is taken from a
tab-delimited input file. The file name may be specified as an option
value, or if the option is specified without a value, the file will be
taken from the standard input.

=back

If the I<file> parameter is not specified, the list of genome IDs is taken from
the positional parameters.

=cut

# Turn off buffering for progress messages.
$| = 1;
# This will hold the FILE option parameter.
my $file;
# Connect to the database.
my $cdmi = Bio::KBase::CDMI::CDMI->new_for_script("file:s" => \$file);
# Get the genome IDs. We need to figure out if we have a file or not.
my @genomeIDs;
if (defined $file) {
    # Here we have an input file.
    if (! $file) {
        # The file is the standard input. A hyphen is used as the file
        # name.
        $file = "-";
    } else {
        # Here we have a physical file.
        if (! -f $file) {
            die "Input file $file not found.\n";
        }
    }
    # Open the file for input and read in the genomes.
    open(my $ih, "<$file") || die "Could not open input file: $!\n";
    while (! eof $ih) {
        my ($genomeID) = Bio::KBase::CDMI::CDMILoader::GetLine($ih);
        push @genomeIDs, $genomeID;
    }
    print scalar(@genomeIDs) . " genome IDs read from $file.\n";
} else {
    # Here the genome IDs are on the command line.
    push @genomeIDs, @ARGV;
    print scalar(@genomeIDs) . " genome IDs found on command line.\n";
}
# Delete the genomes.
my $stats = Stats->new();
for my $genomeID (@genomeIDs) {
    print "Deleting $genomeID.\n";
    my $subStats = $cdmi->Delete(Genome => $genomeID, 'print' => 1);
    $stats->Accumulate($subStats);
}
# Display the statistics.
print "All done:\n" . $stats->Show();
