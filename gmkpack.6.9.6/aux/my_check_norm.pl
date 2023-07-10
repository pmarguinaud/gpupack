#!/usr/bin/perl  

use strict;
use warnings;
use FindBin qw ($Bin);
use lib $Bin;

#RJ: explicitly import name objects
#RJ use Fortran90_stuff;
use Fortran90_stuff qw( setup_parse $name $nest_par $study_called $f90s_FORGIVE_ME
                        slurpfile slurp_fpp slurp_split slurp2array
                        readfile expcont study process_include_files_v2
                        parse_prog_unit getvars find_unused_vars
                        doctor_viol get_calls_inc
                        );
use Data::Dumper qw(Dumper);

$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

#RJ: extra module to handle buffering of stdout and stderr
use IO::Handle;
#RJ: force stderr to stdout to get cleaner logs
unless ($ENV{IOSYNC_OFF}) {
  open (STDERR, '>&', STDOUT);
  STDOUT->autoflush(1);
  STDERR->autoflush(1);
}

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

{
  my (@files);
  (@files) = @ARGV;
  &setup_parse();
  
#RJ: activate FORGIVE_ME, currently just not to bailout on undeclared variables
  our ${f90s_FORGIVE_ME}=1;

  our $study_called;

#RJ: tool setup part
#RJ   my $null='';
#  my $locintfbldir=$ENV{LOC_INTFBDIR} or die "LOC_INTFBDIR not defined ";
#  my $intfbldir=$ENV{INTFBDIR} or die "INTFBDIR not defined ";
  our $w_check_off;
  $w_check_off=$ENV{WCHECK_OFF} or $w_check_off=0;
  our $i_check_off;
  $i_check_off=$ENV{ICHECK_OFF} or $i_check_off=0;
  my $supress;
  $supress=$ENV{SUPRESS_MESSAGE} or $supress='';
  our @supress=();
  @supress=split(':',$supress) if $supress;

#RJ: actual loop through files
  for (@files) {
    my (@inc_statements,@interface_block);
    my (%prog_info,@line_hash);
 # Read in lines from file
    my $fname = $_;
    next unless ($fname=~/\.(?:F90|F95|F03|F08|f90|f95|f03|f08)$/);
    next unless ( -f $fname);
    print "Norms checker diagnostic messages: file $fname \n";

#RJ: changing to a bit faster read function
#RJ: slurp version, just dump file to string, faster by a few seconds and allows filters
#RJ     my @lines = &readfile($fname);
    my $slurp;
    &slurpfile(\$fname,\$slurp);

#RJ: just because of NEW_MAGICS define in src/odb/lib/Magics_dummy.F90, should be removed there
    &slurp_fpp(\$slurp,\$cpp_def,\$cpp_undef);

#RJ: try to call study and check norms on separate units, less false positives
    my @splitted_units;
    &slurp_split(\$slurp,\$fname,\@splitted_units);

    foreach my $ii (0..$#splitted_units) {
      my $cur_fname=$fname;
      if($ii>0) {
        $cur_fname=~s/(\.F[0-9][0-9])$/__SPLIT$ii$1/;
        print "    Norms checker diagnostic messages for splitted file $cur_fname \n";
      }
      my (%prog_info);
      my @statements=();
      my @lines=();
      &slurp2array(\$splitted_units[$ii],\@lines);

      &expcont(\@lines,\@statements);

      $study_called=0;
      &study(\@statements,\%prog_info);

#RJ: original process_include_files might have @lines scope bug, fixed in _v2
#RJ       &process_include_files(\@statements,\%prog_info,\@inc_statements);
      &process_include_files_v2(\@statements,\%prog_info,\@inc_statements);


#RJ: perform FPP checks
      &check_cpp_simple(\@statements,\$cur_fname);

#RJ: check simple
      &simple_checks(\@statements,\%prog_info);

#RJ: check variables
      &check_variables(\@statements,\%prog_info,\$cur_fname);

#RJ: check line rules
      &check_line_rules(\@lines,\$cur_fname);

#RJ: check interfaces
      &check_interface_blocks(\@statements,\$cur_fname);

#RJ: useless
#RJ     unless($prog_info{is_module}) {
#RJ     }
    }
  }
}

#########################
#RJ: local subs

