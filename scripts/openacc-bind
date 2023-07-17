#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use FileHandle;
use Data::Dumper;

my %opts = (nn => $ENV{SLURM_NNODES} || 0, np => $ENV{SLURM_NTASKS} || 0, nnp => $ENV{SLURM_TASKS_PER_NODE} || 0,
            openmp => $ENV{OMP_NUM_THREADS} || 1, ngpus => $ENV{SLURM_GPUS_ON_NODE} || 1);

&GetOptions (map { ("$_=s", \$opts{$_}) } keys (%opts));

$opts{nnp} =~ s,\(.,,o if ($opts{nnp});
$opts{nnp} = $opts{np} / $opts{nn} unless ($opts{nnp});
$opts{np} = $opts{nn} * $opts{nnp} unless ($opts{np});
$opts{nn} = $opts{np} / $opts{nnp} unless ($opts{nn});

die &Dumper (\%opts) unless ($opts{nn} * $opts{nnp} == $opts{np});

my $fh = 'FileHandle'->new (">openacc_bind.txt");

for my $nn (1 .. $opts{nn})
  {
    for my $t (1 .. $opts{nnp})
      {   
        my $gpu = int (($t - 1) * $opts{ngpus} / $opts{nnp});
        $fh->print ("$gpu\n");
      }   
  }

$fh->close (); 


