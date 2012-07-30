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
use BasicLocation;

=head1 CDMI Phenotype Variations Loader

    CDMILoadVariations [options] source genomeDirectory

Load the phenotype variation data for a genome into a KBase Central Data
Model Instance. The variation data is represented by nine files in a
single directory. All of the IDs in the files are from the source
database, and need to be converted to KBase IDs. The low-level name
of the directory must be the same as the genome's ID in the source
database. In some cases there are two fields specified for an ID. In
this case, the first is an ID from the source database and the second
is a KBase ID. The KBase ID will be used if it is present, and the
source ID will be converted otherwise. If neither ID is present, then
it usually indicates that a particular link does not apply.

The files are as follows.

=over 4

=item experiment.tab

This file is used to fill the B<StudyExperiment> table. It contains (0)
the experiment ID (source-id), (1) the design of the experiment (design),
and (2) the authors (originator). The authors are sometimes expressed as
a paper citation.

=item obs_unit.tab

This file is used to fill the B<ObservationalUnit> table and its
associated relationships. It contains (0) the observational unit ID
(source-name), (1) the optional secondary name (source-name2),
(2,3) the ID of the experiment to which the unit belongs
(IncludesPart.from_link), (4,5) the ID of the locality where the
observation took place (HasUnits.from_link), (6,7) the ID of the
taxonomic grouping for the genetic source material, and (8) the
KBase ID of the relvant reference genome (UsesReference.to_link).

=item locality.tab

This file is used to fill the B<Locality> table. It contains (0) the
locality ID (source-name), (1) the elevation in meters (elecation),
(2) the city name (city), (3) the country name (country), (4) the
ISO 3166-1 extended country code (origcty), (5) the latitude (latitude),
(6) the longitude (longitude), (7) the state or province, and (8) the
gazeteer ontology term ID (lo-accession).

=item traits.tab

This file is used to fill the B<Trait> table. It contains (0) the
trait ID (trait-name), (1) the unit of measure (unit-of-measure),
(2) the trait ontology term ID (TO-ID), and (3) a description of the
protocol for measuring the trait (protocol).

=item measures.tab

This file is used to fill the B<HasTrait> table. It contains (0) the
source identifier of the measurement (measure-id), (1,2) the
ID of the trait being measured (to-link), (3,4) the ID of the
observational unit whose trait is being measured (from-link), (5) the
statistical type (statistic-type), and (6) the measurement value (value).

=item assay.tab



=back

=head2 Command-Line Options and Parameters

The command-line options are those specified in L<Bio::KBase::CDMI::CDMI/new_for_script> plus the
following.

=over 4

=item recursive

If this option is specified, then instead of loading a single genome from
the specified directory, a genome will be loaded from each subdirectory
of the specified directory. This allows multiple genomes from a single
source to be loaded in one pass.

=item clear

If this option is specified, the variation tables will be recreated
before loading.

=back

There are two positional parameters-- the source database name (e.g. C<SEED>,
C<MOL>, ...) and the name of the directory containing the variation data
for the genome.

=cut

# Create the command-line option variables.
my ($recursive, $clear);
# Turn off buffering for progress messages.
$| = 1;

# Connect to the database.
my $cdmi = Bio::KBase::CDMI::CDMI->new_for_script("recursive" => \$recursive,
        "clear" => \$clear);