sub eq_array {
    my ($ra, $rb) = @_;
    return 0 unless $#$ra == $#$rb;
    for my $i (0..$#$ra) {
      return 0 unless $ra->[$i] eq $rb->[$i];
    }
    return 1;
}
sub simple_checks{
  my($statements,$prog_info) = @_;
  our($name,$nest_par);
  my(@pu_args,%pu_args,$unit_name,$uc_un);
  my %relops = ('EQ' => '==' , 'NE' => '/=' , 'LT' => '<' , 'LE' => '<=' ,
                'GT' => '>'  , 'GE' => '>=' );
  my $null='';
  my $implicit_none=0;
  my $save=0;
  my $save_hlp=0;
  my $hook_module=0;
  my $prev_exec='';
  foreach my $href (@$statements) {
    $_=$href->{statement};
    my $content=$href->{content};
    my $decl=$href->{decl};
    my $exec=$href->{exec};
    s/\!.*\n/\n/g unless ($content eq 'comment');
    if($content eq 'FUNCTION' or $content eq 'SUBROUTINE' or
       $content eq 'PROGRAM'){ # Need name of routine and args
      @pu_args=();
      %pu_args=();
      my $dum=&parse_prog_unit(\$unit_name,\@pu_args);
      $uc_un=$unit_name;
      $uc_un=$$prog_info{module_name}.':'.$unit_name
        if($$prog_info{is_module});
      $uc_un=$$prog_info{unit_name}[0].':'.$unit_name
        if($$prog_info{has_contain} and $unit_name ne $$prog_info{unit_name}[0]);

      $uc_un=uc($uc_un);
      for(@pu_args) {
        $_=uc($_);
        $pu_args{$_}++;
      }
      my $no_args=scalar @pu_args;
      if($no_args > 50) {
        my $emph='';
        $emph='!!!' if $no_args > 60;
        &outviol(\$null,'I',"CTRL(10) : Routine $unit_name has $no_args $emph arguments ".
                 "compared to the recommended maximum of 50");
      }
    }
    if($decl or $exec) {
      if(/\t/) {
        &outviol(\$href,'S','NORM(02) : TAB characters not allowed');
      }
    }
    if($content eq 'comment') {
      if(/^s*!\s*\n$/) {
        &outviol(\$href,'I','PRES(07) : Empty lines should be left empty, remove !');
      }
    }
    if($exec) {
      if($content eq 'ENDDO') {
#RJ         if(/\bEND DO\b/i){
        unless(/\bENDDO\b/i){
          &outviol(\$href,'W','ENDDO preferred to END DO');
        }
      }
      elsif($content eq 'ENDIF') {
#RJ         if(/\bEND IF\b/i){
        unless(/\bENDIF\b/i){
          &outviol(\$href,'W','ENDIF preferred to END IF');
        }
      }
      elsif($content eq 'ENDWHERE') {
#RJ         if(/\bEND WHERE\b/i){
        unless(/\bENDWHERE\b/i){
#RJ           &outviol(\$href,'W','ENDWHERE preferred to ENDWHERE');
          &outviol(\$href,'W','ENDWHERE preferred to END WHERE');
        }
      }
      elsif($content eq 'ELSEIF') {
#RJ         if(/\bELSE IF\b/i){
        unless(/\bELSEIF\b/i){
          &outviol(\$href,'W','ELSEIF preferred to ELSE IF');
        }
      }

    }
#RJ allow fused endsmth, also program
#RJ     if($content=~/^END (SUBROUTINE|MODULE|FUNCTION)/ ) {
#RJ       unless(/^\s*END +(SUBROUTINE|MODULE|FUNCTION) +$name/i){
    if($content=~/^END[ ]?+(SUBROUTINE|MODULE|FUNCTION|PROGRAM)/ ) {
      unless(/^\s*END[ ]*+(SUBROUTINE|MODULE|FUNCTION|PROGRAM)[ ]++$name/i){
        &outviol(\$href,'W','PRES(04) : The ending statement of a program unit'.
                 ' should repeat its name');
      }
    }
    if($content eq 'RETURN') {
      if($exec == 3) {   # $exec == 3 means last executable statem
        &outviol(\$href,'S','CTRL(03) : RETURN at end of procedure'.
                 ' meaningless, please remove');
      }
      else {
        &outviol(\$href,'I','CTRL(03) : Alternate returns to be avoided');
      }
    }
    if($content eq 'IF') {
      if($href->{content2} eq 'RETURN') {
        &outviol(\$href,'I','CTRL(03) : Alternate returns to be avoided');
      }
    }

    $implicit_none=1 if($content eq 'IMPLICIT NONE');
    $save=1 if($content eq 'SAVE');
    if($$prog_info{is_module}) {
      if(! $href->{in_contain}) {
        $save_hlp++ if($decl == 2);
      }
    }

    if($content eq 'DIMENSION') {
      &outviol(\$href,'S','NORM(05) : The dimension should be specified '.
               'as an attribute');
    }
    if($decl == 2) {
      unless(/::/) {
        &outviol(\$href,'S','NORM(06) : The "::" notation should always '.
                 'be used in declarations');
      }
      if($content eq 'INTEGER' or $content eq 'REAL') {
        if( ! /KIND\s*=/i) {
          &outviol(\$href,'S','NORM(07) : Integers and reals should '.
                   'be declared with explicit kind');
        }
      }

    }
    if ($decl == 4) {
      unless(/^\s*USE\s*$name\s*,\s*ONLY\s*:/i){
        &outviol(\$href,'W','NORM(09) : USE without ONLY');
      }
    }
    if ($content eq 'SUBROUTINE') {
      if(/^\s*&*\s*,/m) {
        &outviol(\$href,'W','PRES(21) : Break lines with comma at end of line');
      }
    }
    if ($content eq 'CALL' ) {
      if(/^\s*&*\s*,/m) {
        &outviol(\$href,'W','PRES(22) : Break lines with comma at end of line');
      }
    }
    if($content eq 'GOTO' or ($content eq 'IF' and $href->{content2} eq 'GOTO')) {
      &outviol(\$href,'W','NORM(13) : GOTO should not be used, use other construct');
    }
    if ($content eq 'COMMON') {
      &outviol(\$href,'S','NORM(15) : COMMON should not be used, use modules');
    }
    if ($content eq 'EQUIVALENCE') {
      &outviol(\$href,'W','NORM(16) : EQUIVALENCE should not be used, use POINTER');
    }
    if ($content eq 'COMPLEX') {
      &outviol(\$href,'S','NORM(17) : COMPLEX type should not be used');
    }
    if ($content eq 'CHARACTER') {
      if(/^\s*CHARACTER *\*/i) {
      &outviol(\$href,'W','NORM(18) : Use CHARACTER(LEN=..) for declaring'.
               ' character variables');
      }
    }
    if ($content eq 'DO') {
      if(/^\s*DO +\d+/i) {
        &outviol(\$href,'S','NORM(20) : Use the DO ... ENDDO construct');
      }
    }
    if ($exec) {
#RJ       for my $relop (keys(%relops)) {
      for my $relop (sort(keys(%relops))) {
        if(/\.$relop\./i) {
          &outviol(\$href,'W',"NORM(24) : Relational operator $relops{$relop}".
                   ' preferred to .'."$relop".'.');
        }
      }
    }
# Checks related to DR_HOOK
    if ($exec == 2) {
      &doctor_call($_,'0',$uc_un,\$href);
    }
    elsif($exec == 3 ) {
      &doctor_call($_,'1',$uc_un,\$href);
    }
    if($content eq 'RETURN') {
      unless($prev_exec=~/CALL\s+DR_HOOK/i){
        &outviol(\$href,'S','CTRL(20) : RETURN without calling DR_HOOK '.
                 ' just before');
      }
      &doctor_call($prev_exec,'1',$uc_un,\$href);
    }
    if($content eq 'IF') {
      if($href->{content2} eq 'RETURN') {
        unless($prev_exec=~/CALL\s+DR_HOOK/i){
          &outviol(\$href,'S','CTRL(20) : RETURN without calling DR_HOOK '.
                   ' under same conditions just before');
        }
        my $temp_exec=$prev_exec;
        $temp_exec=~s/IF\s*$nest_par/IF(LHOOK)/i;
        &doctor_call($temp_exec,'1',$uc_un,\$href);
      }
    }
    if($exec) {
      if(/\bZHOOK_HANDLE\b/i) {
        unless(/CALL\s+DR_HOOK/i){
          &outviol(\$href,'S','CTRL(20) : Variable ZHOOK_HANDLE should only'.
                   ' be used as argument to DR_HOOK');
        }
      }
    }
    $prev_exec=$_ if($exec);

#Check related to MPL.... calls
    if($content eq 'CALL' ) {
      if(/^\s*CALL\s+MPL_/i) {
        if(/CALL\s+(MPL_ABORT|MPL_WRITE|MPL_READ|MPL_OPEN|MPL_CLOSE|MPL_INIT|MPL_GROUPS_CREATE|MPL_BUFFER_METHOD|MPL_IOINIT|MPL_CART_COORD)/i) {
# Don't worry
        }
        else{
          unless (/CDSTRING\s*=\s*['"]$unit_name.*["']/) {
            &outviol(\$href,'S','CTRL(27) : Calls to MPL_ routines should have the argument'.
                     ' CDSTRING=\'caller...\' where caller is the name of the calling routine');
          }
        }
      }
    }

    if($decl == 2) {
      $_=uc($_);
      s/\s//g;
      if(/^(.+)::(.+)$/){
        my $left=$1;
        my $right=$2;
        $_=$right;
        s/$nest_par//g;
        s/($name)\*\w+/$1/g;
        foreach my $arg (@pu_args) {
          if(/\b$arg\b/) {
            unless($href->{statement}=~/\bINTENT\b/i) {
              next if ($href->{statement}=~/Argument NOT used/);
              &outviol(\$href,'S','NORM(27) : Always specify INTENT attribute for'.
                       ' subroutine arguments');
            }
          }
        }
      }
      $_=$href->{statement};
      s/\!.*\n/\n/g unless ($content eq 'comment');
    }
##REK
  &macro_doc($_,\$href);
##REK
  }
  unless($implicit_none) {
    &outviol(\$null,'S','NORM(03) : IMPLICIT NONE missing');
  }
  if($$prog_info{is_module}) {
    unless($save) {
      if($save_hlp) {
        &outviol(\$null,'S','CTRL(05) : Use SAVE statement in module');
      }
    }
  }
}

