#!/usr/bin/env perl  
#RJ #!/usr/local/apps/perl/current/bin/perl
#RJ-time 0m 39.1s (do while)
#RJ-tim0 0m 0.0s (xargs)
#RJ-tim1 0m 0.0s
# Updated 01/2012 : Based on Coding standards 24/11/11
# Paul Burton

use FindBin qw ($Bin);
use lib $Bin;

use strict;
#RJ-time 0m 48.8s (do while)
#RJ-tim0 0m 0.0s (xargs)
#RJ-tim1 0m 0.0s
use warnings;
#RJ-time 1m 31.3s (do while)
#RJ-tim0 0m 0.0s (xargs)
#RJ-tim1 0m 0.1s
#RJ use lib "/home/rd/rdx/bin/prepifs/perl";
#RJ use lib "/home/rd/rdx/perl";
##use Fortran90_stuff qw();
#RJ-time 7m 29.3s (do while)
#RJ-tim0 0m 0.2s (xargs)
#use Fortran90_stuff qw( setup_parse $name $nest_par $study_called $f90s_FORGIVE_ME
#                        slurpfile slurp2array array2slurp slurp_split
#                        slurp_fpp slurp2file process_include_files_v2
#                        readfile process_include_files
#                        expcont study
#                        parse_prog_unit getvars find_unused_vars
#                        doctor_viol_v2 get_calls_inc_v2 );
use Fortran90_stuff qw( setup_parse $name $nest_par $study_called $f90s_FORGIVE_ME
                        slurpfile slurp2array array2slurp slurp_split
                        slurp_fpp slurp2file process_include_files_v2
                        expcont study );
#RJ-time 7m 44.2s(SelfLoader) 13m 47.4s(CompileAll) (do while)
#RJ-tim0 0m  0.2s(SelfLoader)  0m  0.5s(CompileAll) (xargs)
#RJ-tim1 0m 0.6s
use CodingNorms qw( $norms_reportFile %norms_config
                    setup_checker PrintStats PrintReportFile
                    simple_checks check_variables
                    check_line_rules check_interface_blocks
                    check_cpp_simple );
#RJ-time 8m 49.0s (do while)
#RJ-tim0 0m 0.3s (xargs)
#RJ-tim1 0m 0.6s

use Data::Dumper   qw(Dumper);
#RJ-time 8m 49.1s (do while)
#RJ-tim0 0m 0.3s (xargs)
#RJ-tim1 0m 0.6s
#RJ-old use Digest::SHA    qw(sha1_base64);
#RJ-time 8m 49.1s (do while)
#RJ-tim0 0m 0.3s (xargs)
#RJ-tim1 0m 0.6s
#RJ-old use File::Basename qw(basename);
#RJ-time 9m 10.1s (do while)
#RJ-tim0 0m 0.3s (xargs)
#RJ-tim1 0m 0.6s
#RJ-old use Getopt::Long   qw(GetOptions);
#RJ-time 11m 23.7s (do while)
#RJ-tim0 0m 0.4s (xargs)
#RJ-tim1 0m 0.7s

$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

#RJ: extra module to handle buffering of stdout and stderr
use IO::Handle;
#RJ-tim1 0m 0.7s

#RJ: force stderr to stdout to get cleaner logs
open (STDERR, '>&', STDOUT);
STDOUT->autoflush(1);
STDERR->autoflush(1);

my $cpp_def='';
my $cpp_undef='';
#RJ: FPP some stuff, for testing
#RJ:  defines to activate
#    $cpp_def ='LINUX|LITTLE|LITTLE_ENDIAN|HIGHRES|ADDRESS64|BLAS|STATIC_LINKING';
#    $cpp_def.='|SFX_NETCDF|FA|LFI|ARO|OL|ASC|TXT|BIN';
#    $cpp_def.='|SFX_FA|SFX_LFI|SFX_ARO|SFX_OL|SFX_ASC|SFX_TXT|SFX_BIN';
#    $cpp_def.='|ALADIN|NOMPI|SFX_NOMPI';