if (! $cdmi) {
    print "usage: CDMILoadVariations [options] source genomeDirectory\n";
    exit;
}
print "Connected to CDMI.\n";
# Get the source and genome directory.
    my ($source, $genomeDirectory) = @ARGV;
    if (! $source) {
        die "No source database specified.\n";
    } elsif (! $genomeDirectory) {
        die "No genome directory specified.\n";
    } elsif (! -d $genomeDirectory) {
        die "Genome directory $genomeDirectory not found.\n";
    } else {

        my $loader = Bio::KBase::CDMI::CDMILoader->new($cdmi);
        $loader->SetSource($source);
        # Are we clearing?
        if($clear) {
            # Yes. Recreate the variations tables.
            ###TODO: YOU ARE HERE
            my @tables = qw(Publication Role Concerns IsFunctionalIn
                ProteinSequence IsProteinFor Feature FeatureAlias
                IsLocatedIn IsOwnerOf Submitted
                Contig IsComposedOf Genome IsAlignedIn Variation
                IsSequenceOf IsTaxonomyOf ContigSequence HasSection
                ContigChunk Encompasses);
            for my $table (@tables) {
                print "Recreating $table.\n";
                $cdmi->CreateTable($table, 1);
            }
        }
        # Are we in recursive mode?
        if (! $recursive) {
            # No. Load the one genome.
            LoadGenome($loader, $genomeDirectory);
        } else {
            # Yes. Get the subdirectories.
            opendir(TMP, $genomeDirectory) || die "Could not open $genomeDirectory.\n";
            my @subDirs = sort grep { substr($_,0,1) ne '.' } readdir(TMP);
            print scalar(@subDirs) . " entries found in $genomeDirectory.\n";
            # Loop through the subdirectories.
            for my $subDir (@subDirs) {
                my $fullPath = "$genomeDirectory/$subDir";
                if (-d $fullPath) {
                    LoadGenome($loader, $fullPath);
                }
            }
        }
        # Display the statistics.
        print "All done.\n" . $loader->stats->Show();
    }


=head2 Subroutines

=head3 LoadGenome

    LoadGenome($loader, $genomeDirectory);

Load a single genome from the specified genome directory.

=over 4

=item loader

L<Bio::KBase::CDMI::CDMILoader> object to help manager the load.

=item source

Source database the genome came from.

=item genomeDirectory

Directory containing the genome load files.

=back

=cut

sub LoadGenome {
    # Get the parameters.
    my ($loader, $genomeDirectory) = @_;
    # Indicate our progress.
    print "Processing $genomeDirectory.\n";
    # Compute the genome ID from the directory name.
    my @parts = split /\//, $genomeDirectory;
    my $genomeOriginalID = pop @parts;
    print "Computed genome ID is $genomeOriginalID.\n";
    $loader->SetGenome($genomeOriginalID);
    # Read the metadata file.
    my $metaName = $loader->genome_load_file_name($genomeDirectory, "metadata.tbl");
    my $metaHash = Bio::KBase::CDMI::CDMILoader::ParseMetadata($metaName);
    # Extract the genome name.
    my $scientificName = $metaHash->{name};
    if (! $scientificName) {
        die "No scientific name found in metadata for $genomeDirectory.\n";
    }
    # Get the KBID for this genome.
    my $genomeID = $loader->GetKBaseID('kb|g', 'Genome', $genomeOriginalID);
    # If this genome exists and we are only loading new genomes, skip it.
    if ($cdmi->Exists(Genome => $genomeID)) {
        $loader->stats->Add(genomeSkipped => 1);
        print "Genome skipped: already in database.\n";
    } else {
        # Delete any existing data for this genome.
        DeleteGenome($loader, $genomeID);
        # Ensure the genome has data.
        my $contigName = $loader->genome_load_file_name($genomeDirectory, "contigs.fa");
        if (! -s $contigName) {
            print "Genome skipped: no contig data.\n";
        } else {
            # Initialize the relation loaders. The order of the relations is
            # important, since it determines whether or not the DeleteGenome
            # method will work properly.
            $loader->SetRelations(qw(IsComposedOf Contig IsSequenceOf
                    IsOwnerOf Feature FeatureAlias IsLocatedIn IsFunctionalIn
                    IsProteinFor Encompasses));
            # Load the contigs.
            my ($contigMap, $dnaSize, $gcContent, $md5) = LoadContigs($loader,
                    $genomeID, $genomeOriginalID, $contigName);
            # Load the features.
            my ($pegs, $rnas, $id_mapping) = LoadFeatures($loader, $genomeID,
                    $genomeDirectory, $contigMap);
            # Load the proteins.
            my $protName = $loader->genome_load_file_name($genomeDirectory, "proteins.fa");
            LoadProteins($loader, $id_mapping, $protName);
            # Unspool the relation loaders.
            $loader->LoadRelations();
            # Create the genome record.
            CreateGenome($loader, $source, $genomeID, $genomeOriginalID, $metaHash,
                    $dnaSize, $gcContent, $md5, $pegs, $rnas, scalar(keys %$contigMap));
        }
    }
}