#RJ: splitted from main
sub check_variables{
  my ($statements,$prog_info,$full_fname) = @_;
  my %vars=();
  my %use_vars=();
  my @unused_vars=();
  my @unused_use_vars=();
  my $null='';

  &getvars(\@$statements,\%$prog_info,\%vars,\%use_vars);

  &find_unused_vars(\@$statements,\%vars,\@unused_vars,
                    \%use_vars,\@unused_use_vars);

  for (@unused_vars) {
    &outviol(\'','W',"CCPT(04) : Local variable $_ declared but not used");
  }
  for (@unused_use_vars) {
    &outviol(\'','W',"CCPT(04) : Variable $_ found in USE $use_vars{$_}{module}".
             ", ONLY: ...  but variable not used");
  }

  my %doctor_viols=();
  &doctor_viol(\%vars,\%doctor_viols);
#RJ     foreach my $docviol (keys (%doctor_viols)){
  foreach my $docviol (sort(keys (%doctor_viols))){
    $doctor_viols{$docviol}=~/^(\w+)_/;
    my $prefix=$1;
    &outviol(\$null,'W',"NORM(10) : Naming convention violation: $docviol , ".
             'variable should have prefix letter(s) "'."$prefix".'"');
  }
}

#RJ: splitted from main
sub check_line_rules{
  my ($lines,$full_fname)=@_;

  my $i=0;
  my $prev=0;
  for (@$lines) {
    $i++;
    if ( length($_) > 132) {
      &outviol(\$_,'W',"PRES(32) : Line $i longer than 132 characters");
    }
    elsif( length($_) > 80) {
      &outviol(\$_,'I',"PRES(32) : Line $i longer than  80 characters");
    }
    if(! /^ *!.*$/ and $prev) {
#RJ         unless(/^( *)&/) {
      unless(/^[\s]*+[\&]/) {
        &outviol(\$_,'W','NORM(21) : Continuation lines should start with &');
      }
    }
    s/^( *)&(.*)$/$1$2/ if(/^ *&/);
    if( !/^ *!.*$/ && /^.+&(?: *!.*)* *$/) {
      $prev=1;
    }
    elsif(! /^ *!.*$/) {
      $prev=0;
    }
  }
}