#RJ:  defines to deactivate
#    $cpp_undef= 'AIX64|RS6K|IBM_HPM|NECSX|VPP|BOM|FUJITSU|CRAY|T3D|SV2|SGI|DEC|HPPA|DEC';
#    $cpp_undef.='|__PGI|__INTEL_COMPILER|SUN4|DEBUG|DYNAMIC_LINKING|SERIAL|REALHUGE';
#    $cpp_undef.='|_BUFR_[A-Z]++|IRISHBUFR|HIRLAM|SERIAL|NAG';
#    $cpp_undef.='|HAS_MAGICS|NEW_MAGICS|NOT_REALLY_USED_HERE|OBSOLETE|ODB_API_SUPPORT';
#    $cpp_undef.='|RTTOV_[A-Z0-9_]++|_RTTOV_[A-Z_]++';
#    $cpp_undef.='|USE_MATMUL|USE_8_BYTE_WORDS|USE_CTRIM';
#    $cpp_undef.='|USE_SAMIO|WITH_NEMO|WITH_OASIS|MPI1|SQL';
#    $cpp_undef.='|USE_NETCDF|FLUX|PATHSCALE|PALADIN|ESATSFUN';
#    $cpp_undef.='|MNH|SFX_MNH';
#    $cpp_undef.='|OLD_SSMI_IMPLEMENTATION|NOTYETFIXED|FIXME';

#RJ: fpp only needed to fully parse all cy40 harmonie F90 sources without modifications,
#RJ  NEW_MAGICS define in src/odb/lib/Magics_dummy.F90, should be removed there
    $cpp_def.='';
    $cpp_undef='NEW_MAGICS';

#RJ: avoid implicit sharing, but for now allow it for reportFile
#RJ: renamed reportFile=>norms_reportFile,stats=>norms_stats to prep for move to CodingNorms.pm
#RJ: my ($full_fname,$reportFile,%stats);