=head3 DeleteGenome

    DeleteGenome($loader, $genomeID);

Delete the existing data for the specified genome. This method is designed
to work even if the genome was only partially loaded. It will not, however,
delete any roles or proteins, since these do not belong to the genome.

=over 4

=item loader

L<Bio::KBase::CDMI::CDMILoader> object to help manager the load.

=item genomeID

KBase ID of the genome to delete.

=back

=cut

sub DeleteGenome {
    # Get the parameters.
    my ($loader, $genomeID) = @_;
    print "Deleting old copy of genome $genomeID.\n";
    # Get the database object.
    my $cdmi = $loader->cdmi;
    # Get the statistics object.
    my $stats = $loader->stats;
    # Delete the contigs.
    $loader->DeleteRelatedRecords($genomeID, 'IsComposedOf', 'Contig');
    # Delete the features.
    $loader->DeleteRelatedRecords($genomeID, 'IsOwnerOf', 'Feature');
    # Check for a taxonomy connection.
    my ($taxon) = $cdmi->GetFlat("IsTaxonomyOf", 'IsTaxonomyOf(to_link) = ?',
            [$genomeID], 'from-link');
    if ($taxon) {
        # We found one, so disconnect it.
        $cdmi->DeleteRow('IsTaxonomyOf', $taxon, $genomeID);
        $stats->Add(IsTaxonomyOf => 1);
    }
    # Check for a submit connection.
    my ($source) = $cdmi->GetFlat("Submitted", 'Submitted(to_link) = ?',
            [$genomeID], 'from-link');
    if ($source) {
        # We found one, so disconnect it.
        $cdmi->DeleteRow('Submitted', $source, $genomeID);
        $stats->Add(Submitted => 1);
    }
    # Delete the genome itself.
    my $subStats = $cdmi->Delete(Genome => $genomeID);
    # Roll up the statistics.
    $stats->Accumulate($subStats);
}

=head3 LoadContigs

    my ($contigMap, $dnaSize, $gcContent, $md5) =
        LoadContigs($loader, $genomeID, $genomeOriginalID,
        $contigFastaFile);

Load the contigs for the specified genome into the database.

=over 4

=item loader

L<Bio::KBase::CDMI::CDMILoader> object to help manager the load.

=item genomeID

KBase ID of the genome being loaded.

=item genomeOriginalID

ID of the genome in the original database.

=item contigFastaFile

Name of the FASTA file containing the DNA for the contigs.

=item RETURN

Returns a list with four elements: (0) a reference to a hash mapping
the foreign identifier of each contig to the KBase ID, (1) the number of base pairs in all of
the contigs put together, (2) the percent GC content in the DNA, and
(3) the genome's MD5 identifer.

=back

=cut