#RJ: splitted from main
sub check_interface_blocks{
  my ($statements,$full_fname) = @_;

  my $null='';
  my (%calls,%intfb);
  &get_calls_inc(\@$statements,\%calls,\%intfb);
#    print Dumper(\%calls);
#    print Dumper(\%intfb);
#RJ     foreach my $intf (keys (%intfb)){
  foreach my $intf (sort(keys (%intfb))){
    next if ($intfb{$intf} == 2);
    unless ($calls{$intf}) {
      outviol(\$null,'W',"Unnecessary interface block for $intf, no call ");
    }
  }
}

sub outviol {
  my($href,$severity,$message)=@_;
  our $i_check_off;
  our $w_check_off;
  our @supress;
  return if( $i_check_off and $severity eq 'I');
  return if( $w_check_off and $severity eq 'W');
  for my $skip (@supress) {
#    print "SKIP $skip \n";
    my ($cat,$numb);
    ($cat,$numb)=split('-',$skip);
    return if($message=~/\b$cat\($numb\)/);
  }
  if(ref($$href) eq "HASH") {
    print "-> $$href->{statement}";
  }
  elsif($$href){
    print "-> $$href";
  }
  print "($severity) $message \n";
}

sub doctor_call{
  my($statement,$onoff,$uc_un,$href)=@_;
  my $text='first';
  $text='last' if ($onoff);
  if($statement=~/^\s*IF\s*\(\s*LHOOK\s*\)\s*CALL\s+DR_HOOK/i) {
    if($statement=~
       /^\s*IF\s*\(\s*LHOOK\s*\)\s*CALL\s+DR_HOOK\s*\(\'$uc_un\',$onoff,ZHOOK_HANDLE\b/){
      #All is well
    }
    elsif($statement=~
      /^\s*IF\s*\(\s*LHOOK\s*\)\s*CALL\s+DR_HOOK\s*\(\'$uc_un\',$onoff\b/){
      &outviol($href,'S','CTRL(20) : Third argument of call to DR_HOOK'.
               ' should be ZHOOK_HANDLE');
    }
    elsif($statement=~/^\s*IF\s*\(\s*LHOOK\s*\)\s*CALL\s+DR_HOOK\s*\(\'$uc_un\'/){
      &outviol($href,'S','CTRL(20) : Second argument of call to DR_HOOK'.
               " should be $onoff");
    }
    elsif($statement=~/^\s*IF\s*\(\s*LHOOK\s*\)\s*CALL\s+DR_HOOK\s*\(/){
      &outviol($href,'S','CTRL(20) : First argument of call to DR_HOOK'.
               ' should be unit name in uppercase (no blanks)');
    }
  }
  else{
    &outviol($href,'S',"CTRL(20) : The $text executable statement is".
             ' NOT a proper call to DR_HOOK');
  }
}

sub macro_doc{
 my ($statement,$href)=@_;
 if($statement=~/^\s*#ifdef\s+DOC/) {
   &outviol($href,'I','CTRL(35) : Macro DOC is old-fashionned');
 }
 if($statement=~/^\s*#ifdef\s+doc/) {
   &outviol($href,'I','CTRL(35) : Macro doc is old-fashionned');
 }
}

#RJ: cpp checks: simple
sub check_cpp_simple{
 my($statements,$full_fname) = @_;
 my $statement='';
 my $type='';
 my $null='';
 my $def_list='';
# my $null='';

 foreach my $href (@$statements) {
  if ($href->{content}=~/^cpp/){
    &cpp_simple(\$href,\$def_list,$full_fname);
  }
  elsif($href->{content} eq 'include'){
#RJ: still check if correct format
    &cpp_simple(\$href,\$def_list,$full_fname);
    if(exists $href->{inc_statm}) {
      my $incs=$href->{inc_statm};
      foreach my $href2 (@$incs) {
        if(($href2->{content} eq 'cpp') || ($href2->{content} eq 'include')){
          my $inc_name=$$full_fname;
          if(exists $href->{inc_info}) {
            $inc_name=$href->{inc_info}{'inc_name'};
          } 
          &cpp_simple(\$href2,\$def_list,\$inc_name);
        }
      }
    }
  }
  else {
    if($href->{statement}=~/[\\][\s]*+$/) {
      &outviol(\$href,'W','FPP(37) : Posible issue with cpp, '."'\\' symbol at end of line");
    }
  }
 }
 #RJ: check if all defines are undefined at the end
 while ($def_list=~/(\b[\w]++\b)/g){
  &outviol(\$null,'S','FPP(31) : Missing CPP undef for define '."$1");
 }
}

#RJ: main cpp checker
sub cpp_simple{
  my($href,$def_list,$full_fname) = @_;
  my $statement='';
  my $type='';

#warn Dumper($href);

  $statement=$$href->{statement};
  if($statement=~/^[ ]*+[\#]/) {
#   warn "zzz: $statement";
    if($statement=~/^[ ]++[\#]/) {
      &outviol($href,'S','FPP(1) : Whitespaces before CPP directve');
    }
    if($statement=~/^[ ]*+[\#][ ]/){
      &outviol($href,'S','FPP(2) : Whitespace after CPP directive start symbol \'#\'');
    }
    if($statement=~/^[ ]*+[\#][ ]*+[\w]++[ ][ ]++[\w]/){
      &outviol($href,'S','FPP(3) : Extra whitespace after CPP directive type');
    }
#RJ: ech, lets look through fingers on this
#    if($statement=~/[ ][\r\n]*$/){
#      &outviol($href,'W','FPP(4) : Trailing whitespace after CPP directive');
#    }
    if($statement=~/[\t\f]/){
      &outviol($href,'S','FPP(5) : TAB detected in CPP directive');
    }
    if($statement=~/([^\!\#\w\ ()\&\|\:\;\,\.\'\"\<\>\*\/\+\-\^\=\r\n\@\%]++)/){
      &outviol($href,'S','FPP(6) : Characters outside [A-Z][a-z][_][ ][&|^():;,.><"\'+-*/=][@][%] detected: '."\'$1\'");
    }
    if($statement=~/([\;])/){
      &outviol($href,'I','FPP(7) : Possible multiline CPP macro detected');
    }
    
#RJ: check of formats, lets be very unforgiving in fortran ;-)
    if($statement=~/^[ ]*+[\#][ ]*+([\w]++)/){
      $type=$1;
      if($type eq 'include'){
        unless($statement=~/^[\#]include[ ]++"[\w\.]++"[ \r\n]*+$/){
          &outviol($href,'S','FPP(11) : Unstrict format for CPP include directive');
        }
      }
      elsif($type eq 'define'){
        if($statement=~/^[\#]define[ ]++([\w]++)/){
          $$def_list.=','.$1
        }
        unless($statement=~/^[\#]define[ ]++[\w]++(?:[(][\w]++[)])?+/){
          &outviol($href,'S','FPP(12) : Unstrict format for CPP define directive');
        }
      }
      elsif($type eq 'undef'){
        if($statement=~/^[\#]undef[ ]++([\w]++)/){
          $$def_list=~s/[,]$1\b//g;
        }
        unless($statement=~/^[\#]undef[ ]++[\w]++[ \r\n]*+$/){
          &outviol($href,'S','FPP(13) : Unstrict format for CPP undef directive');
        }
      }
      elsif($type eq 'ifdef'){
        unless($statement=~/^[\#]ifdef[ ]++[\w]++[ \r\n]*+$/){
          &outviol($href,'S','FPP(14) : Unstrict format for CPP ifdef directive');
        }
      }
      elsif($type eq 'ifndef'){
        unless($statement=~/^[\#]ifndef[ ]++[\w]++[ \r\n]*+$/){
          &outviol($href,'S','FPP(15) : Unstrict format for CPP ifndef directive');
        }
      }
      elsif($type eq 'else'){
        unless($statement=~/^[\#]else[ \r\n]*+$/){
          &outviol($href,'S','FPP(16) : Junk after CPP else directive');
        }
      }
      elsif($type eq 'endif'){
        unless($statement=~/^[\#]endif[ \r\n]*+$/){
          &outviol($href,'S','FPP(17) : Junk after CPP endif directive');
        }
      }
      elsif($type=~/(?:el)?if\b/){
        if($statement=~/^[\#]if[ ]++[\!]defined[(][\w]++[)][ \r\n]*$/){
          &outviol($href,'I','FPP(36) : Safer to use simple CPP ifndef directive');
        }
        unless($statement=~/^[\#](?:el)?if[ ](?:[\w]++(?:[ ]*+[<>=!]++[ ]*+[\w]++)?+|(?:[!])?defined[ ]?[(][\w]++[)])(?:[ ]*+(?:[\&][\&]|[\|][\|])[ ]*+(?:(?:[!])?defined[ ]?[(][\w]++[)]|[\w]++[ ]*+[<>=!]++[ ]*+[\w]++)*+)*+[ \r\n]*+$/){
          &outviol($href,'S','FPP(18) : Unstrict format for CPP if directive');
        }
        if($statement=~/[&][&]/){
          if($statement=~/[|][|]/){
            &outviol($href,'W','FPP(33) : Avoid mixed logicals in CPP logic within fortran sources');
          }
       }
     }
     elsif($type eq 'error'){
       #do not check logic here, it's error
     }
     else{
       &outviol($href,'W','FPP(8) : Unknown CPP directive type');
     }
    }else{
      &outviol($href,'S','FPP(9) : Failed to get CPP directive type');
    }
  }
}