{;
#RJ: renamed config=>norms_config, whitelist=>norms_whitelist, supress=>norms_supress to prep for move to CodingNorms.pm
#RJ   our (%config,%whitelist,@supress);

#RJ-time 11m 23.8s (do while)
#RJ-tim0 0m 0.4s (xargs)
  &setup_checker();
#RJ-time 11m 36.1s (do while)
#RJ-tim0 0m 0.4s (xargs)
#RJ-tim1 0m 0.7s

  my @files=@ARGV;

  &setup_parse();
#RJ-time 11m 36.7s (do while)
#RJ-tim0 0m 0.4s (xargs)
#RJ-tim1 0m 0.8s

#RJ: activate FORGIVE_ME, currently just not to bailout on undeclared variables
  our ${f90s_FORGIVE_ME}=1;

  our $study_called;

#RJ: unneeded
#RJ   my $null='';
#RJ-old   ${norms_reportFile}="";

  for my $fname (@files) {
#RJ: moved after unit split
#RJ-old     my (@inc_statements,@interface_block);
#RJ-old     my (%prog_info,@line_hash);

#RJ also check f95,f03,f08
    next unless ($fname=~/\.(?:F90|F95|F03|F08|f90|f95|f03|f08)$/);
#RJ: warn if not exists
#RJ     next unless ( -f $fname);
    unless ( -f $fname){
        warn "Warning: file $fname does not exists";
        next;
    }
#RJ-time 11m 37.9s (do while)
#RJ-tim0 0m 0.5s (xargs)
#RJ-tim1 0m 0.8s

#SM: set current file name in environment
    $ENV{'CHK_NORMS_CURRENT'} = $fname;

#RJ: alternative block
    &PrintReportFile(\$fname);
#RJ-old #RJ     $full_fname=$fname;
#RJ-old     if (! ${norms_config}{quiet}) {
#RJ-old #RJ       $reportFile=$full_fname;
#RJ-old       ${norms_reportFile}=$fname;
#RJ-old #RJ       print "\n\n========== Working on file $reportFile ==========\n";
#RJ-old      print "\n\n========== Working on file ${norms_reportFile} ==========\n";
#RJ-old     }
#RJ-old #RJ-time 11m 41.1s (do while) / 0m 0.5s (xargs)
#RJ-old #RJ-tim1 0m 0.8s

#RJ-old     my @lines;

#RJ: changing to a bit faster read function
#RJ-old    @lines = &readfile($fname);
#RJ-time 13m 35.9s (SelfLoader) 18m 54.5s (CompileAll) (do while)
#RJ-tim0  0m  3.9s (SelfLoader)  0m  4.1s (CompileAll) (xargs)
#RJ: slurp version, just dump file to string, faster by a few seconds
    my $slurp;
    &slurpfile(\$fname,\$slurp);
#RJ-tim1 0m 1.2s
#RJ-tim2 0m 1.2s

#RJ: just because of NEW_MAGICS define in src/odb/lib/Magics_dummy.F90, should be removed there
    &slurp_fpp(\$slurp,\$cpp_def,\$cpp_undef);
#RJ-tim2 0m 2.9s

#RJ     &slurp2array(\$slurp,\@lines);
#RJ-time 13m 22.6s (SelfLoader) 18m 46.1s (CompileAll) (do while)
#RJ-tim0  0m  2.2s (SelfLoader)  0m  2.3s (CompileAll) (xargs)
    my @splitted_units;
    &slurp_split(\$slurp,\$fname,\@splitted_units);
#RJ-tim1 0m 13.3s
#RJ-tim2 0m 13.6s

    foreach my $ii (0..$#splitted_units) {
##      warn "Unit[$ii] $fname";
      my $cur_fname=$fname;
      if($ii>0) {
        $cur_fname=~s/(\.F[0-9][0-9])$/__SPLIT$ii$1/;
      }
      my (%prog_info);
      my @statements=();
      my @lines;
      &slurp2array(\$splitted_units[$ii],\@lines);
#RJ-tim1 0m 14.9s
#RJ-tim2 0m 14.9s

      &expcont(\@lines,\@statements);
#RJ-time 13m 49.5s (do while)
#RJ-tim0 0m 28.2s (xargs)
#RJ-tim1 0m 51.0s
#RJ-tim1 0m 45.2s
 #     warn Dumper(@statements);
#RJ-old      our $study_called=0;
      $study_called=0;
      &study(\@statements,\%prog_info);
 # warn Dumper(@statements);
#RJ-time 15m 49.2s (do while)
#RJ-tim0 1m 23.3s (xargs)
#RJ-tim1 2m 1.4s
#RJ-tim2 1m 41.7s
#RJ-tim3 1m 42.1s
#RJ-tim4 1m 43.2s


#RJ-solved: still very slow ~3mins
#RJ: turns out it was @lines scope bug in original version, fixed in _v2
#RJ-old       my (@inc_statements);
#RJ-old       &process_include_files(\@statements,\%prog_info,\@inc_statements);
#RJ-time 18m 20.5s(SelfLoader) 22m 15.6s(CompileAll) (do while)
#RJ-time  3m 46.8s(SelfLoader)  3m 47.4s(CompileAll) (xargs)
#RJ-tim1 4m 59.3s
#RJ-tim2 4m 16.9s
      &process_include_files_v2(\@statements,\%prog_info);
#RJ-tim3 2m 32.8s
#RJ-tim4 2m 25.5s

#RJ: perform FPP checks
      &check_cpp_simple(\@statements,\$cur_fname);
#RJ-tim4 2m 43.1s

      &simple_checks(\@statements,\%prog_info,\$cur_fname);
#RJ-tim1 6m 45.6s
#RJ-tim2 5m 51.7s
#RJ-tim3 4m 5.9s
#RJ-tim4 4m 19.3s

#RJ: check_unused_vars
      &check_variables(\@statements,\%prog_info,\$cur_fname);
#RJ-tim1 11m 8.7s
#RJ-tim2 9m 17.4s
#RJ-tim3 6m 49.2s
#RJ-tim4 9m 59.8s

#RJ: check_line_rules
      &check_line_rules(\@lines,\$cur_fname);
#RJ-tim1 11m 28.2s
#RJ-tim2 9m 41.1s
#RJ-tim3 7m 22.6s
#RJ-tim4 7m 32.9s

#RJ: check_interface_blocks
      &check_interface_blocks(\@statements,\$cur_fname);
#RJ-tim1 11m 38.9s
#RJ-tim2 9m 41.2s
#RJ-tim3 7m 25.0s
#RJ-tim4 7m 40.4s
    }

#RJ: useless
#RJ     unless($prog_info{is_module}) {
#RJ     }
  }
  &PrintStats();
#RJ-time5  7m 27.6s (xargs)    check_norms_2011.pl is started 4 times ( yes thats few very long lines in shell ;) )
#                   time cat list.txt |xargs perl ./check_norm_2011.pl --intfbdir=1 > all_xargs.log
#RJ-time5 25m 25.8s (do while) check_norms_2011.pl is started 7869 times output is finally identical to xargs one
#RJ                 time cat list.txt |while read line ; do perl ./check_norm_2011.pl --intfbdir=1  $line >> all_while.log ; done
}