sub LoadContigs {
    # Get the parameters.
    my ($loader, $genomeID, $genomeOriginalID, $contigFastaFile) = @_;
    # Get the CDMI database object.
    my $cdmi = $loader->cdmi;
    # Get the statistics object.
    my $stats = $loader->stats;
    # Create an MD5 computer so we can compute the contig and genome
    # MD5s.
    my $md5Object = MD5Computer->new();
    # Create the return variables. Note that until we're ready to return
    # to the caller, $gcContent will contain the total number of GC base
    # pairs found, not the percentage.
    my ($contigMap, $dnaSize, $gcContent) = ({}, 0, 0);
    # Open the contig FASTA file.
    open(my $ih, "<$contigFastaFile") || die "Could not open contig file: $!\n";
    # Get the length of a DNA segment.
    my $segmentLength = $cdmi->TuningParameter('maxSequenceLength');
    # Each contig is separated into a real contig that belongs to the
    # genome and a contig sequence that represents the DNA. Since
    # contig sequences are shared, we cache each contig in memory
    # first and then load it after we've verified that the sequence is
    # new to the database.
    # We start by reading the identifier line for the first contig.
    my $line = <$ih>;
    unless ($line =~ /^>(\S+)\s*(.*)/) {
        die "Invalid format in contig file: $contigFastaFile.\n";
    } else {
        my ($foreignID, $comment) = ($1, $2);
        # Loop through the contigs.
        while (defined $foreignID) {
            # Get this contig's sequence.
            my ($sequence, $nextID, $comment) =
                    $loader->ReadFastaRecord($ih);
            # Normalize to lower case.
            $sequence = lc $sequence;
            # Update the GC and DNA counts.
            $gcContent += ($sequence =~ tr/gc//);
            my $contigLen = length $sequence;
            $dnaSize += $contigLen;
            $stats->Add(dnaLetters => $contigLen);
            # We must break the contig into chunks. We do this with unpack.
            my $chunkCount = int($contigLen / $segmentLength);
            my $template = ("A$segmentLength" x $chunkCount) . "A*";
            my @chunks = unpack($template, $sequence);
            $stats->Add(contigChunks => scalar @chunks);
            # We don't need the full sequence any more.
            undef $sequence;
            # Compute the contig's MD5.
            my $contigMD5 = $md5Object->ProcessContig($foreignID, \@chunks);
            my $contigKBID = $loader->GetKBaseID("$genomeID.c", 'Contig',
                    $foreignID);
            $contigMap->{$foreignID} = $contigKBID;
            # We now have all the information we need to load the contig
            # into the database. First, check to see if the sequence is
            # already in the database.
            my $contigSeqData = $cdmi->GetEntity(ContigSequence => $contigMD5);
            if (defined $contigSeqData) {
                # It is, so we don't have to create it.
                $stats->Add(contigReused => 1);
            } else {
                # Here we have to create the sequence.
                $stats->Add(contigFresh => 1);
                $cdmi->InsertObject('ContigSequence', id => $contigMD5,
                    'length' => $contigLen);
                # Loop through the chunks, connecting them to the contig.
                for (my $i = 0; $i < @chunks; $i++) {
                    # We have to create the key for this chunk. It's the
                    # contig key followed by the ordinal number padded to
                    # seven digits.
                    my $chunkID = $contigMD5 . ":" . ("0" x (7 - length($i))) . $i;
                    # Create the chunk and connect it to the sequence.
                    $cdmi->InsertObject('HasSection', from_link => $contigMD5,
                            to_link => $chunkID);
                    $cdmi->InsertObject('ContigChunk', id => $chunkID,
                        sequence => $chunks[$i]);
                    $stats->Add(chunkInserted => 1);
                }
            }
            # Now the sequence is in the database. Add the contig and
            # connect it to the genome.
            $loader->InsertObject('IsComposedOf', from_link => $genomeID,
                    to_link => $contigKBID);
            $loader->InsertObject('Contig', id => $contigKBID,
                    source_id => $foreignID);
            $loader->InsertObject('IsSequenceOf', from_link => $contigMD5,
                    to_link => $contigKBID);
            $stats->Add(contigs => 1);
            # Set up for the next contig.
            $foreignID = $nextID;
        }
    }
    # Compute the genome's MD5.
    my $md5 = $md5Object->CloseGenome();
    # Convert the GC content to a percentage.
    $gcContent = $gcContent * 100 / $dnaSize;
    print "$dnaSize base pairs loaded from $contigFastaFile.\n";
    # Return the computation results.
    return ($contigMap, $dnaSize, $gcContent, $md5);
}

=head3 LoadFeatures

    my ($pegs, $rnas, $id_mapping) = LoadFeatures($loader,
            $genomeID, $genomeDirectory, $contigMap);

Load the genome's features into the database from the feature files.
The feature information is kept in two tab-delimited files-- one
that specifies the feature types and locations, and one that
specifies each feature's functional assignment.

=over 4

=item loader

L<Bio::KBase::CDMI::CDMILoader> object to help manager the load.

=item genomeID

KBase ID of the genome being loaded.

=item genomeDirectory

Directory containing the feature files-- C<features.tab> and C<functions.tab>.

=item contigMap

Reference to a hash that maps each contig's foreign identifier to
its KBase ID.

=item RETURN

Returns a list containing (0) the number of protein-encoding genes
in the genome, (1) the number of RNAs in the genome, and (2) a
reference to a hash mapping foreign feature IDs to KBase IDs.

=back

=cut

sub LoadFeatures {
    # Get the parameters.
    my ($loader, $genomeID, $genomeDirectory, $contigMap) = @_;
    # Get the statistics object.
    my $stats = $loader->stats;
    # Initialize the return variables.
    my ($pegs, $rnas) = (0, 0);
    # Count the total features for the progress display.
    my $fidCount = 0;
    # Create the feature ID mapping.
    my $id_mapping = {};
    # This will save the aliases.
    my $aliasMap = {};
    # We'll track the parents in here.
    my %parentMap;
    # To pull this off, we need to read two files in parallel-- one
    # containing the locations and the feature types, and one containing
    # the assignments. Both files have the feature ID in the first
    # column, so we sort them and use standard merge logic.
    my $featFileName = $loader->genome_load_file_name($genomeDirectory, 'features.tab');
    my $funcFileName = $loader->genome_load_file_name($genomeDirectory, 'functions.tab');
    open(my $feath, "sort \"$featFileName\" |") || die "Could not open features file: $!\n";
    my ($fid1, $type, $locations, $parent, $subset, @aliases) = $loader->GetLine($feath);
    $fidCount++;
    open(my $funch, "sort \"$funcFileName\" |") || die "Could not open functions file: $!\n";
    $stats->Add(functionLines => 1);
    my ($fid2, $function) = $loader->GetLine($funch);

    # Loop through the files. Note that it is acceptable for a feature to
    # be without an assignment, but an assignment without a location and a
    # type is an error and is discarded. Thus, the key file of interest is
    # the feature file, represented by $fid1. We will process the features
    # in batches of 1000 at a time. Each batch is formed into a hash
    # mapping feature IDs to 3-tuples (type, location, function). We
    # then get the KBase IDs for all the features and put the batch
    # into the database.

    my %fidBatch;
    my $batchSize = 0;
    while (defined $fid1) {
        # Get rid of any function file entries that did not have matching
        # feature file entries.
        while (defined $fid2 && $fid2 lt $fid1) {
            ($fid2, $function) = $loader->GetLine($funch);
            $stats->Add(orphanFunction => 1);
            $stats->Add(functionLines => 1);
        }
        # Compute the function for this feature. It's either the current
        # function file entry or an empty string. If it's the current
        # function file entry we advance the function file for the next
        # loop iteration.
        my $fidFunction = "";
        if (defined $fid2 && $fid2 eq $fid1) {
            # We take care to insure the function exists. Some
            # function file entries have only a feature ID. If this
            # is the case, we want to stick with the null string currently
            # in there.
            if (defined $function) {
                $fidFunction = $function;
            }
            # Advance the function file to the next entry.
            ($fid2, $function) = $loader->GetLine($funch);
            $stats->Add(functionLines => 1);
        }
        # If this feature has aliases, save them.
        if (@aliases) {
            $aliasMap->{$fid1} = \@aliases;
            $stats->Add(aliasesFound => 1);
            $stats->Add(aliasIn => scalar(@aliases));
        }
        # If this feature has a parent, save it.
        if ($parent) {
            $parentMap{$fid1} = $parent;
            $stats->Add(parentIn => 1);
        }
        # Put this feature into the hash.
        $fidBatch{$fid1} = [$type, $locations, $fidFunction];
        $batchSize++;
        # Is the batch full?
        if ($batchSize >= 1000) {
            # Yes. Process It.
            ProcessFeatureBatch($loader, $id_mapping, \$pegs, \$rnas, $genomeID,
                    \%fidBatch, $contigMap, $aliasMap);
            # Start the next one.
            %fidBatch = ();
            $batchSize = 0;
        }
        # Get the next feature in the feature file.
        ($fid1, $type, $locations) = $loader->GetLine($feath);
        $fidCount++;
    }
    # Process the residual batch.
    if ($batchSize > 0) {
        ProcessFeatureBatch($loader, $id_mapping, \$pegs, \$rnas, $genomeID,
                \%fidBatch, $contigMap, $aliasMap);
    }
    # Finish out the function file. We only do this to get the statistics.
    while (defined $fid2) {
        ($fid2, $function) = $loader->GetLine($funch);
        $stats->Add(orphanFunction => 1);
        $stats->Add(functionLines => 1);
    }
    # Process the parents.
    for my $child (keys %parentMap) {
        my $parent = $parentMap{$child};
        # Insure the parent ID is valid.
        if (! $id_mapping->{$parent}) {
            $stats->Add(missingParent => 1);
        } else {
            # Store it in the Encompasses table.
            $loader->InsertObject('Encompasses', from_link => $id_mapping->{$child},
                    to_link => $id_mapping->{$parent});
        }
    }
    # Accumulate the statistics on the number of features.
    $stats->Add(featureLines => $fidCount);
    # Display our progress.
    print "$fidCount features loaded from $genomeDirectory.\n";
    # Return the feature type counts and the mappings.
    return ($pegs, $rnas, $id_mapping);
}

=head3 ProcessFeatureBatch

    ProcessFeatureBatch($loader, $id_mapping, \$pegs, \$rnas,
                        $genomeID, \%fidBatch, \%contigMap, \%aliasMap);

Load a batch of features into the database. Features are processed
in batches to reduce the overhead for requesting feature IDs from
the KBase ID service.

=over 4

=item loader

L<Bio::KBase::CDMI::CDMILoader> object to help manager the load.

=item id_mapping

Reference to hash mapping foreign feature IDs to KBase IDs.

=item pegs

Reference to the counter for the number of protein-encoding genes found.

=item rnas

Reference to the counter for the number of RNAs found.

=item genomeID

KBase ID of the genome being loaded.

=item fidBatch

Reference to a hash that maps each foreign feature ID to a 3-tuple
consisting of (0) the feature type, (1) the feature's location strings,
and (2) the feature's functional assignment.

=item contigMap

Reference to a hash that maps each contig's foreign identifier to
its KBase ID.

=item aliasMap

Reference to a hash that maps each feature's foreign identifier to
a list of aliases (if any).

=cut

sub ProcessFeatureBatch {
    # Get the parameters.
    my ($loader, $id_mapping, $pegs, $rnas, $genomeID,
            $fidBatch, $contigMap, $aliasMap) = @_;
    # Get the CDMI database.
    my $cdmi = $loader->cdmi;
    # Get the statistics object.
    my $stats = $loader->stats;
    $stats->Add(featureBatches => 1);
    # Compute the maximum location segment length.
    my $segmentLength = $cdmi->TuningParameter('maxLocationLength');
    # Get all the KBase IDs for the features in this batch.
    my @fids = keys %$fidBatch;

    #
    # We need to split the features by type in order to have the correct prefix.
    #
    my %typemap;
    for my $fid (@fids) {
        my($type) = $fidBatch->{$fid}->[0];
        push(@{$typemap{$type}}, $fid);
    }
    for my $type (keys %typemap) {
        my $h = $loader->GetKBaseIDs("$genomeID.$type", 'Feature',
               $typemap{$type});
        $id_mapping->{$_} = $h->{$_} foreach keys %$h;
    }
    # Now we have all the KBase IDs we need. Loop through the batch.
    for my $fid (@fids) {
        # Get the KBase ID for this feature.
        my $fidKBID = $id_mapping->{$fid};
        # Get the type, location, and function.
        my ($type, $locations, $function) = @{$fidBatch->{$fid}};
        # Parse the locations.
        my @locs = map { BasicLocation->new($_) } split /\s*,\s*/, $locations;
        $stats->Add(featureLocations => scalar @locs);
        # Compute the total feature length.
        print "Processing $fid.\n"; ##HACK
        my $len = $locs[0]->Length;
        for (my $i = 1; $i < @locs; $i++) {
            $len += $locs[$i]->Length;
        }
        # Create the feature record.
        $loader->InsertObject('IsOwnerOf', from_link => $genomeID,
                to_link => $fidKBID);
        $loader->InsertObject('Feature', id => $fidKBID,
                feature_type => $type, function => $function,
                sequence_length => $len, source_id => $fid);
        $stats->Add(features => 1);
        # Check for aliases.
        my $aliases = $aliasMap->{$fid};
        if (defined $aliases) {
            for my $alias (@$aliases) {
                $loader->InsertObject('FeatureAlias', id => $fidKBID,
                        alias => $alias);
                $stats->Add(featureAlias => 1);
            }
        }
        # Count the feature type.
        $stats->Add("featureType-$type" => 1);
        $$pegs++ if $type eq 'CDS';
        $$rnas++ if $type eq 'rna';
        # Check the contig IDs in the locations.  If we find an
        # invalid contig ID, we must skip the location data for
        # this feature.
        my $badContig = 0;
        for my $loc (@locs) {
            if (! defined $contigMap->{$loc->Contig}) {
                $badContig++;
                print "Contig " . $loc->Contig . " not found for feature $fid.\n";
            }
        }
        if ($badContig) {
            $stats->Add(badContigs => $badContig);
            $stats->Add(featureContigError => 1);
        } else {
            # Now we need to create the feature's location segments.
            # This variable counts the segments created.
            my $locIndex = 0;
            # Loop through the sub-locations.
            for my $loc (@locs) {
                # Compute this location's contig.
                my $contigKBID = $contigMap->{$loc->Contig};
                # Divide the location into segments.
                while (my $segment = $loc->Peel($segmentLength)) {
                    # Output this segment.
                    $loader->InsertObject('IsLocatedIn', from_link => $fidKBID,
                            to_link => $contigKBID, begin => $segment->Left,
                            dir => $segment->Dir, 'len' => $segmentLength,
                            ordinal => $locIndex++);
                    $stats->Add(locSegments => 1);
                }
                # Output the residual part of the location.
                $loader->InsertObject('IsLocatedIn', from_link => $fidKBID,
                        to_link => $contigKBID, begin => $loc->Left,
                        dir => $loc->Dir, 'len' => $loc->Length,
                        ordinal => $locIndex);
                $stats->Add(locSegments => 1);
            }
        }
        # Finally, we associate the feature with its roles.
        my ($roles, $errors) = SeedUtils::roles_for_loading($function);
        if (! defined $roles) {
            # Here the function does not appear to be a role.
            $stats->Add(roleRejected => 1);
        } else {
            # Here the function contained one or more roles. Count
            # the number of roles that were rejected for being too
            # long.
            $stats->Add(rolesTooLong => $errors);
            # Loop through the roles found.
            for my $role (@$roles) {
                # Insure this role is in the database.
                my $roleID = $loader->CheckRole($role);
                # Connect it to the feature.
                $loader->InsertObject('IsFunctionalIn', from_link => $roleID,
                        to_link => $fidKBID);
            }
        }
    }
}

=head3 LoadProteins

    LoadProteins($loader, $id_mapping, $proteinFastaFile);

Load the protein translations into the database.

=over 4

=item loader

L<Bio::KBase::CDMI::CDMILoader> object to help manager the load.

=item id_mapping

Reference to a hash mapping foreign feature IDs to KBase IDs.

=item proteinFastaFile

Name of a FASTA file containing the protein translation for each feature.

=back

=cut

sub LoadProteins {
    # Get the parameters.
    my ($loader, $id_mapping, $proteinFastaFile) = @_;
    # Get the statistics object.
    my $stats = $loader->stats;
    # Ensure the protein file exists and is nonempty.
    if (! -s $proteinFastaFile) {
        $stats->Add(emptyProteinFile => 1);
    } else {
        # Open the protein file for input.
        open(my $ih, "<$proteinFastaFile") || die "Could not open protein file: $!\n";
        # This will count the proteins.
        my $protCount = 0;
        # Read the header of the first protein.
        my $line = <$ih>;
        unless ($line =~ /^>(\S+)\s*(.*)/) {
            die "Invalid format in protein file: $proteinFastaFile.\n";
        } else {
            # Loop through the fasta file.
            my ($fid, $comment) = ($1, $2);
            while (defined $fid) {
                # Get this feature's protein.
                my ($sequence, $nextFid, $comment) = $loader->ReadFastaRecord($ih);
                $protCount++;
                # Insure the protein sequence is in the database and get its
                # ID.
                my $protID = $loader->CheckProtein($sequence);
                # Look for the feature.
                my $kbid = $id_mapping->{$fid};
                if (! $kbid) {
                    # Not found, so we have an error.
                    print STDERR "Feature $fid for protein sequence not found.\n";
                    $stats->Add(proteinFeatureNotFound => 1);
                } else {
                    # Found, so we can connect the protein to the feature.
                    $loader->InsertObject('IsProteinFor', from_link => $protID,
                            to_link => $kbid);
                    $stats->Add(featureProtein => 1);
                }
                # Set up for the next feature.
                $fid = $nextFid;
            }
        }
        # Update the protein statistics.
        $stats->Add(proteinsIn => $protCount);
        # Display our progress.
        print "$protCount proteins loaded from $proteinFastaFile.\n";
    }
}

=head3 CreateGenome

    CreateGenome($loader, $source, $genomeID, $genomeOriginalID,
                 $metaHash, $dnaSize, $gcContent, $md5, $pegs,
                 $rnas);

Create the genome record.

=over 4

=item loader

L<Bio::KBase::CDMI::CDMILoader> object to help manager the load.

=item source

Source database the genome came from.

=item genomeID

KBase ID of the genome being loaded.

=item source

Source database the genome came from.

=item genomeOriginalID

Foreign identifier of the genome in the source database.

=item metaHash

Reference to a hash containing the contents of the metadata file.

=item dnaSize

Number of base pairs in the genome's DNA.

=item gcContent

Percent GC content in the DNA.

=item md5

MD5 identifier of the genome's DNA sequence.

=item pegs

Number of protein-encoding genes in the genome.

=item rnas

Number of RNAs in the genome.

=item contigs

Number of contigs in the genome.

=back

=cut

sub CreateGenome {
    # Get the parameters.
    my ($loader, $source, $genomeID, $genomeOriginalID, $metaHash, $dnaSize, $gcContent, $md5, $pegs, $rnas, $contigs) = @_;
    # Get the statistics object.
    my $stats = $loader->stats;
    # Get the database object.
    my $cdmi = $loader->cdmi;
    # Default the domain to an empty string (unknown).
    my $domain = "";
    my $prokaryotic = 0;
    # Get the scientific name from the metadata.
    my $scientificName = $metaHash->{name};
    if (! $scientificName) {
        die "Invalid or missing name for $genomeOriginalID.\n";
    }
    # Try to find the taxon ID for this genome.
    my $taxID = $cdmi->ComputeTaxonID($scientificName);
    # If we found one, connect it to the genome and compute the domain.
    if (defined $taxID) {
        $cdmi->InsertObject('IsTaxonomyOf', from_link => $taxID,
                to_link => $genomeID);
        $stats->Add(genomeHasTaxon => 1);
        # Now we need to compute the domain. We do a looping climb up
        # the taxonomy tree.
        my $currentTaxID = $taxID;
        while ($currentTaxID && ! $domain) {
            my ($taxTuple) = $cdmi->GetAll('IsInGroup TaxonomicGrouping',
                    "IsInGroup(from_link) = ?", [$currentTaxID],
                    "TaxonomicGrouping(id) TaxonomicGrouping(domain) TaxonomicGrouping(scientific_name)");
            if (! $taxTuple) {
                # We've run off the end, so we stop the loop without a
                # domain.
                undef $currentTaxID;
            } else {
                # Get the data about this group.
                my ($nextTaxID, $domainFlag, $nextTaxName) = @$taxTuple;
                if ($domainFlag) {
                    # Here we've found a domain group, so save its name.
                    $domain = $nextTaxName;
                    # Decide if it's prokaryotic.
                    if ($nextTaxID == 2 || $nextTaxID == 2157) {
                        $prokaryotic = 1;
                    }
                } else {
                     # Here we have to keep looking.
                     $currentTaxID = $nextTaxID;
                }
            }
        }
    }
    # Connect the genome to its submitting source.
    $cdmi->InsertObject('Submitted', from_link => $source, to_link => $genomeID);
    $loader->InsureEntity(Source => $source);
    # Get the attributes.
    my $geneticCode = $metaHash->{genetic_code} || 11;
    my $complete = $metaHash->{complete} || 1;
    # Now we create the genome record itself.
    $cdmi->InsertObject('Genome', id => $genomeID, complete => $complete,
            contigs => $contigs, dna_size => $dnaSize, domain => $domain,
            gc_content => $gcContent, genetic_code => $geneticCode,
            md5 => $md5, pegs => $pegs, prokaryotic => $prokaryotic,
            rnas => $rnas, scientific_name => $scientificName,
            source_id => $genomeOriginalID);
    $stats->Add(genomesAdded => 1);
    print "Genome $genomeID created.\n";
}
