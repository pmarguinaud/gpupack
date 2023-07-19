package Fortran90_stuff;
use strict;
use warnings;
use Exporter;
use SelfLoader;


use Data::Dumper qw(Dumper);
use Digest::SHA  qw(sha1_base64);
#RJ: much faster
die "Bailout[F90_STUFF]: perl version - $] less than v5.10" unless($] >= 5.010);

$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

#RJ: moving all to export_ok, but for now restore old behaviour
our $VERSION    = '1.1';
our @ISA        = qw(Exporter SelfLoader);
#RJ: until explicit imports in tools disabled
#our @EXPORT     = qw();
#our @EXPORT_OK  = qw( study setup_parse pre_tidy remove_macro expcont
our @EXPORT     = qw( study setup_parse pre_tidy remove_macro expcont
                      process_include_files process_include_files_v2
                      tidy tidy_decl getvars
                      find_unused_vars remove_unused_vars doctor_viol doctor_viol_v2
                      fix_doctor_viol various cont_lines f90_indent
                      writefile readfile create_interface_block
                      add_interface_blocks change_var_names insert_hook
                      remake_arg_decl remove_some_comments
                      parse_prog_unit parse_prog_unit_v2
                      get_calls_inc get_calls_inc_v2 getcalls
                      cont_lines_surfex parse_prog_unit_surfex
                      insert_use_modi create_interface_module
                      slurpfile slurp2file slurp2array array2slurp
                      slurp_split slurp_fpp slurp_defpp slurp_inc slurp_deinc
                      slurp_tidy slurp_depends slurp_intfb slurp_modi
                      $study_called $name $nest_par $f90s_FORGIVE_ME $f90s_VERBOSITY );

#==========================================================================

sub setup_parse {
# Set up some "global" variables that helps with parsing statements
  our $nest_par;
#RJ: nesting detection, faster version by half
#RJ   if using perl version pre 5.10 change to previous $nest_par
#RJ   however old one fails to get triple nested stuff and very slows study
#RJ   $nest_par = qr{\((?:(?>[^()]+)|(??{$nest_par}))*\)}; #Camel p214
  $nest_par = qr{(?:([(](?:[^()]++|(?-1))*+[)]))};
#RJ   our $name='[a-zA-Z]\w*';
  our $name='(?:[a-zA-Z][\w]*+)';
#RJ   our $digit_string='\d+';
  our $digit_string='(?:[\d]++)';
  our $type_name=$name;
  our $specification_expr='(?:'.$name.'|'.$digit_string.')'; # Simplification
#RJ: simplify, move star detection to "len=" one
#RJ   our $type_param_value='(?:\*|'.$specification_expr.')';
  our $type_param_value='(?:'.$specification_expr.')';
#RJ: also detect "*8" ones, add '(',[)] for 'len=' one
#RJ   our $char_selector='LEN *= *'.$type_param_value; # Simplification
  our $char_selector ='(?:';
      $char_selector.= '(?:';
      $char_selector.=  '(?:[(][ ]*+LEN[ ]*+[\=][ ]*+'.$type_param_value.'[ ]*+[)])';
#RJ: extra dangerous case at lfistress.F90 'CHARACTER (3) FUNCTION ACT ()'
      $char_selector.=  '|(?:[(][ ]*+'.$type_param_value.'[ ]*+[)])';
      $char_selector.=  '|(?:[\*]'.$type_param_value.')';
      $char_selector.= ')';
      $char_selector.=')';
#RJ: adding number class
#RJ   our $kind_selector='\( *KIND *= *'.$name.' *\)';    # Simplification
  our $kind_selector ='(?:';
      $kind_selector.= '(?:';
      $kind_selector.=  '(?:[(][ ]*+KIND[ ]*+[\=][ ]*+'.$type_param_value.'[ ]*+[)])';
      $kind_selector.=  '|(?:[\*]'.$type_param_value.')';
      $kind_selector.= ')';
      $kind_selector.=')';
#RJ   our $type_spec = 'INTEGER *(?:'.$kind_selector.')?';
#RJ       $type_spec.='|REAL *(?:'.$kind_selector.')?';
#RJ       $type_spec.='|DOUBLE PRECISION|COMPLEX *(?:'.$kind_selector.')?';
#RJ       $type_spec.='|CHARACTER *'.$char_selector;
#RJ       $type_spec.='|LOGICAL *(?:'.$kind_selector.')?';
#RJ       $type_spec.='|TYPE\s*\(\s*'.$type_name.'\s*\)';
  our $type_spec ='(?:';
      $type_spec.= '(?:(?:INTEGER|REAL|LOGICAL|DOUBLE PRECISION|COMPLEX)[\s]*+(?:'.$kind_selector.')?)';
      $type_spec.= '|(?:CHARACTER[\s]*+(?:'.$char_selector.')?)';
      $type_spec.= '|(?:TYPE[\s]*+[(][\s]*+'.$type_name.'[\s]*+[)])';
      $type_spec.=')';
#RJ: special flag to try to recover, by default 'unforgivable'
  our ${f90s_FORGIVE_ME}=0;
#RJ: special flag to control verbosity, by default 2, from none=0 to very verbose=5
  our ${f90s_VERBOSITY}=2;
}

#RJ: SelfLoader feature to speed up Fortran90_stuff.pm compilation with 'on demand' mode
#RJ: for development should be commented out, for production should be enabled, simply faster
#__DATA__
__DATA__

#==========================================================================
sub slurp_split{
#RJ: fastest yet still most permissive, best efforts unit splitter I could write in short time
#RJ: doesn't care about cpp prototyping, not considers plain END as end unit.
#RJ: manages to extract 8927 units from single catted harmonie F90 sources file (~90mb) in just 4m5s ;P
#RJ:   provided if COMBI runtines are editted to have needed END UNIT(unended CONTAINS cases are hard..)
my ($slurp,$fname,$splitted)=@_;
$$slurp =~ s/^([ ]*)module[ ]+(subroutine|function)\b/"$1 $2"/iemg;
our (${f90s_VERBOSITY});
my @stack;
my $pos_multi=0;
#RJ-debug my $have_contain=0;
my $have_cpp=0;
my $cur_regex='';
my $cur_unit='';
my $cur_name='';
my $in_contains=0;
my $in_unit='';
my $in_unit_start=0;
my $unit_count=0;
my $skip_till=-1;
#RJ: add helper marker to the start
my $dump="\n\@\@\@\n".$$slurp;
{
  local $/;

#RJ: end[ ]?interface is mandatory, thus explointing
#RJ: markup/blacklist inteface blocks with \x07 "bell character"
  $dump=~ s%[\n]([ ]*+(?:end)?+[ \t]*+(?:interface))\b%\n\x11$1%ig;
  $dump=~ s%[\n]([\x11][^\x11]++[\x11])%my $t="\n".$1;$t=~s/[\n][\x11]?/\n\x07/g;$t%eg;

#RJ: assume end[ ]?type is mandatory when has methods, thus exploint masking with "bell characters"
#RJ: is type definitions legal inside interface blocks or vise versa? might have issues everywhere
#  $dump=~ s%[\n]([ ]*+(?:type)[ \t]*+::|(?:end)[ \t]*+(?:type\b))%\n\x11$1%ig;
  $dump=~ s%[\n]([ ]*+(?:type)[ \t]*+(?:[,][ \t]*+(?:(?:extends|bind)[ \t]*+[(][a-z0-9_ ]++[)]|[a-z]++)[ \t]*+)*+::|(?:end)[ \t]*+(?:type\b))%\n\x11$1%ig;
  $dump=~ s%[\n]([\x11][^\x11]++[\x11])%my $t="\n".$1;$t=~s/[\n][\x11]?/\n\x07/g;$t%eg;

  if($dump=~s/[\r][\n]?+/\n/g) {
    if(${f90s_VERBOSITY}>=4) {
      warn "Warning[SPLIT_CR]: $$fname";
    }
  }
  if($dump=~s/[\;]/\;\x08/g) {
    $pos_multi=1;
  }
  if($dump=~/[\n][\#]endif/) {
    $have_cpp=1;
#RJ-debug     warn "Warning[CPP]: $$fname";
  }

#RJ-debug   if ($dump=~/(?:^|[\n])([ \t]*+end[ \t]*+(?:[\!][^\n]*+))/i) {
#RJ-debug     die "Failed: plain end detected";
#RJ-debug   }

#  while($dump=~s/([\n\x08])((?:[^\n\!\x08\x0c]++\b(?:[ \t]++)*+)*?\b(?:end[ \t]*+)?(?:subroutine|function|module|program|contains|interface)\b[^\n]*+)/$1\x0c$2/i) {
#  while($dump=~s/([\n\x08])((?:[^\n\!\x08\x0c]++\b)*?\b(?:end[ \t]*+)?(?:subroutine|function|module|program|contains|interface)\b[^\n]*+)/$1\x0c$2/i) {
#  while($dump=~s/([\n\x08])([ \t]*+(?:[^\n\!\x08\x0c]++\b)*?\b(?:end[ \t]*+)?(?:subroutine|function|module|program|contains|interface)\b[^\n]*+)/$1\x0c$2/i) {
#  while($dump=~s/([\n\x08])([ \t]*+\b(?:END[ \t]*+|(?:RECURSIVE[ \t]++|ELEMENTAL[ \t]++|PURE[ \t]++)*+)?+(?:subroutine|function|module|program|contains|interface)\b[^\n]*+)/$1\x0c$2/i) {
#  while($dump=~s/([\n\x08])([ \t]*+\b(?:end[ \t]*+\b(?:subroutine|function|module|program|interface)\b|\b(?:contains|subroutine|function|module|program|interface)\b|(?:\b(?:recursive[ \t]++|elemental[ \t]++|pure[ \t]++)*+\b(?:subroutine|function)\b)|(?:\b(?:integer|real|character|logical|type)\b[^\n\!\x08\x0c]*?\bfunction\b))\b[^\n\x08\x0c]*+)/$1\x0c$2/i) {
#good,slow  while($dump=~s/([\n\x08])([ \t]*+\b(?:end[ \t]*+(?:subroutine|function|module|program)\b|\b(?:contains|subroutine|function|module|program)\b|(?:\b(?:recursive[ \t]++|elemental[ \t]++|pure[ \t]++)*+\b(?:subroutine|function)\b)|(?:\b(?:integer|real|character|logical|type)\b[^\n\!\x08\x0c]*?\bfunction\b))\b[^\n\x08\x0c]*+)/$1\x0c$2/i) {
#better but still slow   while($dump=~s/([\n\x08])([ \t]*+\b(?:end[ \t]*+(?:subroutine|function|module|program)\b|(?:contains|subroutine|function|module|program)\b|(?:(?:recursive[ \t]++|elemental[ \t]++|pure[ \t]++)++(?:subroutine|function)\b)|(?:(?:integer|real|character|logical|type)\b[^\n\!\x08\x0c]*?\bfunction\b))\b[^\n\x08\x0c(]*+)/$1\x0c$2/i) {
#    push(@stack,"$2");
#  }
#best ;) overhead is just 4.7s for whole bunch of harmonie F90 sources (7869), warning note the 'e' modifier
  $dump=~s/([\n\x08])([ \t]*+\b(?:end[ \t]*+(?:subroutine|function|module|program)\b|(?:contains|subroutine|function|module|program)\b|(?:(?:recursive[ \t]++|elemental[ \t]++|pure[ \t]++)++(?:subroutine|function)\b)|(?:(?:integer|real|character|logical|type)\b[^\n\!\x08\x0c]*?\bfunction\b))\b[^\n\x08\x0c(]*+)/push(@stack,"$2");"$1\x0c$2"/ieg;

#warn "qqq-stack:\n".Dumper(@stack);
#warn "stack:\n".Dumper(@stack);

#RJ-debug   for my $ttt (@stack) {
#RJ-debug #  warn $ttt;
#RJ-debug     if($ttt=~/^[ \t]*+contains\b/i) {$have_contain=1; warn "Warning[CONTAINS]: $$fname";}
#RJ-debug #  if($ttt=~/^[ \t]*+(?!end)[^\n\!\x08\x0c]*?\b(?:subroutine|function|module|program)\b/i) {$unit_count+=1;}
#RJ-debug   }
#RJ-debug #warn Dumper($dump);

#  $cur_regex='^';
#  for my $ttt (@stack) {

  foreach my $ii (0..$#stack) {
    if($skip_till>$ii){
#      warn "skip_till=$skip_till, ii=$ii";
      $cur_regex.='[^\x0c]*+[\x0c]';
#      $skip_till=-1;
    }
    else {
#    if($skip_till==$ii){
#      $cur_regex.='[^\x0c]*+[\x0c][^\n]*+';
#      last;
#    }
      my $ttt=$stack[$ii];
#      warn "ttt=$ttt";
#      warn "cur_regex: $cur_regex";
      if($in_contains==0) {
        if($ttt=~/^[ \t]*+(?!end)[^\n\!\x08\x0c]*?\b(subroutine|function|module|program)\b(?:[ ]++([\w]++\b))?+/i) {
 #         warn "_1_start $1 $2";
          $cur_unit=$1;
          $cur_name='';
          if(defined($2)) {
          $cur_name=$2;
          }
          $unit_count+=1;
          unless($cur_regex=~/^$/) {
            if(${f90s_VERBOSITY}>=2) {
              warn "Warning[SPLIT]: implicit cut for unit '$cur_unit $cur_name' in $$fname\n";
            }
            $cur_regex.='[^\x0c]*+';
            if($dump=~s/($cur_regex)//) {
              my $cut=$1;
              $cut=~s/^[\n][\@][\@][\@][\n]//;
              $cut=~s/[\x07\x08\x0b\x0c]//g;
 #             warn "qqq: push1, count=".$#$splitted;
              push(@$splitted,$cut);
 #             warn "qqq-after: push1, count=".$#$splitted;
              $cur_regex='';
            }
            else { die "Bailout[SPLIT]: failed to cut for regex - $cur_regex";}
          }
          $cur_regex='^[^\x0c]*+[\x0c]';#.qr($ttt);
          if($cur_name ne '') {
temp:       foreach my $jj ($ii+1..$#stack){
              if($stack[$jj]=~/^[ \t]*+(?:end)[ \t]*+(?:$cur_unit)[ \t]++(?:$cur_name)\b/i){
 #               warn "found end $cur_unit $cur_name";
                $skip_till=$jj;
                last temp;
              }
            }
          }
          if($ii == $#stack) {
            if($#stack>0) {
              if(${f90s_VERBOSITY}>=2) {
                warn "Warning[SPLIT]: implicit ending cut for unit '$cur_unit $cur_name' in $$fname\n";
              }
            }
            $cur_regex.='[^\x0c]*+$';
            if($dump=~s/($cur_regex)//) {
              my $cut=$1;
              $cut=~s/^[\n][\@][\@][\@][\n]//;
              $cut=~s/[\x07\x08\x0b\x0c]//g;
 #             warn "qqq: push2, count=".$#$splitted;
              push(@$splitted,$cut);
 #             warn "qqq: push2, count=".$#$splitted;
              $cur_regex='';
            }
            else { die "Bailout[SPLIT]: failed to cut for regex - $cur_regex";}
          }
        }
        elsif($ttt=~/^[ \t]*+(?:end)[ \t]*+(subroutine|function|module|program)\b(?:[ \t]++([\w]++)\b)?+/i){
 #       warn "_1_end $1 $2";
          my $uuu=$1;
          my $vvv='';
          if(defined($2)) {
            $vvv=$2;
          }
          if($cur_unit=~/^$uuu$/i) {
            $cur_regex.='[^\x0c]*+[\x0c][^\n\x08]*+';#.qr($ttt);
            if($ii == $#stack) {
              $cur_regex.='[^\x0c]*+$';
            }
 #           warn "before dump\n".$dump;
            if($dump=~s/($cur_regex)//) {
              my $cut=$1;
              $cut=~s/^[\n][\@][\@][\@][\n]//;
              $cut=~s/[\x07\x08\x0b\x0c]//g;
 #             warn "qqq: push3, count=".$#$splitted;
              push(@$splitted,$cut);
 #             warn "qqq: push3, count=".$#$splitted;
              $cur_regex='';
            }
            else { die "Bailout[SPLIT]: failed to cut for regex - $cur_regex"."\n".Dumper($dump)."zzzz";}
 #           warn "after dump\n".$dump;
            if($vvv ne '') {
 #             warn "vvv: $vvv";
              unless($cur_name=~/^$vvv$/i) {
                die "Bailout[SPLIT]: bad unit, expected 'end $cur_unit $cur_name', got 'end $uuu $vvv'";
              }
            }
          }
          else {die "Bailout[SPLIT]: bad unit, expected 'end $cur_unit', got 'end $uuu'"}
        }
        elsif($ttt=~/^[ \t]*+contains\b/i) {
          $in_unit=$cur_unit;
 #         warn "zzz: $in_unit";
          $cur_regex.='[^\x0c]*+[\x0c]';#.qr($ttt);
          $in_contains+=1;
          if($ii == $#stack) {
            $cur_regex.='[^\x0c]*+$';
            if($dump=~s/($cur_regex)//) {
              my $cut=$1;
              $cut=~s/^[\n][\@][\@][\@][\n]//;
              $cut=~s/[\x07\x08\x0b\x0c]//g;
 #             warn "qqq: push4, count=".$#$splitted;
              push(@$splitted,$cut);
              $cur_regex='';
            }
            else { die "Bailout[SPLIT]: failed to cut for regex - $cur_regex";}
          }
        }
        else { die "Bailout[SPLIT]: shouldn't get here for - $ttt"; }
      }
      elsif($in_contains==1) {
        if($ttt=~/^[ \t]*+(?!end)[^\n\!\x08\x0c]*?\b(subroutine|function|module|program)\b(?:[ ]++([\w]++\b))?+/i) {
 #         warn "_2_start $1";
          my $uuu=$1;
          my $vvv='';
          if(defined($2)) {
          $vvv=$2;
          }
          if($uuu=~/^(?:module|program)$/i) {
            if(${f90s_VERBOSITY}>=2) {
              warn "Warning[SPLIT]: implicit recovery from contains for unit '$uuu $vvv' cut in $$fname\n";
            }
            $cur_regex.='[^\x0c]*+';
            if($dump=~s/($cur_regex)//) {
              my $cut=$1;
              $cut=~s/^[\n][\@][\@][\@][\n]//;
              $cut=~s/[\x07\x08\x0b\x0c]//g;
 #             warn "qqq: push1, count=".$#$splitted;
              push(@$splitted,$cut);
 #             warn "qqq-after: push1, count=".$#$splitted;
              $cur_regex='';
            }
            else {
              die "Bailout[SPLIT]: failed to cut for regex - $cur_regex";
            }
#RJ: restore level one stuff
            $in_unit_start=0;
            $in_contains=0;
            $cur_unit=$uuu;
            $cur_name=$vvv;
            $cur_regex='^[^\x0c]*+[\x0c]';#.qr($ttt);
            if($cur_name ne '') {
temp2:        foreach my $jj ($ii+1..$#stack){
                if($stack[$jj]=~/^[ \t]*+(?:end)[ \t]*+(?:$cur_unit)[ \t]++(?:$cur_name)\b/i){
 #                 warn "found end $cur_unit $cur_name";
                  $skip_till=$jj;
                  last temp2;
                }
              }
            }
          }
          else {
            $in_unit_start=1;
            $cur_regex.='[^\x0c]*+[\x0c]';#.qr($ttt);
            if($ii == $#stack) {
              $cur_regex.='[^\x0c]*+$';
              if($dump=~s/($cur_regex)//) {
                my $cut=$1;
                $cut=~s/^[\n][\@][\@][\@][\n]//;
                $cut=~s/[\x07\x08\x0b\x0c]//g;
 #               warn "qqq: push5, count=".$#$splitted;
                push(@$splitted,$cut);
                $cur_regex='';
              }
              else {
                die "Bailout[SPLIT]: failed to cut for regex - $cur_regex";
              }
            }
          }
        }
        elsif($ttt=~/^[ \t]*+(?:end)[ \t]*+(subroutine|function|module|program)\b/i){
 #         warn "_2_end $1 $in_unit_start";
          my $uuu=$1;
          if($in_unit_start==1) {
            $in_unit_start=0;
            $cur_regex.='[^\x0c]*+[\x0c][^\n\x08]*+';#.qr($ttt);
            if($ii == $#stack) {
              $cur_regex.='[^\x0c]*+$';
              if($dump=~s/($cur_regex)//) {
                my $cut=$1;
                $cut=~s/^[\n][\@][\@][\@][\n]//;
                $cut=~s/[\x07\x08\x0b\x0c]//g;
 #               warn "qqq: push6, count=".$#$splitted;
                push(@$splitted,$cut);
                $cur_regex='';
              }
              else { die "Bailout[SPLIT]: failed to cut for regex - $cur_regex";}
            }
          }
          elsif($in_unit_start==0) {
            if($in_unit=~/^$uuu$/i) {
              $cur_regex.='[^\x0c]*+[\x0c]';#.qr($ttt);
              $in_contains=0;
              if($ii == $#stack) {
                $cur_regex.='[^\x0c]*+$';
              }
              if($dump=~s/($cur_regex)//) {
                my $cut=$1;
                $cut=~s/^[\n][\@][\@][\@][\n]//;
                $cut=~s/[\x07\x08\x0b\x0c]//g;
 #               warn "qqq: push7, count=".$#$splitted;
                push(@$splitted,$cut);
                $cur_regex='';
              }
              else { die "Bailout[SPLIT]: failed to cut for regex - $cur_regex";}
            }
            else {die "Bailout[SPLIT]: bad unit, expected 'end $cur_unit', got 'end $1'"}
          }
          else {die "Bailout[SPLIT]: lost when trapping contains"}
        }
        elsif($ttt=~/^[ \t]*+contains\b/i) {
          die "Bailout[SPLIT]: double nesting detected in unit '$cur_unit $cur_name'"
        }
      }
      else {
        die "Bailout[SPLIT]: why am I here...."
      }
    }
  }
  if($#stack >= 0){
    if(! $dump=~/^$/) {
 #     warn "zzz cur_regex='$cur_regex'";
      die "Bailout[SPLIT]: failed to consume for '$dump'";
    }
  }
}

if($unit_count==0) {
  if(${f90s_VERBOSITY}>=2) {
    warn "Warning[SPLIT_ZERO]: $$fname";
  }
  push (@$splitted,$$slurp);
}
#RJ-debug if($unit_count==1) {warn "Warning[SPLIT_ONE]: $$fname";}# push (@$splitted,$$slurp);}
if($unit_count>1) {
  if(${f90s_VERBOSITY}>=4) {
    warn "Warning[SPLIT_MORE]: $$fname\n";
  }
}
if($unit_count>1 && $have_cpp>0) {
  if(${f90s_VERBOSITY}>=5) {
    warn "Warning[SPLIT_MCPP]: $$fname\n";
  }
}
if($unit_count>1 && $pos_multi==1) {
  if(${f90s_VERBOSITY}>=5) {
    warn "Warning[SPLIT_MULTI]: $$fname\n";
  }
}

#warn "aaa:\n".$$slurp."bbb:\n";
# $dump=~s/[\x07\x08\x0b\x0c]//g;

#RJ-debug warn "stack:\n".Dumper(@stack);
#RJ-debug warn "splitted:\n".Dumper(@$splitted);
#RJ-debug warn "zzz-stacks: $#stack";
#RJ-debug warn "zzz-units: $#$splitted";
}

#==========================================================================
sub study{
# Study statements and put attributes into array $statements
# Attributes assigned:
# $href->{content}       - What statement it is
# $href->{decl}       - true if declaration,
#                       5 means statement function
#                       4 means USE statement,
#                       2 means type decleration
#                       3 means FORMAT statement
#                       1 means the rest
# $href->{in_contain} - true while in internal procedure(s)
# $href->{exec}       - true if executable statement
#                     - 2 means first executable statement in program unit
#                     - 3 means last executable statement in program unit
#                     - 23 means first and last executable statement in program unit
# $href->{prog_unit}  - program unit number (numbered from 0)
# $href->{number}     - statement number (numbered from 0)

# Further attributes will be assigned later (action attributes)
  my($statements,$prog_info) = @_;
  our (${f90s_VERBOSITY});
  our ($name,$nest_par);
  my (@args,$prog_unit,$href,@punit,$current_punit);
  my ($unit_exit,$unit_type,$unit_name,@unit_args,@unit_attrs,@unit_stack);
  my $unit_stack_unbalanced=0;
  my ($content,$decl,$exec);
  my($type_def)=0;
  my($unit_count)=-1;
  @punit=();
  $current_punit='';
  my $number=-1;
  my $in_contain=0;
  my $in_interface=0;
  my $contain_host='';
  my $current_unit_name='';
  our($study_called);

#  if(! $study_called) {
#    $$prog_info{has_interface_block}=0;
#  }
# Initial "parsing" loop

  foreach $href (@$statements) {
    $href->{in_contain}=$in_contain;
    $href->{contain_host}=$contain_host if($in_contain);
    $number++;
    $_=$href->{statement};
    $content='unknown';
    my $content2='';
    $decl=0;
    $exec=0;
    my $externalized=0;

#RJ: useless
#RJ     if($type_def) {
#RJ  #     $href->{content}='typedef';
#RJ     }

# Comment
CRACK:    {
#RJ: since this is going to be free form source, exchange order of triming actions for speed
      s/^[ \t]*+//;
#RJ: not sure about this one, changing to a better one, that ignores OMP tags
#RJ       if(/^\s*!/ || /^\s*$/) {
#RJ       if(/^[\s]*+(?:$|[\!][^\$])/) {
      if(/^(?:$|[\!][^\$])/) {
        $content='comment';
        last CRACK;
      }
#RJ: preserve cpp and native fortran includes
#RJ       $_=uc($_)  unless(/^\#/);
      $_=uc($_)  unless(/^(?:[\#]|INCLUDE\b)/i);
#$RJ-old       s/^[ \t]*+//;
#RJ       s/\!.*\n/\n/g;                        # Remove trailing comments in all lines
      s/[\!](?:[^\$\n][^\n]*+[\n]|[\n])/\n/g;   # Remove trailing comments in all lines, except for conditional OMP ones
#      print "AA $_";

# Program name statement
      if($content eq 'unknown' and ! $in_interface) {
#RJ-later add check if subroutine|module|function|program is in line #speed
        if(/(?:SUBROUTINE|FUNCTION|MODULE|SUBMODULE|PROGRAM)\b/){
           my $line=$_;
           &parse_prog_unit_v2(\$line,\$unit_exit,\$unit_type,\$unit_name,\@unit_args,\@unit_attrs);
#RJ: adding early detection of end{module,function,subroutine,program}, also check for scopes
          if(($unit_exit gt 0) && ($unit_exit % 2 == 1) ) {
            if($unit_type ne "" && ($#unit_stack >= 0)) {
              if($unit_name ne "") {
 # warn " ttt: $#unit_stack\n".Dumper(@unit_stack);
                my $t_expect=pop(@unit_stack);
 # warn "  expecting: $t_expect";
                unless($t_expect=~/^(?:$unit_type)[ ]$unit_name$/i){
                  if($unit_stack_unbalanced == 0) {
			  #REK die "Bailout[CRACK]: expected 'END".uc($t_expect)."', got 'END".$unit_type." ".$unit_name."'"."$_";
                  }
                  else {
#RJ: try to balance the unit_stack
                    my $t_balance;
                    while(($#unit_stack >= 0) && ($unit_stack_unbalanced != 0)) {
                      $t_balance=pop(@unit_stack);
 # warn "  trying: $t_balance";
                      if($t_balance=~/^(?:$unit_type)[ ]$unit_name$/i){
                        $unit_stack_unbalanced=0;
                      }
                    }
                    if($unit_stack_unbalanced !=0) {
                      die "Bailout[CRACK]: failed to balance unit_stack";
                    }
                  }
                }
              }
              else {
                $unit_stack_unbalanced = -2;
                my $t_expect2=pop(@unit_stack);
                unless($t_expect2=~/^(?:$unit_type)\b/i){
                  if($unit_stack_unbalanced == 0) {
                    die "Bailout[CRACK]: expected 'END".uc($t_expect2)."', got 'END".$unit_type." "."'"."$_";
                  }
                  else {
#RJ: try to balance the unit_stack
                    my $t_balance2;
                    while(($#unit_stack >= 0) && ($unit_stack_unbalanced != -1)) {
                      $t_balance2=pop(@unit_stack);
                      if($t_balance2=~/^(?:$unit_type)\b/i){
                        $unit_stack_unbalanced=-1;
                      }
                    }
                    if($unit_stack_unbalanced !=0) {
                      if(${f90s_VERBOSITY}>=4) {
                        warn "Warning[CRACK]: unit_stack might be unbalanced";
                      }
                    }
                  }
                }
              }
            }
            $prog_unit=pop(@punit);
            $prog_unit="" unless (defined($prog_unit));
            $content='END'.uc($prog_unit);
            if($in_contain) {
              unless(@punit) {
                $unit_count=0;
                $href->{in_contain}=0;
                $in_contain=0;
              }
            }
#            unless($t_type=~/^(?:$prog_unit)$/i){
#              die "Bailout[CRACK]: expected 'END".uc($prog_unit)."', got 'END".$t_type."'"."$_";
#            }
#            else{ warn "if in2: OK";}

            last CRACK;
          }
          elsif($unit_exit == 0) {
            $prog_unit=$unit_type;
#RJ             if($prog_unit) {
              $current_unit_name=$unit_name;
              $content=uc($prog_unit);
              push(@punit,$prog_unit);
              $current_punit=$prog_unit;
              $unit_count++;
              if(! $study_called) {
                push(@unit_stack,$unit_type.' '.$unit_name);
#RJ-dub?                 $$prog_info{'unit_name'}[$unit_count]=uc($unit_name);
                $$prog_info{'unit_name'}[$unit_count]=uc($unit_name);
#                $$prog_info{'tokens'}[$unit_count]=[];
                if($prog_unit eq 'module') {
                  $$prog_info{'is_module'}=1;
                  $$prog_info{'module_name'}=$unit_name;
                }
              }
              last CRACK;
#RJ             }
          }
          else {
#RJ: didn't matched unit_exit<0
          }
        }
      }

#RJ: deal with number labels first, might be good idea, to add this info to structure
#RJ: requires change to "FORMAT" detection
    if($content eq 'unknown') {
      s/^[\s ]*+[\d]++[\s]++//;
    }

      if($content eq 'unknown') {
        $decl=0;
        $exec=1;
# Executable constructs
        &study_exec(\$content,$prog_info,\$study_called);
        if($content eq 'IF') {
          s/^IF[\s]*+$nest_par[\s]*+//;
          &study_exec(\$content2,$prog_info,\$study_called);
#RJ: workaround for case "IF (CLSTRU(J:J).==.')') THEN" in xrd/lfi/lfidst.F90 giving use of uninited values
#RJ: extra safety, try to detect content=='IF_construct'
          if($content2 eq '') {
            if(/^[^\w]++THEN\b/) {
              $content="IF_construct";
            }
            else {
              die "Bailout[STUDY]: failed to detect content2 for $_";
            }
          }
        }
      }

      if($content eq 'unknown') {
# Specification statements
        $exec=0;
        $decl=1;
        if(/^USE\b/) {
          $content='USE';
          $decl=4;
        }
        elsif(/^INTEGER\b/) {
          $content='INTEGER';
          $decl=2;
          if(/[,][ ]*+EXTERNAL\b/) {
            $externalized=1;
          }
        }
        elsif(/^REAL\b/) {
          $content='REAL';
          $decl=2;
          if(/[,][ ]*+EXTERNAL\b/) {
            $externalized=1;
          }
        }
        elsif(/^LOGICAL\b/) {
          $content='LOGICAL';
          $decl=2;
          if(/[,][ ]*+EXTERNAL\b/) {
            $externalized=1;
          }
        }
        elsif(/^CHARACTER\b/) {
          $content='CHARACTER';
          $decl=2;
          if(/[,][ ]*+EXTERNAL\b/) {
            $externalized=1;
          }
        }
        elsif(/^DOUBLE PRECISION\b/) {
          $content='DOUBLE PRECISION';
          $decl=2;
          if(/[,][ ]*+EXTERNAL\b/) {
            $externalized=1;
          }
        }
        elsif(/^COMPLEX\b/) {
          $content='COMPLEX';
          $decl=2;
          if(/[,][ ]*+EXTERNAL\b/) {
            $externalized=1;
          }
        }
        elsif(/^(TYPE|CLASS)[ ]*+[(]/) {
          $content='type_decl';
          $decl=2;
          if(/[,][ ]*+EXTERNAL\b/) {
            $externalized=1;
          }
        }
        elsif(/^ALLOCATABLE\b/) {
          $content='ALLOCATABLE';
        }
        elsif(/^COMMON\b/) {
          $content='COMMON';
        }
        elsif(/^DATA\b/) {
          $content='DATA';
        }
        elsif(/^DIMENSION\b/) {
          $content='DIMENSION';
        }
        elsif(/^EQUIVALENCE\b/) {
          $content='EQUIVALENCE';
        }
        elsif(/^EXTERNAL\b/) {
          $content='EXTERNAL';
          $externalized=1;
        }
#RJ: due to number label stripping above
#RJ         elsif(/^\d+\s+FORMAT\b/) {
        elsif(/^FORMAT\b/) {
          $content='FORMAT';
          $decl=3;
        }
        elsif(/^IMPLICIT\b\s+NONE\b/) {
          $content='IMPLICIT NONE';
        }
        elsif(/^IMPLICIT\b/) {
          $content='IMPLICIT';
        }
        elsif(/^INTENT\b/) {
          $content='INTENT';
        }
        elsif(/^INTRINSIC\b/) {
          $content='INTRINSIC';
        }
        elsif(/^NAMELIST\b/) {
          $content='NAMELIST';
        }
        elsif(/^OPTIONAL\b/) {
          $content='OPTIONAL';
        }
        elsif(/^PARAMETER\b/) {
          $content='PARAMETER';
        }
        elsif(/^POINTER\b/) {
          $content='POINTER';
        }
        elsif(/^PUBLIC\b/) {
          $content='PUBLIC';
        }
        elsif(/^PRIVATE\b/) {
          $content='PRIVATE';
        }
        elsif(/^SAVE\b/) {
          $content='SAVE';
        }
        elsif(/^TARGET\b/) {
          $content='TARGET';
        }
        elsif(/^SEQUENCE\b/) {
          $content='SEQUENCE';
        }
        elsif(/^PROCEDURE\b/) {
          $content='PROCEDURE';
        }
        elsif(/^IMPORT\b/) {
          $content='IMPORT';
        }
        elsif(/^ABSTRACT\b/) {
          $content='ABSTRACT';
        }
        elsif(/^INTERFACE\b/) {
          $content='INTERFACE';
          if(! $study_called) {
            $$prog_info{has_interface_block}=1;
            $in_interface=1;
          }
        }
#RJ: catch multi space cases too
#RJ         elsif(/^END ?INTERFACE\b/) {
        elsif(/^END[ ]*+INTERFACE\b/) {
          $content='END INTERFACE';
          $in_interface=0;
        }
#RJ         elsif(/^TYPE *[^\( ]/i) {
        elsif(/^TYPE[ ]*+[^\( ]/i) {
          $content='type_def';
          $type_def=1;
        }
#RJ         elsif(/^END ?TYPE\b/){
        elsif(/^END[ ]*+TYPE\b/){
          $content='type_def';
          $type_def=0;
        }
        elsif( $in_interface ) {
#RJ           if(/^MODULE PROCEDURE\b/) {
          if(/^MODULE[ ]++PROCEDURE\b/) {
            $content='MODULE PROCEDURE';
          }
        }
      }
# Other constructs
      if($content eq 'unknown') {
        $decl=0;
        $exec=0;

        if ( $type_def ) {
          $content = 'type_def';
        }
        elsif(/^CONTAINS\b/) {
          $content='CONTAINS';
          $in_contain=1;
          $contain_host=uc($current_unit_name);
          if(! $study_called) {
            $$prog_info{has_contain}=1;
            $$prog_info{containing}=1;
          }
        }
        elsif(/^\#include\b/) {
          $content='include';
          if(! $study_called) {
            $$prog_info{has_include}=1;
          }
        }
#RJ: assume if statement starts with '_' it is a cpp macro
        elsif(/^(?:[\#]|[_])/) {
          $content='cpp';
        }
#RJ: conditional OPENMP directive
        elsif(/^[\!][\$]/) {
          $content='omp';
        }
#RJ: fortran native include directive, maybe inling them is a good idea.. but should be moved up before uc()
#RJ: due to attempt to consider this as include too, i modiffier
#RJ         elsif(/^INCLUDE/) {
        elsif(/^INCLUDE\b/i) {
          $content='native_include';
        }
        elsif(/^\@/) {
          $content='compiler_directive';
        }
        elsif (/^SELECT\b/i) {
          $content = 'SELECT';
        }
        else{
#RJ: allow fused statements
#RJ-later check what gets here, just in case
          if(/^END\b[^\w]++$/) {
            $prog_unit=pop(@punit);
            if($unit_stack_unbalanced == 0) {
              $unit_stack_unbalanced = 1;
            }
  #          warn "Warning[CRACK] unblanced END";
            $prog_unit="" unless (defined($prog_unit));
            $content='END'.uc($prog_unit);
            if($in_contain) {
              unless(@punit) {
                $unit_count=0;
                $href->{in_contain}=0;
                $in_contain=0;
              }
            }
          }
#RJ: other strangeness
#RJ: "ENTRY" statement, but not adding declaration bit, just warn
          elsif(/^ENTRY[ ]+[A-Z]/) {
            $exec=0;
            $decl=0;
            $content='ENTRY';
            if(${f90s_VERBOSITY}>=4) {
              warn "Warning[STUDY]: pos 'ENTRY' statement detected\n";
            }
          }
#RJ: multiline cpp macro as statement in some of ifsaux/misc/{fa,lfi}*.F90, mse/new/sfx*.F90, mse/module/modd_io_surf_aro.F90
#RJ: adding to cpp, could be checked from there, dangerous because contains '//'
          elsif(/^TESTIREP\b[^\&\n]*[\n]/) {
            $exec=1;
            $decl=0;
            $content='cpp';
            if(${f90s_VERBOSITY}>=4) {
              warn "Warning[STUDY]: pos 'TESTIREP' macro detected, added to cpp_bad group\n";
            }
          }
#RJ: bad "ERROR" odb prototyping in fodb.h,fodbutil.h,fodbmp.h,fodbmp1.h,fodbmp2.h,ecsort_shared.h
#RJ-remark this one should be replaced with #error to crash at preprocessor early. For now adding to cpp_bad
          elsif(/^ERROR\b[^\=\&\n]*[\n]/) {
            $exec=1;
            $decl=0;
            $content='cpp_bad';
            if(${f90s_VERBOSITY}>=2) {
              warn "Warning[STUDY]: pos 'ERROR' macro detected, should be replaced with \#error\n";
            }
          }
#RJ: some prototyping types in odb, could be deleted, but for compleateness
          elsif(/^(DATA_TYPE|GEN_TYPE)\b[^\=\&\n]*[\n]/) {
            $exec=0;
            $decl=1;
            $content='cpp_odb';
          }
#RJ: very bad multiline cpp macro as declaration/statement in sat project sources, #include throw.h
#RJ: adding to cpp_sat, could be checked from there
#RJ-remark recommend to do something about this one, lots of surprising effects
          elsif(/^TRY\b[^\=\&\n]*[\n]/) {
            $exec=1;
            $decl=1;
            $content='cpp_sat';
            if(${f90s_VERBOSITY}>=4) {
              warn "Warning[STUDY]: pos very bad  'TRY' macro detected, added to cpp_sat group\n";
            }
          }
#RJ: throw.h others, simple
          elsif(/^(CATCH|CATCH_L|PCATCH)\b[^\=\&\n]*[\n]/) {
            $exec=1;
            $decl=0;
            $content='cpp_sat';
            if(${f90s_VERBOSITY}>=4) {
              warn "Warning[STUDY]: pos multiline '$1' macro detected, added to cpp_sat group\n";
            }
          }
#RJ: throw.h others, but be safe for good variables, for simplicity using up to double nested '(())'
          elsif(/^(THROW|THROWM|THROW_L|INFO|WARN)\b(?:[(][^()]++(?:[(][^)]++[)])?[^)]*[)])?[^\=\&\n]*[\n]/) {
            $exec=1;
            $decl=0;
            $content='cpp_sat';
            if(${f90s_VERBOSITY}>=4) {
              warn "Warning[STUDY]: pos multiline '$1' macro detected, added to cpp_sat group\n";
            }
          }
        }
      }
    }

#RJ-debug warn "zzz: $_ $content";

    if($in_interface and $content ne 'INTERFACE') {
      $content='in_interface';
      $exec=0;
      $decl=1;
    }

 # warn "DEBUG: ".$content." | ".$decl." | $_";

#    print "BB $unit_count $content $_";
    if($content  eq 'unknown') {
      print STDERR "Failed to crack statement starting at line $href->{first_line}"," - syntax error?? \n";
      print STDERR " $_ ";
#      print STDERR "study_called $study_called in_interface $in_interface \n";
#      print STDERR Dumper($statements);
      my $fname = $ENV{'CHK_NORMS_CURRENT'};
      my $tag   = defined($fname) ? "[$fname] " : '';
      die "${tag}Failed[STUDY] in study";
    }
#    unless($content eq 'comment') {
#      my @tmpvar=/\b$name\b/g;
#      my $i=0;
#      foreach my $tmp (@tmpvar){
#        $href->{'tokens'}[$i]=$tmp;
#        $i++;
#        if(! $study_called and $unit_count > -1) {
#          $$prog_info{'token_hash'}[$unit_count]{$tmp}++;
#        }
#      }
#    }

    $href->{content}=$content;
    $href->{content2}=$content2 if($content2);
    $href->{externalized}=$externalized if($externalized>0);
    $href->{decl}=$decl;
    $href->{exec}=$exec;
#    $href->{type_decl}=$type_decl;
    $href->{prog_unit}=$unit_count;
    $href->{number}=$number;
    unless($content eq 'comment') {
      $href->{multi_line} = 1 if(tr/\n// > 1);
    }
  }


# Find first executable statement in each program unit
# Also repair statement functions wrongly assigned as executable
  my $prev_unit_count=-2;
  my $stat_func_suspicion=0;
  my @lastexec=();

  foreach $href (@$statements) {
    $exec=$href->{exec};
    $unit_count=$href->{prog_unit};
    if($exec) {
      if($unit_count > $prev_unit_count) {
        $content=$href->{content};
        if($content eq 'array_assign') {
          $stat_func_suspicion=1;
          $_=$href->{statement};
          if(/^\s*$name\s*\(\s*:/){
          $stat_func_suspicion=0;
#            print " A $_";
          }
          elsif(/^\s*$name\s*\(\s*$name\s*:/){
            $stat_func_suspicion=0;
#            print " B $_";
          }
          elsif(/^\s*$name\s*\(\s*\d+/){
            $stat_func_suspicion=0;
#            print " C $_";
          }
#RJ: better statement function detection, they always have 'xxx(..)=' form
#RJ           elsif(/^[^\=(]++[\s ]*+[\=]/) {
          elsif(/^[^\=\%(]++[\s ]*+[\=\%]/) {
            $stat_func_suspicion=0;
          }
#RJ           else {
          elsif(/[)][\s ]*+[\=]/) {
            $href->{exec}=0;
            $href->{decl}=5;
            $href->{content}='statmf';
#            print " D $_";
            next;
          }
          else {
            my $fname = $ENV{'CHK_NORMS_CURRENT'};
            my $tag   = defined($fname) ? "[$fname] " : '';
            die "${tag}Failed[STUDY]: fix stat_func for $_"
          }
        }
        $href->{exec}=2;
        $prev_unit_count=$unit_count;
        $content=$href->{content};
      }
      $lastexec[$unit_count]=$href->{number}  unless ($unit_count < 0);
# No prog_unit assigned, include file?
    }
  }

# Assign last executable statement
  if(@lastexec) {
    foreach my $last (@lastexec) {
      if(defined ($last)) {
        if($$statements[$last]->{exec} == 1) {
          $$statements[$last]->{exec}=3;
        }
        else{
          $$statements[$last]->{exec}=23;
        }
      }
    }
  }
# Consistency checks
  my $fail=0;
  my $prev_exec=0;
  $prev_unit_count=-1;
  foreach $href (@$statements) {
    $content=$href->{content};
    next if($content eq 'comment');
    $unit_count=$href->{prog_unit};
    $exec=$href->{exec};
    $decl=$href->{decl};
    if($unit_count == $prev_unit_count) {
      if($decl and $prev_exec) {
        unless ($content eq 'FORMAT' | $content eq 'DATA' ) {
          print STDERR "$href->{first_line} $href->{statement}";
          print STDERR "Decleration after executable statement\n";
          my $fname = $ENV{'CHK_NORMS_CURRENT'};
          my $tag   = defined($fname) ? "[$fname] " : '';
          warn "${tag}Failed[STUDY] at $href->{first_line} $href->{statement}\n";
          $href->{fail}=1;
          $fail=1;
        }
      }
    }
    $prev_unit_count=$unit_count;
    $prev_exec=$exec;
  }
  if($fail) {
    foreach $href (@$statements) {
      $content=$href->{content};
      $unit_count=$href->{prog_unit};
      $exec=$href->{exec};
      $decl=$href->{decl};
      print "*** FAIL *** : " if (exists($href->{fail}));
      print "$href->{first_line} : \"$content\" $unit_count $exec $decl $href->{statement}";
    }
    my $fname = $ENV{'CHK_NORMS_CURRENT'};
    my $tag   = defined($fname) ? "[$fname] " : '';
    die "${tag}Failed[STUDY]";
  }
  $study_called=1;

}

#==========================================================================
sub study_exec{
  my($content,$prog_info,$study_called) = @_;
  our ($name,$nest_par);
#RJ   if(/^(\w+\s*:\s*)*IF\s*$nest_par\s*THEN/) {
#RJ   if(/^(?:[\w]+[\s]*+[\:][\s]*+)?+IF[\s]*+$nest_par(?:[\'\")\s]*+)THEN\b/) {
  if(/^(?:[\w]+[\s]*+[\:][\s]*+)?+IF[\s]*+$nest_par[\s]*+THEN\b/) {
    $$content='IF_construct';
  }
#RJ: catch multi space cases too
#RJ   elsif(/^ELSE ?IF *\(/) {
  elsif(/^ELSE[ ]*+IF *\(/) {
    $$content='ELSEIF';
  }
  elsif(/^ELSE\b\s*($name)*/) {
    $$content='ELSE';
  }
#RJ: catch multi space cases too
#RJ   elsif(/^END ?IF\b\s*($name)*/) {
  elsif(/^END[ ]*+IF\b\s*($name)*/) {
    $$content='ENDIF';
  }
#RJ: non capturing variant
#RJ   elsif(/^($name\s*:\s*)*DO\b/) {
  elsif(/^(?:$name\s*:\s*)*DO\b/) {
    $$content='DO';
  }
#RJ: catch multi space cases too
#RJ   elsif(/^END ?DO\b/) {
  elsif(/^END[ ]*+DO\b/) {
    $$content='ENDDO';
  }
  elsif(/^ALLOCATE\b/) {
    $$content='ALLOCATE';
  }
  elsif(/^ASSIGN\b/) {
    $$content='ASIGN';
  }
  elsif(/^BACKSPACE\b/) {
    $$content='BACKSPACE';
  }
  elsif(/^CALL\b/) {
    $$content='CALL';
    if(!$$study_called) {
      $$prog_info{no_calls}++;
    }
  }
  elsif(/^CLOSE\b/) {
    $$content='CLOSE';
  }
#RJ: unneeded digit after my modification
#RJ   elsif(/^(\d+)*\s*CONTINUE\b/) {
  elsif(/^CONTINUE\b/) {
    $$content='CONTINUE';
  }
  elsif(/^CYCLE\b/) {
    $$content='CYCLE';
  }
  elsif(/^DEALLOCATE\b/) {
    $$content='DEALLOCATE';
  }
  elsif(/^ENDFILE\b/) {
    $$content='ENDFILE';
  }
  elsif(/^EXIT\b/) {
    $$content='EXIT';
  }
#RJ: catch multi space cases too
#RJ   elsif(/^GO ?TO\b/) {
  elsif(/^GO[ ]*+TO\b/) {
    $$content='GOTO';
  }
  elsif(/^IF\s*\(/) {
    $$content='IF';
  }
  elsif(/^INQUIRE\b/) {
    $$content='INQUIRE';
  }
  elsif(/^NULLIFY\b/) {
    $$content='NULLIFY';
  }
  elsif(/^OPEN\b/) {
    $$content='OPEN';
  }
  elsif(/^PAUSE\b/) {
    $$content='PAUSE';
  }
  elsif(/^PRINT\b/) {
    $$content='PRINT';
  }
  elsif(/^READ\b/) {
    $$content='READ';
  }
  elsif(/^READ\b/) {
    $$content='READ';
  }
  elsif(/^RETURN\b/) {
    $$content='RETURN';
  }
  elsif(/^REWIND\b/) {
    $$content='REWIND';
  }
  elsif(/^STOP\b/) {
    $$content='STOP';
  }
  elsif(/^SYNC ALL\b/) {
    $$content='SYNC ALL';
  }
  elsif(/^SYNC IMAGES\b/) {
    $$content='SYNC IMAGES';
  }
  elsif(/^WHERE\s*$nest_par\s*$name.*=/) {
    $$content='WHERE';
  }
  elsif(/^WRITE\s*\(/) {
    $$content='WRITE';
  }
  elsif(/^($name\s*:\s*)*SELECT\s?CASE\b/) {
    $$content='SELECT CASE';
  }
  elsif(/^CASE\b/) {
    $$content='CASE';
  }
  elsif(/^CLASS +IS\b/) {
    $$content = 'CLASS IS';
  }
  elsif(/^CLASS +DEFAULT\b/) {
    $$content = 'CLASS DEFAULT';
  }
#RJ: catch multi space cases too
#RJ   elsif(/^END ?SELECT\b/) {
  elsif(/^END[ ]*+SELECT\b/) {
    $$content='END SELECT';
  }
  elsif(/^WHERE *\(/) {
    $$content='WHERE_construct';
  }
#RJ: catch multi space cases too
#RJ   elsif(/^ELSE ?WHERE\b/) {
  elsif(/^ELSE[ ]*+WHERE\b/) {
    $$content='ELSEWHERE';
  }
#RJ: catch multi space cases too
#RJ   elsif(/^END ?WHERE\b/) {
  elsif(/^END[ ]*+WHERE\b/) {
    $$content='ENDWHERE';
  }
  elsif(/^ASSOCIATE\b/) {
    $$content='ASSOCIATE';
  }
#RJ: catch multi space cases too
#RJ   elsif(/^END ?ASSOCIATE\b/){
  elsif(/^END[ ]*+ASSOCIATE\b/){
    $$content='ENDASSOCIATE';
  }
#RJ: new class "pointer_assign"
  elsif(/^(?:[A-Z][\w]*+)[\s ]*+[\=][\>]/) {             #iglob_type  => g%glob%ntypsend(:)
    $$content='pointer_assign';
  }
  elsif(/^$name\s*=/o) {                                 #ZVAR = ....
    $$content='scal_assign';
  }
  elsif(/^$name\s*$nest_par\s*\[([\S\s]*?)\]\s*=/o) { #ZARR(JL)[IMAGE] = .... 
    $$content='array_assign';
  }
#RJ: assuming that you have perl 5.10
#RJ: universal one for structures and nested ones, if only needed to detect if it is an assignment to element
#RJ: others unneeded
#RJ: uses perl v5.010 feature - $nested_par, could be inlined
  elsif(/^[\w]++[\s]*+(?:[\%][\s]*+[\w]++|(?:([(](?:[^()]++|(?-1))*+[)]))|[\s]++)++[\s]*[\=]/) {
    $$content='array_assign';
#RJ: redirect to "pointer_assign" class if contains '=>'
    if(/[\=][\>]/) {
      $$content='pointer_assign';                        #pre%storage=>g%pre%storage
    }
  }
#RJ   elsif(/^$name\s*$nest_par\s*=/o) {                     #ZARR(JL) = ....
#RJ     $$content='array_assign';
#RJ   }
#RJ   elsif(/^$name\s*%\s*$name\s*=/o) {                     #ZMYTYPE%ICOMP = .....
#RJ     $$content='scal_assign';
#RJ   }
#RJ   elsif(/^$name\s*$nest_par\s*%\s*$name\s*=/o) {         #ZMYTYPE(JK)%ICOMP = .....
#RJ     $$content='array_assign';
#RJ   }
#RJ   elsif(/^$name\s*%\s*$name\s*$nest_par\s*=/o) {         #ZMYTYPE%ICOMP(JL) = .....
#RJ     $$content='array_assign';
#RJ   }
#RJ   elsif(/^($name\s*($nest_par)*\s*%\s*$name\s*($nest_par)* *)+=/o) { #ZMYTYPE(JK)%ICOMP(JL) = ...
#RJ     $$content='array_assign';
#RJ   }
#RJ   elsif(/^$name\s*($nest_par)($nest_par)\s*=/o) {        #CLNAME(JK)(1:5) = ......
#RJ     $$content='array_assign';
#RJ   }
}
#===================================================================================
sub pre_tidy {

# Initial tidying to make the rest work

  my($lines)=@_;
  foreach (@$lines) {

# Substitute tab with four blanks
    s/\t/    /g;
    s/^ *INTEGER /INTEGER_M /i;
    s/^ *REAL /REAL_B /i;
  }
}
#==========================================================================
sub remove_macro {

# Remove INTEGER_M, _ONE_ etc. macros and replace by expanded statement

  my($lines)=@_;

  my($im)=1; # Until I start checking include files
  my($ia)=0;
  my($ib)=0;
  my($rb)=1; # Until I start checking include files
  my($is)=0;
  my($rh)=0;
  my($rm)=0;
  my(@pars,$string);
  for (@$lines) {
    next if(/^ *$/ | /^ *!/);
# The following two substitutions should be restored at end of processing
    s/(\'[^!]*)!+(.*\')/$1\$2/;   # Protect against mischief
    s/(["][^!]*)!+(.*["])/$1\$2/;      # Protect against mischief
    $im=$im+/JPIM\b/i unless($im);
    $rb=$rb+/JPRB\b/i unless($rb);
    $rm=$rm+/JPRM\b/i unless($rm);
    $im=$im+s/\bINTEGER_M\b/INTEGER(KIND=JPIM)/o;
    $ia=$ia+s/\bINTEGER_A\b/INTEGER(KIND=JPIA)/o;
    $ib=$ib+s/\bINTEGER_B\b/INTEGER(KIND=JPIB)/o;
    $is=$is+s/\bINTEGER_S\b/INTEGER(KIND=JPIS)/o;
    $rb=$rb+s/\bREAL_B\b/REAL(KIND=JPRB)/o;
    $rh=$rh+s/\bREAL_H\b/REAL(KIND=JPRH)/o;
    $rm=$rm+s/\bREAL_M\b/REAL(KIND=JPRM)/o;
    $rb=$rb+s/\b_ZERO_\b/0.0_JPRB/og;
    $rb=$rb+s/\b_ONE_\b/1.0_JPRB/og;
    $rb=$rb+s/\b_TWO_\b/2.0_JPRB/og;
    $rb=$rb+s/\b_HALF_\b/0.5_JPRB/og;
  }
  @pars=();
  push(@pars,"JPIM") if $im;
  push(@pars,"JPRB") if $rb;
  push(@pars,"JPRM") if $rm;
  push(@pars,"JPIA") if $ia;
  push(@pars,"JPIB") if $ib;
  push(@pars,"JPIS") if $is;
  ($string=join('     ,',@pars))=~s/ *$//;
  for (@$lines) {
    next unless (/^\#/);
    if(@pars) {
      s/^#include +"tsmbkind.h"/USE PARKIND1  ,ONLY : $string/ ;
    }
    else {
      s/^#include +"tsmbkind.h"//;
    }
#    if($rh) {
      s/^#include +"hugekind.h"/USE PARKIND2  ,ONLY : JPRH/ ;
#    }
#    else {
#      s/^#include +"hugekind.h"// ;
#    }
  }
}

#==========================================================================
#RJ: simply returns mod and inc dependencies
sub slurp_depends{
  my($slurped,$mod_deps,$inc_deps)=@_;

  {
    local $/;
    my $dump="\n".$$slurped."\n";

    $dump=~s/[\n][ \t]*+use[ \:\t]++([\w]+)/$$mod_deps.=' '.$1;""/ieg;
    $dump=~s/[\n][ \t\#]*+include[ ]*+[\"\'][ ]*+([^\s\'\"]++)[ ]*+[\"\']/$$inc_deps.=' '.$1;""/ieg;

    $$mod_deps=~s/^[ ]++//;
    $$inc_deps=~s/^[ ]++//;
    $$mod_deps=lc($$mod_deps);

    my %hm =();
    my @am =();
    @am = grep { ! $hm{$_}++ } split(' ',$$mod_deps);
    $$mod_deps=join(' ',@am);
    
    my %hi =();
    my @ai =();
    @ai = grep { ! $hi{$_}++ } split(' ',$$inc_deps);
    $$inc_deps=join(' ',@ai);

  }
}

#==========================================================================
#RJ: very fast and stict(only needed dependencies) modi maker, includes intfb
sub slurp_modi{
  my($slurped,$output,$iname,$iret)=@_;

  &slurp_intfb($slurped,$output,$iname,$iret);
  if($$iret!=0){
    return;
  }
  {
    local $/;
    $$output="MODULE MODI_".uc($$iname)."\nIMPLICIT NONE\n".$$output;
    $$output.="ENDMODULE MODI_".uc($$iname)."\n";
  }

}

#==========================================================================
#RJ: very fast and very stict(only needed dependencies) intfb maker
#RJ: follows dummy argument declaration order, so no reordering in actual declrations
sub slurp_intfb{
#RJ: on purpose fails to create following interfaces for units:
#RJ  odb_api_get_colnames (indirect use of parkind1 for JPIM)     @ ./src/odb/lib/odb_wrapper.F90
#RJ  odb_whatis           (indirect use of parkind1 for JPIM)     @ ./src/odb/lib/odb_wrapper.F90
#RJ  compute_links        (indirect use of parkind1 for JPIM)     @ ./src/odb/lib/odb_wrapper.F90
#RJ  fresnel              (indirect use of parkind1 for JPRB)     @ ./src/sat/cmem/fresnel_sub.F90
#RJ  kfgrid_get           (indirect use of parkind1 for JPRB)     @ ./src/sat/emiss/kfgrid_get.F90
#RJ  cutzero              (missing integer type decl for KMIN)    @ ./src/sat/programs/bufr_resat_thin.F90
#RJ  init_garden_options_n(dummy sub to be removed, but no abort) @ ./src/surfex/SURFEX/init_garden_optionsn.F90

#RJ: multiple definitions in hm source tree if splitted to separate units without cpp, this implies that there are some prototyping:
#RJ   ctxprint
#RJ   mpi_setup_c
#RJ   mpi_finalize_c
#RJ   mpi_print_info_c
#RJ   odb_no_of_local_pools_c
#RJ   odb_get_local_pools_c
#RJ   odb_open_c
#RJ   odb_close_c
#RJ   odb_swapout_c
#RJ   odb_get_no_of_columns_c
#RJ   odb_create_index_c
#RJ   odb_put_one_row_c
#RJ   odb_update_links_c
#RJ   sub1
#RJ   sub2
#RJ   process_table
#RJ   compress_print
#RJ   printables
#RJ   open_db
#RJ   close_db
#RJ   view_cancel
#RJ   swapout_view
#RJ   view_select
#RJ   view_get
#RJ   add_view
#RJ   put_odb
#RJ   geobox
#RJ   geosangl
#RJ   eigenmd

#RJ: creates uncompilable interfaces for these units:
#RJ:  (mainly dummy argument list order doesn't match declaration order)
#RJ:  this also implies that dummy args as dependencies should be declaraded first for clarification
#RJ:  best solution would be pass them through module(runtime anyway) or shift order
#RJ  carnak     (KOBSx,KINDSIZ passed after their use as deps)  @ ./src/arp/canari/carnak.F90
#RJ  jmgfixer   (YDSL passed after its use as dep)              @ ./src/arp/control/jmgfixer.F90
#RJ  negfixer   (YDSL passed after its use as dep)              @ ./src/arp/control/negfixer.F90
#RJ  qmfixer2   (YDSL passed after its use as dep)              @ ./src/arp/control/qmfixer2.F90
#RJ  qmfixer    (YDSL passed after its use as dep)              @ ./src/arp/control/qmfixer.F90
#RJ  trmfixers  (YDSL passed after its use as dep)              @ ./src/arp/control/trmfixers.F90
#RJ  rttov_calcemis_ir_k (chanprof used before it is passed)    @ ./src/sat/rttov/main/rttov_calcemis_ir_k.F90
#RJ  rttov_calcemis_mw_k (chanprof used before it is passed)    @ ./src/sat/rttov/main/rttov_calcemis_mw_k.F90
#RJ  rttov_intavg_chan   (chanprof used before it is passed)    @ ./src/sat/rttov/main/rttov_intavg_chan.F90
#RJ  rttov_intavg_chan_k (chanprof used before it is passed)    @ ./src/sat/rttov/main/rttov_intavg_chan_k.F90
#RJ  rttov_intavg_chan_ad(chanprof used before it is passed)    @ ./src/rttov/main/rttov_intavg_chan_ad.F90
#RJ  rttov_intavg_chan_tl(chanprof used before it is passed)    @ ./src/sat/rttov/main/rttov_intavg_chan_tl.F90
#RJ  rttov_setpredictors_7_k (profiles used before it is passed)@ ./src/sat/rttov/main/rttov_setpredictors_7_k.F90
#RJ  rttov_setpredictors_8_k (prof     used before it is passed)@ ./src/sat/rttov/main/rttov_setpredictors_8_k.F90
#RJ  rttov_setpredictors_9_k (prof     used before it is passed)@ ./src/sat/rttov/main/rttov_setpredictors_9_k.F90
#RJ  odb_fill_c(locally declared c_int_array used for dummy args)@ ./src/odb/lib/odb_wrapper.F90

#RJ: others are fine, this sub forces generic interfaces, but code currently mismatches them in some places

  my($slurped,$output,$iname,$iret)=@_;
  our($nest_par,$type_spec);
  {
    local $/;
    $$iret=-1;
    my $dump="\n".$$slurped."\n";

    $dump=~s/[\n][\s]++/\n/g;
    $dump=~s/[\n](?:if|do|call|contains)\b[^\x00]++$//i;
    $dump=~s/[\n][\!][^\n]*+//g;
    $dump=~s/[\t]/ /g;

#RJ: kill interfaces, not needed for intfbs
    if($dump=~s/[\n](?:end[\s]*+)?+interface\b/\n\x11/ig) {
      $dump=~s/[\n][\x11][^\x11]++[\x11][^\n]++//g;
    }

#RJ: now it should be safe to check weather this is a module or program
    if($dump=~/[\n](?:module|program)\b/i){
 # warn "skipping: module or program detected";
      $$iret=-2;
      return;
    }

    my $unit_found=0;
    my $unit_exit='';
    my $unit_type='';
    my $unit_name='';
    my @unit_args;
    my @unit_attrs;

 #   my $line='subroutine odb_api_get_colnames(odb_iterator, colnames, c_ncols, idx_seqno, masterKey) bind(C, name="odb_swapout_f90")   ';
 #   &parse_prog_unit_v2(\$line,\$unit_exit,\$unit_type,\$unit_name,\@unit_args,\@unit_attrs);
 #   warn Dumper(@unit_attrs);
    
#RJ: be carefull on unit type searches
    {
      my $tdump=$dump;
      $tdump=~s/[\!][^\n]*+//g;
      $tdump=~s/[\&][ \t]*+[\s\&]++//g;
      my @tlines;
      &slurp2array(\$tdump,\@tlines);
      foreach my $tline (@tlines) {
        if($tline=~/(?:SUBROUTINE|FUNCTION|MODULE|SUBMODULE|PROGRAM)\b/i){
          &parse_prog_unit_v2(\$tline,\$unit_exit,\$unit_type,\$unit_name,\@unit_args,\@unit_attrs);

          if($unit_exit == 0) {
            if($unit_type=~/^(module|program|submodule)$/i) {
 # warn "skipping: module or program detected";
              $$iret=-2;
              return;
            }
            elsif($unit_type=~/^(?:subroutine|function)$/i) {
 # warn "found $unit_type";
              $unit_found=1;
              last;
            }
          }
        }
      }
 # warn Dumper(@unit_args);
      if($unit_found != 1) {
  warn "failed to found unit type";
        $$iret=-3;
        return;
      }
    }
    $$iname=lc($unit_name);
    my $outstart='';
    my $outend='';
    my $func_have_type=0;
    my $func_type_decl='';
    my $func_result_name='';

    $outend="END".uc($unit_type).' '.uc($unit_name)."\n";
    $outend.="ENDINTERFACE ".uc($unit_name)."\n";

    $outstart=uc($unit_type).' '.uc($unit_name);
    $outstart.='(';
    if(@unit_args){
      $outstart.=uc($unit_args[0]);
      foreach my $ii (1..$#unit_args) {
        $outstart.=','.uc($unit_args[$ii]);
      }
    }
    $outstart.=')';

    if(@unit_attrs) {
 # warn Dumper(@unit_attrs);
      my $tbind='';
      foreach my $ii (0..$#unit_attrs) {
        my $ttt=$unit_attrs[$ii];
        if($ttt=~/^(RECURSIVE|PURE|ELEMENTAL)$/i) {
          $outstart=$1.' '.$outstart;
        }
        elsif($ttt=~/^BIND\b/i) {
          $tbind=$ttt;
        }
        elsif($ttt=~/^RESULT[ ]*+[(][ ]*+([\w]++)[ ]*+[)]$/i) {
          $func_result_name=$1;
          if($func_result_name ne uc($unit_name)) {
            $outstart.=" ".$ttt;
          }
        }
        else {
#RJ: assume it is function type declaration
 # warn "unknown extra attribute '$ttt'";
            $func_type_decl=uc($ttt);
        }
      }

#      if(($unit_type eq 'function') && ($func_type_decl ne '')) {
#        $func_type_decl.=":: ".$func_result_name;
#      }

      if($tbind ne '') {
        $outstart.=' '.$tbind;
      }
    }
    $outstart.="\n";
    $outstart="INTERFACE ".uc($unit_name)."\n".$outstart;

    $dump=~s/(?:[\"][\"]|[\'][\']|[\"][^\n\"]++[\"]|[\'][^\n\']++[\'])//g;
    $dump=~s/[\!][^\n]*+//g;
    $dump=~s/[\&][ \t]*+[\s\&]++//g;

#RJ: destroy unit declaration; simplifies a lot
    {
      unless($dump=~s/[\n].*\b(?:${unit_type}[ ]*+${unit_name})[^\n]*+//i) {
        die "failed to kill ${unit_type} ${unit_name}";
      }
    }

    my $typez="character|type|integer|real|double|complex|logical|use|external";
    my $stmtz="len|kind|intent|in|inout|out|precision";
#RJ:      my $stmta="dimension|size|parameter|allocatable|pointer|auto|save|optional|target|value|bind";
    my $stmta="dimension|size|parameter|allocatable|pointer|auto|save|optional";
    my $stmtb=$stmtz."|".$stmta."|".$typez;

 # warn $dump;
    my @lines;
    &slurp2array(\$dump,\@lines);

#RJ: allways include intrinsic modules

#RJ-temp: for now to detect empty module usages and not to fail on them, force ONLY! intrinsics too.
#RJ-remark: all modules should be splitted to data and method ones, then no probelm with assignment.
    my $dirty_uses='';
    my $allowed_dirty_uses='';
    $allowed_dirty_uses.=",CONTROL_VECTOR(CONTROL_VECTORS)";
    $allowed_dirty_uses.=",RANDOMNUMBERSTREAM(RANDOM_NUMBERS_MIX)";
    $allowed_dirty_uses.=",SPECTRAL_COLS(SPECTRAL_COLUMNS_MIX)";
    $allowed_dirty_uses.=",GRIDPOINT_FIELD(GRIDPOINT_FIELDS_MIX)";
    $allowed_dirty_uses.=",SPECTRAL_FIELD(SPECTRAL_FIELDS_MOD)";
    $allowed_dirty_uses.=",JB_CONTROL_VECTOR(JB_CONTROL_VECTORS_MOD)";
    $allowed_dirty_uses.=",NMXDCL(YOMCMA)";
    $allowed_dirty_uses.=",JPIM(PARKIND1)";
    $allowed_dirty_uses.=",JPRB(PARKIND1)";
    $allowed_dirty_uses.=",JPLIKB(LFI_PRECISION)";          #from ./src/xrd/fa/decf10.F90
    $allowed_dirty_uses.=",JPLIKM(LFI_PRECISION)";          #from ./src/xrd/fa/facade.F90
    $allowed_dirty_uses.=",JPDBLE(LFI_PRECISION)";          #from ./src/xrd/fa/facade.F90
    $allowed_dirty_uses.=",JPDBLR(LFI_PRECISION)";          #from ./src/xrd/fa/facade.F90
    $allowed_dirty_uses.=",NBUIMAX(MODD_BUDGET)";           #from ./src/mpa/micro/internals/cart_compress.F90
    $allowed_dirty_uses.=",NBUJMAX(MODD_BUDGET)";           #from ./src/mpa/micro/internals/cart_compress.F90
    $allowed_dirty_uses.=",NBUKMAX(MODD_BUDGET)";           #from ./src/mpa/micro/internals/cart_compress.F90
    $allowed_dirty_uses.=",JPJVMAX(MODD_CH_INIT_JVALUES)";  #from ./src/mpa/chem/internals/ch_interp_jvalues.F90
    $allowed_dirty_uses.=",JPXKRK(MODD_FMDECLAR)";          #from ./src/mse/internals/fm_read.F90
    $allowed_dirty_uses.=",DATE_TIME(MODD_TYPE_DATE_SURF)"; #from ./src/mse/internals/fmreadt0.F90
    $allowed_dirty_uses.=",SURF_SNOW(MODD_TYPE_SNOW)";      #from ./src/surfex/SURFEX/allocate_gr_snow.F90
    $allowed_dirty_uses.=",PRONOSVAR_T(MODD_TYPE_EFUTIL)";  #from ./src/surfex/SURFEX/build_pronoslistn.F90
    $allowed_dirty_uses.=",CMEM_FIELDS(YOMCMEMTYPES)";      #from ./src/sat/cmem/atm_sub.F90
    $allowed_dirty_uses.=",NFREQ(YOAMSU)";                  #from ./src/sat/emiss/e_grody.F90
    $allowed_dirty_uses.=",NSFC(YOAMSU)";                   #from ./src/sat/emiss/e_grody.F90
    $allowed_dirty_uses.=",KFGRID_TYPE(MOD_KFGRID)";        #from ./src/sat/emiss/kfgrid_delete.F90
    $allowed_dirty_uses.=",NBRESM(EXTR_MODULE_1C)";         #from ./src/odb/pandor/extrtovs/extr_lib_1c.F90
    $allowed_dirty_uses.=",REF_TOVS(EXTR_MODULE_1C)";       #from ./src/odb/pandor/extrtovs/extr_lib_1c.F90
    $allowed_dirty_uses.=",LONG(RAD_BIAS_1C_UTI)";          #from ./src/odb/pandor/extrtovs/regress_one.F90
#RJ: special case, maxvarlen is declared in odbshared.F90 but allow to be implicitly added from odb_module.F90
    $allowed_dirty_uses.=",MAXVARLEN(ODB_MODULE)";          #from ./src/odb/lib/odb_wrapper.F90
    $allowed_dirty_uses.=",C_INT(ISO_C_BINDING)";           #from ./src/odb/lib/odb_wrapper.F90
    $allowed_dirty_uses.=",C_CHAR(ISO_C_BINDING)";          #from ./src/odb/lib/odb_wrapper.F90
    $allowed_dirty_uses.=",C_BOOL(ISO_C_BINDING)";          #from ./src/odb/lib/odb_wrapper.F90
    $allowed_dirty_uses.=",C_PTR(ISO_C_BINDING)";           #from ./src/odb/lib/odb_wrapper.F90
    $allowed_dirty_uses.=",C_DOUBLE(ISO_C_BINDING)";        #from ./src/odb/lib/odb_wrapper.F90

#RJ-remark using intrinsics in dummy arguments could create some very funny stuff at runtime...
#RJ: some inbstrinsics might be skipped, if they are not some actual variables luckily...
    my $skip_intrinsics=',MAX,MIN,SIZE';

    my @use_types;
    my @use_vars;
    my @decl_types;
    my @decl_vars;
    my @partial_types;
    my @partial_vars;
    foreach my $line (@lines) {
      if($line=~/^(use[ ]*+(?:[,][ ]*+(?:non_)?+intrinsic[ ]*+)?+(?:[\:][\:][ ]*+)?+\b[\w]++[ ]*+[\,][ ]*+only)[ ]*+[\:][ ]*+([^\n]++)$/i) {
        push(@use_types,uc($1));
        my $ttt=$2;
        $ttt=~s/[ ]++//g;
        $ttt=~s/([\w]++(?:[\=][\>][\w]++)?+)/~$1/g;
        push(@use_vars,uc($ttt));
      }
      if($line=~/^use[ ]*+(?:[,][ ]*+(?:non_)?+intrinsic[ ]*+)?+(?:[\:][\:][ ]*+)?+(\b[\w]++)[ ]*+$/i) {
 # warn "Found dirty module '$1'";
        $dirty_uses.=",$1,";
      }
#RJ       elsif($line=~/^(?:integer|real|logical|character|type|complex|double precision)\b/i) {
#RJ       elsif($line=~/^(?:integer|real|logical|character|type[ ]*+[(]|complex|double precision)\b/i) {
      elsif(($line=~/^(?:integer|real|logical|character|type|complex|double[ ]++precision)\b/i) && ($line!~/^type[ ]++[\w]/i)) {
##RJ: extra safety, if type is 'TYPE' ensure that is 'TYPE(smth)'
#        if($line=~/^type\b/) {
#          unless($line=~/^type[ ]*+[(]/){
#            die "Warning[SLURP_INTFB]: local type declaration detected for dummy args, '$line', should be moved module";
#          }
#        }
        my $t1;
        my $t2;
        if($line=~s/^([^\:]++(?:[\:][^\:]++)*?)::([^\n]++)$//) {
          $t1=$1;
          $t2=$2;
        }
        elsif($line=~s/([ ]*+[\w]++[\s ]*+(?:[*][\s ]*+(?:[\w]++|$nest_par))?(?:[\s ]*+$nest_par|[\s ]*+[\,][\s ]*+[\w]++[\s ]*+)*+)//o) {
          $t1=$1;
          $t2=$line;
        }
        else {
  warn "Failed[SLURP_INTFB]: failed to strip variable type for $line";
            $$iret=-4;
            return;
        }
 # warn "typez: $t1";
 # warn "varz: $t2";
        $t2=~s/[ ]+//g;
#RJ:         $t2=~s/([\w]++(?:$nest_par)?+(?:[\=][\w\"\'\+\-\*\/\.]++|[\*][\w]++)?+)/~$1/g;
        $t2=~s/([\w]++(?:$nest_par)?+(?:[^\,]*+))/~$1/g;
        $t2=~s/[\,][\~]/~/g;
        push(@decl_types,uc($t1));
        push(@decl_vars,uc($t2));
 # warn "zzz: $t2";
      }
      elsif($line=~/^(?:external|$stmta)\b/i) {
        my $t1;
        my $t2;
        if($line=~s/^([^\:]++(?:[\:][^\:]++)*?)::([^\n]++)$//) {
          $t1=$1;
          $t2=$2;
        }
        elsif($line=~s/([ ]*+[\w]++[\s ]*+(?:[*][\s ]*+(?:[\w]++|$nest_par))?(?:[\s ]*+$nest_par|[\s ]*+[\,][\s ]*+[\w]++[\s ]*+)*+)//o) {
          $t1=$1;
          $t2=$line;
        }
        else {
  warn "Failed[SLURP_INTFB]: failed to strip variable type for $line";
            $$iret=-4;
            return;
        }
 # warn "typez: $t1";
 # warn "varz: $t2";
        $t2=~s/[ ]+//g;
#RJ:         $t2=~s/([\w]++(?:$nest_par)?+(?:[\=][\w\"\'\+\-\*\/\.]++|[\*][\w]++)?+)/~$1/g;
        $t2=~s/([\w]++(?:$nest_par)?+(?:[^\,]*+))/~$1/g;
        $t2=~s/[\,][\~]/~/g;
        push(@partial_types,uc($t1));
        push(@partial_vars,uc($t2));
      }
    }
#RJ:     my @solve_vars;
    my $solvevars='';
    foreach my $var (@unit_args) {
 # warn $var;
#RJ:       push(@solve_vars,uc($var));
      $solvevars.=",$var,";
    }
 # warn "solvevars= $solvevars";

 # warn Dumper(@use_vars);

    my $outuse='';
    my $outvar='';
    my $solved='';

#RJ:    foreach my $var (@solve_vars) {
    my $t_solve='';

    $t_solve.=$solvevars;
    if($unit_type eq 'function') {
      $t_solve.=",".uc($func_result_name).",";
      if($func_type_decl ne ''){
 #       $outvar.="$func_type_decl\n";
          push(@decl_types,uc($func_type_decl));
          push(@decl_vars,'~'.uc($func_result_name));
      }
    }
    while ($t_solve=~s/\b([A-Z][\w]*+)\b//) {
      my $var=$1;
      my $found_var=0;
 # warn "trying var '$var' $t_solve";
 # warn Dumper(@decl_types,@decl_vars);
      foreach my $ii (0..$#decl_vars) {
        if($decl_vars[$ii]=~/[\~]($var\b((?:$nest_par)?+[^\~]*+))/) {
 # warn $decl_vars[$ii];
          my $t1=$1;
          my $t2=$2;
 # warn "found var: $var";
#RJ: if parameter attr, add before
          if($decl_types[$ii]=~/[\,][ ]*+\bparameter\b/i) {
            $outvar=$decl_types[$ii].":: $t1\n".$outvar;
  #warn Dumper($ii,@decl_types);
          }
          else {
            $outvar.=$decl_types[$ii].":: $t1\n";
 # warn Dumper($ii);
 # warn Dumper(@decl_types);
 # warn Dumper(@decl_vars);
          }
          $solved.=",$var,";
          $found_var=1;
          if(defined($t2)) {
 # warn "dependencies: $t2";
            my $dep=$t2;
            $dep=~s/[\%][\w ]+(?:$nest_par)?+//g;
#RJ             $dep=~s%\b([A-Z][\w]*+)\b%if($deps!~/\b$1\b/){$deps.=",$1,";};""%eg;
            while($dep=~s/\b([A-Z][\w]*+)\b//) {
              my $ttt=$1;
              if(!(($solved=~/\b$ttt\b/) || ($t_solve=~/\b$ttt\b/))) {
                $t_solve.=",$ttt,";
              }
            }
          }
#RJ: safety check, for partial statements
          foreach my $jj (0..$#partial_vars) {
            my $tpart=$partial_vars[$jj];
            if($tpart=~/[\~]($var\b($nest_par)?+[^\~]*+)/) {
 #   die "partial statements detected for dummy arguments";
              $outvar.=$partial_types[$jj].":: $1\n";
            }
          }
          my $tdecl=$decl_types[$ii];
          $tdecl=~s/\b(?:$stmtb)\b//ig;
          $tdecl=~s/[,][ ]*+(?:(?:target|value)\b|(?:bind[ ]*+[(][ c]*+[)]))//ig;
          while($tdecl=~s/\b([A-Z][\w]*+)\b//) {
            my $ttt=$1;
            $ttt=~s/[\%][\w ]+(?:$nest_par)?+//g;
            if(!(($solved=~/\b$ttt\b/) || ($t_solve=~/\b$ttt\b/))) {
              $t_solve.=",$ttt,";
            }
          }
 # warn "decl_deps: $tdecl";
          last;
        }
      }

#RJ: try to look in USE statements
      if($found_var!=1) {
 # warn "trying var '$var' $t_solve";
        foreach my $ii (0..$#use_vars) {
          if($use_vars[$ii]=~/[\~]($var\b(?:[ ]*+[\=][\>][ ]*+[\w]++)?+)/) {
 # warn "found var: $var";
            $outuse.="${use_types[$ii]}: $1\n";
            $solved.=",$var,";
            $found_var=1;
            last;
          }
        }
      }

#RJ: if still no, try to look in DIRTY USE statements, have to be filled up before
      if($found_var!=1) {
 # warn "zzz:  $var, $allowed_dirty_uses";
        if($allowed_dirty_uses=~/$var[(]([\w]++)[)]/) {
          my $tmod=$1;
 # warn "zzz1: $tmod ";
          if($dirty_uses=~/\b$tmod\b/i) {
 # warn "found var: $var";
            $outuse.="USE $tmod,ONLY: $var\n";
            warn "Warning[SLURP_INTFB]: implicitly adding dirty 'use $tmod,only: $var' in unit $unit_name\n";
            $solved.=",$var,";
            $found_var=1;
          }
        }
      }

#RJ: even try to get partial statements 'AUX_PROC' in src/ald/transform/edir_trans_px.F90
      if($found_var!=1) {
 # warn "trying var '$var' $t_solve";
        foreach my $ii (0..$#partial_vars) {
          if($partial_vars[$ii]=~/[\~]($var\b($nest_par)?+)/) {
 # warn "found var: $var";
            $outvar.="${partial_types[$ii]}:: $1\n";
            $solved.=",$var,";
            if(defined($2)) {
              die "partial statement with nested argument detected";
            }
            $found_var=1;
          }
        }
      }

      if($found_var!=1) {
        if($skip_intrinsics=~/\b$var\b/) {
          warn "Warning[SLURP_INTFB]: variable '$var' treated as intrinsic in $unit_name\n";
        }
        else {
  warn "failed to solve var '$var'";
          $$iret=-5;
          return;
        }
      }
    }
#    warn Dumper("\n".$outuse);
#    warn Dumper("\n".$outvar);
    $t_solve=~s/[,]++//;
    if($t_solve ne '') {
  warn "Failure in t_solve: ".$t_solve;
      $$iret=-6;
      return;
    }

    $$output=$outstart;
    $$output.=$outuse;
    $$output.="IMPLICIT NONE\n";
    $$output.=$outvar;
    $$output.=$outend;

#RJ: continuate long lines, *should* be safe enough for intfbs
    while($$output=~s/[\n]([^\n\!]{79}[\w()]*+[^\n\&\,]*+[,])([ ]*+[\w])/\n$1&\n&$2/g) {
 # warn $1.$2;
    }

    $$iret=0;
 # warn Dumper(@decl_types);
 # warn Dumper(@decl_vars);
 # warn Dumper(@lines);
  }
}

#==========================================================================
#RJ: slurp whole file into single string, faster
sub slurpfile {
  my($fname,$dump)=@_;
  our (${f90s_VERBOSITY});
  if(!open(FH1,'<',$$fname)) {
    print STDERR "Can't open $$fname for slurping\n";
    die("Failed[SLURPFILE]: Can't open $$fname for slurping\n");
  }
  $$dump = do { local($/);<FH1>; };
  if($$dump=~s/[\r][\n]?/\n/g) {
    if(${f90s_VERBOSITY}>=2) {
      warn "Warning[SLURP]: MS (CR LF) style line endings detected and fixed\n";
    }
  }
  close(FH1);
}

#==========================================================================
#RJ: dump slurp into file, faster
sub slurp2file {
  my($fname,$dump)=@_;
  if(!open(FH2,'>',$$fname)) {
    print STDERR "Can't create $$fname for slurp dumping\n";
    die("Failed[SLURPFILE]: Can't create $$fname for slurp dumping\n");
  }
  {
    local($/);
    print FH2 $$dump;
  }
  close(FH2);
}

#==========================================================================
#RJ: split slurp to array
sub slurp2array {
  my($dump,$array)=@_;
  @$array= split(/^/,$$dump);
}

#==========================================================================
#RJ: slurp simple alternative code blocks commenter(non destructive)
#RJ: remark be carefull what you pass in def/undef strings, goes directly to regex
#RJ: on purpose doesn't handle 'DEF>5' and unspecified defines
#RJ: assumes legit cpp code
sub slurp_fpp {
  my($dump,$def,$undef)=@_;
  if(!defined($$dump) || !defined($$def) || !defined($$undef)) {
    die "slurp_fpp called without all three arguments"
  }
  {
    local $/;
#RJ: helpers
    my $cpp_def="zRJ";
    my $cpp_undef="Zrj";
    if($$def=~/[^ ]/) {
      $cpp_def=$$def;
    }
    if($$undef=~/[^ ]/) {
      $cpp_undef=$$undef;
    }
    $$dump="\n".$$dump;
    $$dump=~s/[\r][\n]?+/\n/g;
    $$dump=~s%[\n][#][ ]*+((?:el)*if[a-z]* [^\n]+)%my $t=$1;my $x=$t;$x=~s@ifndef[ ]+([a-z0-9__]++)@if !defined($1)@ig;$x=~s@ifdef[ ]+([a-z0-9__]++)@if defined($1)@ig;$x=~s@defined[ ]*([a-z0-9_]++)[ ]*@defined($1)@ig;$x=~s@[ ]*defined[ ]*[(][ ]*([a-z0-9_]++)[ ]*[)]@my $y=$1;if($y=~/^(?:$cpp_undef)$/){$y="0";}elsif($y=~/^(?:$cpp_def)$/){$y="1";}$y;@eig;my $xz="";while($xz ne $x){$xz=$x;$x=~s@[\!][ ]*0@1@g;$x=~s@[\!][ ]*1@0@g;$x=~s@0[ ]*[|]{2}@@g;$x=~s@[|]{2}[ ]*0@@g;$x=~s@1[ ]*[|]{2}[ ]*[01]@1@g;$x=~s@1[ ]*[&]{2}@@g;$x=~s@[&]{2}[ ]*1@@g;$x=~s@1[ ]*[&]{2}[ ]*1@1@g;$x=~s@0[ ]*[&]{2}[ ]*[01]@0@g;$x=~s@[(][ ]*([01])[ ]*[)]@$1@g;}$x=~s@^((?:el)?if)[ ]*1[ ]*$@\xaa$1t\;@;$x=~s@^((?:el)?if)[ ]*0[ ]*$@\xaa$1f\;@;$x=~s@^((?:el)?if).*+$@\xaa$1u\;@;"\n".$x."#".$t%eg;
    $$dump=~s/[\n]\xaaif/\n\xbf\xaaif/g;
    $$dump=~s/[\n][#][ ]*+else/\n\xaaelift;#else/g;
    $$dump=~s/[\n][#][ ]*+endif/\n\xbf\xaa;#endif/g;
    1 while($$dump=~s%([\n]\xbf\xaaif[^\xbf]+?(?=[\xbf][\xaa][\;][#]endif)[\xbf][\xaa][\;][#]endif)%my $x=$1;$x=~s/\xbf//g;if($x=~/\xaa[ ]*(?:el)*ifu/){$x=~s@\xaa[^\;]*+[;]@@g;}else{while($x=~/\xaa/){$x=~s&[\n]\xaa(?:el)*if([a-z])[\;]([^\xaa]++)([^\xff]++)&my $t=$1;my $y="\n".$2;my $z="\n".$3;$y=~s@[\n]$@@;if($t=~/t/){$z=~s@[\n]@\n\!zFPP @g;$y=~s@[\n]@\n\!zFPP @i;$x=$y.$z};if($t=~/f/){$y=~s@[\n]@\n\!zFPP @g;$x=$y.$z};$x&e;$x=~s@[\n][\!]zFPP \xaa[^\;]*+[\;]@\n\!zFPP @g;$x=~s@([\n][\xaa][\x00-\xff])@my $q=$1;if($q=~/^[\n][\xaa][;]$/){$q="\n\!zFPP "};$q@e;};$x=~s@[\n](?:[!]zFPP[ ])++@\n\!zFPP @g;};$x%eig);
    $$dump=~s/^[\n]//;
  }
}

#==========================================================================
#RJ: defpp, removes '!zFPP ' from lines
sub slurp_defpp {
  my($dump)=@_;
  {
    local $/;
    $$dump="\n".$$dump;
    $$dump=~s/[\n](?:[\!]zFPP[ ])++/\n/g;
    $$dump=~s/^[\n]//;
  }
}

#==========================================================================
#RJ: simple code cleaner
sub slurp_tidy {
  my($slurp)=@_;
  {
    local $/;
    my $dump="";
    $dump="\n\@\@\@\n".$$slurp."\n";

# line ending conversion to unix format, just in case
    $dump=~ s/[\r][\n]?+/\n/g;
# expand tabs similar like unix expand
#    I prefer expand till 6*N character since my laptop backspace is almost not responding, yup...
#    $dump=~ s/([\n][^\t\n]*[\t][^\n]*)/my $x=$1;1 while $x=~s&[\t]&" "x(6-(($-[0]-1)%6))&e;$x/eg;
    $dump=~ s/([\n][^\t\n]*[\t][^\n]*)/my $x=$1;1 while $x=~s&[\t]&" "x(8-(($-[0]-1)%8))&e;$x/eg;

# go to xeger mode
    $dump= reverse($dump);

# remove trailing spaces (in xeger)
    $dump=~ s/[\n][ ]+/\n/g;
# ensure only one empty line at the end of file (in xeger)
    $dump=~ s/^[\n]++/\n/;

# back to regex mode
    $dump= reverse($dump);

# remove start tag
    $dump=~s/^[\n][\@][\@][\@][\n]//;

    $$slurp=$dump;
  }
}

#==========================================================================
#RJ: simple slurp mode inliner(recursive,tagging,revertable)
#RJ: if include file is not found, inlcude directive is preserved
sub slurp_inc{
  my ($slurp)=@_;
  our (${f90s_VERBOSITY});
  my ($VPATH,@vpath);
  my $fname='';
  my $finc='';
  my $dump='';

    $VPATH=$ENV{VPATH} or die "Failed[SLURP_INC]: VPATH not defined ";
    @vpath=split(":",$VPATH);
  {
    local($/);
    $dump="\n".$$slurp;
    
#RJ: consider both cpp and native includes
    while($dump=~s/[\n]([ \#]*+(?:include|INCLUDE)[ ]*+[\"\'][ ]*+([^\s\'\"]++)[ ]*+[\"\'])/\n\x07$1/) {
      my $fname=$2;
      my $ffound=0;
#RJ: cycle through VPATH dirs
      my $ffname='';
      foreach my $path (@vpath) {
        $ffname=$path.'/'.$fname;
        if( -f $ffname) {
          $ffound=1;
          last;
        }
      }

      if( ($ffound==1) && ($ffname ne '') ) {
        my $islurp;
        &slurpfile(\$ffname,\$islurp);
        $dump=~s/[\x07]([^\n]++)/\!SLURP_INC $1\n${islurp}\n\!SLURP_INC_END $fname/;
      }
      else {
        if(${f90s_VERBOSITY}>=2) {
          warn "Warning[SLURP_INC]: include '$fname' not found in VPATH=$VPATH\n";
        }
        $dump=~s/[\x07]/\x08/;
      }
    }

    $dump=~s/[\x07\x08]//g;
    $dump=~s/^[\n]//;
    $$slurp=$dump;
  }
}

#==========================================================================
#RJ: simple slurp mode deinliner
sub slurp_deinc{
  my ($slurp)=@_;
  my $dump='';

  {
    local($/);
    $dump="\n".$$slurp;

    $dump=~s/[\n][\!]SLURP_INC/\n\x07/g;
    1 while($dump=~s/\x07[ ]([^\n]++[\n])[^\x07]++[\x07]_END[^\n]++[\n]/$1/g);

    $dump=~s/[\x07\x08]//g;
    $$slurp=$dump;
  }
}

#==========================================================================
#RJ: split array to slurp
sub array2slurp {
  my($array,$dump)=@_;
  $$dump=join('',@$array)
}

#==========================================================================
sub readfile  {
# Read file
  my($fname)=@_;
  my(@lines);
  if(!open(INFIL,$fname)) {
    print STDERR "Can't open $fname for reading\n";
    die("Failed[READFILE]: Can't open $fname for reading\n");
  }
  @lines=<INFIL>;
  close INFIL;
  (@lines);
}

#==========================================================================
sub writefile  {
# Write file
  my($fname,$lines)=@_;
  if(!open(OUTFIL,">".$fname)) {
    print STDERR "Can't open $fname for writing\n";
    exit;
  }
  print OUTFIL @$lines;
  close OUTFIL;
}

#==========================================================================
sub expcont {
#RJ: still very slow, needs rewrite, but with modiffications able to mostly work like intended
#
# Expand continuation lines into statements for free-format Fortran while
# maintaining line-breaking and all comments
# Put statements onto array of references to anonymous hashes as key 'statement'
# Also put into the hash the linenumber of first line of statement as key 'first_line'
  my($lines,$statements) = @_;
  my($statm,$prev,$rec,$line,$first_line);
  $prev=0;
  my $line_number=0;
  foreach $line (@$lines) {
    $_=$line;
    $line_number++;

#RJ: looks to be simple enough not to test several times, simplifying
#RJ     if(/^ *&/) {
#RJ       s/^( *)&(.*)$/$1$2/s;
#RJ ##      print " 1 $_";
#RJ     }
    unless(s/^[\&]//) {
      s/^([ \t]++)[\&]/$1/;
    }

#RJ: more complex version to detect more continuation and faster
#RJ: expand fails if continuated line has a trailing tab...
#RJ     if( !/^ *!.*$/ && /^.+&(?: *!.*)* *$/) {
#RJ-old     if( !/^[ \t]*[\!]/ && /^.+&(?: *!.*)*[ \t]*$/) {
#RJ-old     if( !/^[ \t]*[\!]/ && (/^(?:[^\&\!\n]++[\&])(?:[ \t]++|[\!][^\n]*+)*+$/) {
#RJ-old     if( !/^[ \t]*[\!]/ && (/^(?:[^\&\!\n]++[\&])(?:[ \t]++|[\!][^\n]*+)*+$/ || /^(?:[^\&\!\'\"\n]*+[\'\"][^\!\&\n]*+(?:[\!\n][^\&\n]*+|[\&][^\!\&\n]++)?+[&][ \t]*+)$/) ) {
#RJ-old    if( !/^[ \t]*[\!]/ && (/^(?:[^\&\!\n]++[\&])(?:[ \t]++|[\!][^\n]*+)*+$/ || /^(?:[^\&\!\'\"\n]*+[\'\"][^\!\&\n]*+(?:[\!\n][^\&\n]*+|[\&][^\!\&\n]++)?+[&][ \t]*+|[^\!\&\n\'\,]*+(?:[\, ]*+[\'][^\'\n]++[\']|[\, ]*+[^\!\&\n\'\,]++)*+[\,][ \t]*+[\&][ \t]*+)$/) ) {
#    if(!/^[ \t]*[\!]/ && /[\&]/) {
#      if( (/^(?:[^\&\!\n]++[\&])(?:[ \t]++|[\!][^\n]*+)*+$/ || /^(?:[^\&\!\'\"\n]*+[\'\"][^\!\&\n]*+(?:[\!\n][^\&\n]*+|[\&][^\!\&\n]++)?+[&][ \t]*+|[^\!\&\n\'\,]*+(?:[\, ]*+[\'][^\'\n]++[\']|[\, ]*+[^\!\&\n\'\,]++)*+[\,][ \t]*+[\&][ \t]*+)$/) ) {
      if(!/^[ \t]*[\!]/ && (/^(?:[^\&\!\n]++[\&])(?:[ \t]++|[\!][^\n]*+)*+$/ || /^(?:[^\&\!\'\"\n]*+[\'\"][^\!\&\n]*+(?:[\!\n][^\&\n]*+|[\&][^\!\&\n]++)?+[&][ \t]*+|[^\!\&\n\'\,]*+(?:[\, ]*+[\'][^\'\n]++[\']|[\, ]*+[^\!\&\n\'\,]++)*+[\,][ \t]*+[\&][ \t]*+)$/) ) {
#RJ: in this place assume that '&' is before '!' else assume '&' at the end
#RJ       s/(.+)&(.+)/$1$2/s;
#      unless(s/(.+)[\&]([ \t]*+[\!])/$1$2/s) {
#RJ         s/(.+)[\&]([ \t]*+)$/$1$2/s;
          unless(s/^([^\&\!\n]++)[\&]/$1/s) {
            s/[\&][ \t]*+$//;
          }
#      }
        $statm.=$_;
        $first_line=$line_number unless($prev);
        $prev=1;
##      print " 2 $_";
        next;
      }
#    }
#RJ     elsif($prev && /^ *!/) {
    elsif($prev && /^[ \t]*+[\!]/) {
      $statm.=$_;
##      print " 3 $_";
      next;
    }
    elsif($prev && /^[ \t]*+$/) {
##      print " 4 $_";
      next;
    }
    else {
##      print " 5 $_";
      $first_line=$line_number unless($prev);
      $statm.=$_;
#  warn "www: $_ www";
      {
        my $rec={};
        $rec->{'statement'}=$statm;
        $rec->{'first_line'}=$first_line;
        $rec->{'sha1'}=sha1_base64($statm);
#  warn "ttt:\n".Dumper($rec);
        push(@$statements,$rec);
      }
      $statm = "";
      $prev=0;
    }
  }
}
#==========================================================================

sub cont_lines {
#
# Put back continuation character in correct place and execute delayed actions
#
  my($statements,$lines,$line_hash) = @_;
  my(@temp,$i,$iup,$href);


# Put back continuation characters and split statements into lines as they were
  @$lines=();
  @$line_hash=();
  foreach $href (@$statements) {
    $_=$href->{statement};
    if (/\n.*\n/){                      # This is a multi-line statement
      @temp=split /\n/;                 # Split statement into lines (removes EOL)
      $iup=scalar(@temp);               # Number of lines in statement
      for ($i=0;$i < $iup;$i++) {       # Loop through lines
        $_=$temp[$i];
        if($i == 0 ){                   # First line
          if(/^([^!]+)(!.*)$/) {        # Line has trailing comment
            s/^([^!]+)(!.*)$/$1&$2\n/;  # Put back & at end of line before comment
          }
          else {                        # No trailing comment
            s/^([^!]+)$/$1&\n/;         # Put back & and EOL at end of line
          }
        }
        elsif ($i == ($iup-1)) {        # Last line
          s/^( *)(.*)$/$1& $2 \n/;      # Put back & at beginning of line
        }
        else {                          # Other lines
          if (/^ *!/) {                 # Line is comment line
            $_=$_."\n";                 # Restore EOL for comments
          }
          else {
            if(/^( *)([^!]*)(!.*)$/) {  # Line has trailing comment
              s/^( *)([^!]*)(!.*)*$/$1& $2&$3\n/;  # & at beginning and end of line
            }
            else {                      # No trailing comment
              s/^( *)([^!]*)$/$1& $2&\n/; # & at beggining and end of line
            }
          }
        }
        if($i == 0        && exists $href->{pre_insert}) {
          my @templines=split('\n',$href->{pre_insert});
          foreach my $tline (@templines) {
            my $rec={};
            $rec->{'content'}='unknown';
            $rec->{'line'}=$tline."\n";
            push(@$lines,$rec->{'line'});
            push(@$line_hash,$rec);
          }
        }
        unless(exists $href->{remove}) {
          my $rec={};
          $rec->{'line'}=$_;
          if($i == 0) {
            $rec->{'content'}=$href->{content};
          }
          else {
            $rec->{'content'}='cont_line';
          }
          push(@$lines,$rec->{'line'});
          push(@$line_hash,$rec);
        }
        if($i == ($iup-1) && exists $href->{post_insert}) {
          my @templines=split('\n',$href->{post_insert});
          foreach my $tline (@templines) {
            my $rec={};
            $rec->{'content'}='unknown';
            $rec->{'line'}=$tline."\n";
            push(@$lines,$rec->{'line'});
            push(@$line_hash,$rec);
          }
        }
      }
    }
    else {  # Not multiline statement
      if(exists $href->{pre_insert}) {
        my @templines=split('\n',$href->{pre_insert});
        foreach my $tline (@templines) {
          my $rec={};
          $rec->{'content'}='unknown';
          $rec->{'line'}=$tline."\n";
          push(@$lines,$rec->{'line'});
          push(@$line_hash,$rec);
        }
      }
      unless(exists $href->{remove}) {
        my $rec={};
        $rec->{'line'}=$_;
        $rec->{'content'}=$href->{content};
        push(@$lines,$rec->{'line'});
        push(@$line_hash,$rec);
#        print $rec;
      }
      if(exists $href->{post_insert}) {
        my @templines=split('\n',$href->{post_insert});
        foreach my $tline (@templines) {
          my $rec={};
          $rec->{'content'}='unknown';
          $rec->{'line'}=$tline."\n";
          push(@$lines,$rec->{'line'});
          push(@$line_hash,$rec);
        }
      }
    }
  }
}
#==========================================================================
sub getvars {
# Return list of locally declared variables with type and scope information
#
  my ($statements,$prog_info,$vars,$use_vars) = @_;
  our (${f90s_VERBOSITY});
  my ($test,$type,@vars1,$func,$prog_unit,$dum,$tmp_name,@pu_args);
  my ($preserve,$rank,$href);
#RJ: adding extra variable to be tad more 'lenient' on implicit typing cases
  our($nest_par,$name,${f90s_FORGIVE_ME});

  %$vars=();
  $func="";
  $prog_unit=0;
  %$use_vars=();
  foreach $href (@$statements) {
    next if($href->{content} eq 'comment');           # Skip comments
    next if($href->{exec});                        # Don't look in executable statements
    next if($$prog_info{is_module} and ! $href->{in_contain}); # Unless inside CONTAIN skip module
    $prog_unit=$href->{prog_unit};
    if($href->{content} eq 'FUNCTION') {
      $_=$href->{statement};
      my $dum=&parse_prog_unit(\$func,\@pu_args);          # Get name of FUNCTION
#      print "GETVARS FUNCTION $func \n";
      $func=uc($func);
    }
    if($href->{decl} == 2 or $href->{content} eq 'EXTERNAL'){  # Real parse starts
      $_=$href->{statement};
      $_=uc($_);                                   # Upcase to avoid /.../i
#RJ       s/^ *//;                                     # remove leading blanks
      s/^[ ]++//;                                  # remove leading blanks
      if($href->{decl} == 2) {
        $type=lc(substr($href->{content},0,1));
#RJ: in case there are still some double prec declarations, assume it is a real -> 'r'
        if($href->{content} eq "DOUBLE PRECISION"){
          $type='r';
        }
#RJ: adding new externalized attribute to detect external functions early
        if(defined($href->{externalized}) && ($href->{externalized}>0)) {
          $type='e';
        }
      }
      else {
        $type='e';
      }
      s/\!.*\n/\n/g;                               # Remove trailing comments in all lines
      $preserve=$_;
#RJ: this one is dangerous, variable might be defined without "::"
#RJ       s/(.+)::(.+)/$2/s;                           #REAL(KIND=JPRB) :: zsig(:) -> zsig(:),
#RJ: using simplest form that I use, that deals with these:
                                                   #REAL (KIND=JPRB) , intent(inout) ,save  zsig(:) -> zsig(:)
                                                   #REAL*8  , intent(inout) ,save  zsig(:) -> zsig(:)
                                                   #REAL    zsig(:) -> zsig(:)
                                                   #REAL :: zsig(:) -> zsig(:)
                                                   #EXTERNAL zsig(:) -> zsig(:)
                                                   #INTEGER (KIND=JPLIKB) IISMAX_1 -> IISMAX_1
#RJ: also looks like '&' are stripped already so include \n to whitespaces YGDFAGIOT_ARGS issue
#RJ-clean      s/^(?:.*?::|[ ]*[\w]++(?:[*][\w]++)?[ ]*(?:[ ]*[(][^)]++[)]|[ ]*[,][ ]*[\w]++)*)//;
      my $t_strip=$_;
#RJ: try "::" case first
      unless ($t_strip=~s/^[^\:]++(?:[\:][^\:]++)*?:://) {
#RJ: if failed still try non "::" case
#RJ: I know it ain't pretty, but does the job and it is still fast'ish
#RJ-old         unless ($t_strip=~s/[ ]*[\w]++(?:[*][\w]++)?[ \n]*(?:[ \n]*[(][^)]++[)]|[ \n]*[,][ \n]*[\w]++)*//) {
#RJ-old         unless ($t_strip=~s/[ ]*+[\w]++[\s ]*+(?:[*][\s ]*+(?:[\w]++|$nest_par))?(?:[\s ]*+$nest_par|[\s ]*+[\,][\s ]*+[\w]++[\s ]*+$nest_par)*+//o) {
        unless ($t_strip=~s/[ ]*+[\w]++[\s ]*+(?:[*][\s ]*+(?:[\w]++|$nest_par))?(?:[\s ]*+$nest_par|[\s ]*+[\,][\s ]*+[\w]++[\s ]*+)*+//o) {
#RJ: die
          die "Failed[GETVARS]: failed to strip variable type for $t_strip";
        }
      }
#RJ-delete: nolonger needed
#RJ: override type if var dec has 'external' attribute, for now here, later disable, perf penalty
#RJ: should be done before, when parsing type and matched with $href->{content} eq 'EXTERNAL'
#RJ       if(/\bEXTERNAL\b/) {
#RJ         $type='e';
#RJ       }

      $_=$t_strip;
#RJ: above one does EXTERNAL too
#RJ       s/^EXTERNAL (.+)$/$1/;
      s/\s+//g;                                    # Remove all white-space
      if($href->{content} eq 'CHARACTER') {
#RJ: expand with spaces
#RJ         s/($name)\*\d+/$1/g;
        s/($name)[\s ]*+[\*][\s ]*+[\d]++/$1/g;
#RJ         s/($name)\*$nest_par/$1/g;
        s/($name)[\s ]*+[\*][\s ]*+$nest_par/$1/g;
#RJ         s/($name)$nest_par\*\w+/$1/g;
        s/($name)[\s ]*+$nest_par[\s ]*+[\*][\s ]*+[\w]++/$1/g;
      }
#RJ-remark ensure that next one is very greedy, for now will do but there might be cases like 'real :: a(2)=/1,2/,b(2,2)=/ /5,2/ ,/5,2/ /'
      s#=\(/.+/\)##;      # ZVAL(1:2)=(/1.0,2.0/) -> ZVAL(1:2)
#?      s/=[^,\n]+//g;
      s/$nest_par//g;     # ISEC3(SIZE(NSEC3)),ISEC4(SIZE(NSEC4)) -> ISEC3,ISEC4
#RJ        s/=\w+//g;          # ZVAL=1.0 -> ZVAL
#RJ: trim '=smth', generalization, avoid touching '(),', but trim 'CHARACTER(LEN=*), PARAMETER :: MYNAME = MODNAME//' (SET_VARBCIX)'
      s/[\=][^,()]++(?:[\/][\/][^,()]++)?//g;
 # warn "zzz: $_";
#RJ: adding extra case for xrd/lfi/lfilcc.F90 'CHARACTER CDTAB (LFI%JPNXNA*KFACTM)*(LFI%JPNCPN)'
      if(s/[\+\-\*\/]//g) {
        if(${f90s_VERBOSITY}>=2) {
          warn "Warning[GETARGS]: too ambiguous, pos missing parentheses for '$preserve'\n";
        }
      }
#RJ: dangerous, disabling
#RJ       s@/.*/@@;           # What?
 # warn "zzs: $_\n".Dumper(%$vars);
      @vars1=split(',',$_);
      for(@vars1) {
        next unless /^$name$/;          # A bit of security
#RJ-temp
#RJ: adding warning on variable redefining, mainly in contains->{sub a; sub b}
#RJ         if(defined($$vars{$_})) {
#RJ           warn "Warning[GETARGS]: variable '$_' redefining detected";
#RJ         }
        $$vars{$_}{statement}=$href;
        if($preserve =~ /\b$_\b *\(/ | $preserve =~ /DIMENSION/) {
          $rank=1;        # Variable is array
        }
        else {
          $rank=0;        # Variable is scalar
        }
        if($_ eq $func) {
          $$vars{$_}{type_spec}="f";
        }
        else {
          if($href->{content} eq 'FUNCTION') {
            $$vars{$_}{type_spec}='f';
          }
          else {
            $$vars{$_}{type_spec}=$type;
          }
        }
        $$vars{$_}{scope}=$prog_unit;
#RJ: if unit has several units in contains and one of them had rank=1 don't downgrade to scallar
#RJ: to bypass function name, hack, simply if variable name in main unit is named, it shouldn't be external function ;)
        unless(defined($$vars{$_}{rank}) && $$vars{$_}{rank}>0){
          $$vars{$_}{rank}=$rank;
        }
        $$vars{$_}{usage}='local';
      }
    }
# Perhaps the variable is really a statement function?
    if($href->{decl} == 5) {
      $_=$href->{statement};
      s/\s+//g;                                    # Remove all white-space
#RJ: this should not be used implicitly, gives "Use of uninitialized value...", wrapping into some logic
#RJ:      /^($name)\((.+)\)=/i;
      if(/^($name)\((.+)\)=/i) {
        my $tvar=uc($1);
        my @stmf_args=split(',',$2);
        if (exists($$vars{$tvar})) {
          $$vars{$tvar}{type_spec}='s';
#            print "STATMF OK $tvar \n ";
        }
        for (@stmf_args) {
          if (exists($$vars{$_})) {
            $$vars{$_}{type_spec}='s';
#            print "STATMF ARG OK $_ \n ";
          }
        }
      }
      else {
        die "Failed[GETVARS]: something else - $_";
      }
    }
  }
 #  warn "zzs: $_\n".Dumper(%$vars);

# Perhaps instead the variable is a declaration of an external function?
  my @extract=();                  # Extract part of statements for efficiency
  foreach $href (@$statements) {
    if($href->{exec}) {                 # Function call must be in executable stat.
      next if($href->{content} eq 'CALL'); # A call can't contain an undeclared function
      push(@extract,$href->{statement});
    }
  }

#RJ: this has nasty random feature of turning variables to functions, e.g. 'write(io,*)"Pipecmd(unfiltered):"//pipecmd' for pipecmd
#RJ: force sorting of keys, reproducible reports
#RJ   foreach my $var (keys (%$vars)) {
 # warn Dumper(%$vars);
 # warn Dumper($$vars{'ILENS'});
  foreach my $var (sort(keys (%$vars))) {
#RJ-debug  warn "found $var";
    next if($$vars{$var}{rank} > 0);   # Can't be a function if rank > 0
#RJ: extra case for 'FUNC' in qgaus.F90, that is declared as external
#    next if($$vars{$var}{type_spec} eq 's' | $$vars{$var}{type_spec} eq 'f');
    next if($$vars{$var}{type_spec} eq 's');
    next if($$vars{$var}{type_spec} eq 'f');
    next if($$vars{$var}{type_spec} eq 'e');
#RJ: type(TYPE) functions are very rare, thus don't assign here, or should be used?
    next if($$vars{$var}{type_spec} eq 't');
    my $dec_unit=$$vars{$var}{scope};
#RJ: avoid cases like "ICOD=YRQGFP%ICOD(JF)" here with '[^\%]?+', relatively cheap, but check in 2nd pass for speed
#RJ     my $regex1=qr/\b$var\b\s*\(/i;      # As var's rank=0 this could be function call
    my $regex1=qr/\b$var\b\s*\(/i;    # As var's rank=0 this could be function call
    for(@extract) {
      if(/${regex1}/) {
#RJ: cheaper version
#RJ         s/\!.*\n/\n/g;                       # Remove trailing comments in all lines
        s/[\!][^\n]*+//g;                       # Remove trailing comments in all lines
        s/[\s]++//g;                            # Remove all white-space
#RJ: check for %var case here
        if(/[^\%]?+${regex1}/) {
          if($$vars{$var}{type_spec} eq 'c') {   # Avoid CLVAR(1:3) etc.
#  warn "zzz: $_";
#RJ: generalize for case "CLNOMA=CDNOMA(1:MIN(16,LEN(CDNOMA)))" in cchien.F90
#RJ: generalize even more to catch CENV(i+5:) cases
#RJ             next if(/${regex1}\s*(\d+|$name)*\s*:\s*(\d+|$name)*\s*\)/);
            next if(/${regex1}\s*[^\:\,\n]*+[\:]/);
          }
          my $t_temp=$_;
#RJ: workaround for nasty random bug 'write(io,*)"Pipecmd(unfiltered):"//pipecmd' for pipecmd
#RJ: other case "WRITE(KULOUT,*) 'PLAT0 (rd) = ',PLAT0,'PLAT0 (dg) = ',PLAT0*ZRTD"
          $t_temp=~s/(?:[\"][\"]|[\'][\']|[\"][^\"\n]++[\"]|[\'][^\'\n]++[\'])//g;
          next unless $t_temp=~/${regex1}/;
#          print "TYPE changed to function $var $_ \n";
          if(${f90s_VERBOSITY}>=2) {
            warn "Warning[GETARGS]: pos missing 'EXTERNAL' attr, TYPE changed to function for var '$var' $_\n";
          }
          $$vars{$var}{type_spec}='f';
          last;
        }
      }
    }
  }
# ---------------------------------------------------------------------
# Assign  "usage" in Doctor sense to variable (default usage is 'local')
#
  foreach $href (@$statements) {
# Is the variable a dummy argument
    if($href->{content} eq 'FUNCTION' or $href->{content} eq 'SUBROUTINE') {
      $_=$href->{statement};
      @pu_args=();
      my $dum=&parse_prog_unit(\$func,\@pu_args);   # Get arguments
      for(@pu_args) {
        if( exists $$vars{$_} ) {
          if($$vars{$_}{scope} == $href->{prog_unit}) {
            $$vars{$_}{usage}='arg';
          }
        }
        else {
          print STDERR "Argument $_ has not got a corresponding declaration statement\n";
          print "Argument $_ has not got a corresponding declaration statement\n";
#RJ: sometimes it is useful just to get a warning here
          unless(defined(${f90s_FORGIVE_ME}) && (${f90s_FORGIVE_ME}!=0)) {
            print "Bailing out at this point\n";
            die "Failed[GETVARS]: Bailing out";
          }
          else {
            if(${f90s_VERBOSITY}>=2) {
              warn "Warning[GETARGS]: not bailing for '$_' in unit $func due to FORGIVE_ME";
            }
          }
        }
      }
    }
# Does the variable appear in a NAMELIST
# We want to distinguish this for more lenient Doctor check
    if($href->{content} eq 'NAMELIST') {
      $_=$href->{statement};
      s/\!.*\n/\n/g;     # Remove trailing comments in all lines
      s/\s+//g;          # Remove all white-space
#RJ: this doesn't feel right, looks like only variables are needed, thus stripping is easier and no warnings
#RJ-fix Use of uninitialized value $1 in uc at Fortran90_stuff.pm
#RJ       m:NAMELIST/\w+/(.+):;
      s%NAMELIST/\w+/%%;
#RJ       my @namvars=split(',',uc($1));
      my @namvars=split(',',uc($_));
      for (@namvars) {
        if( exists $$vars{$_} ) {
          if($$vars{$_}{scope} == $href->{prog_unit}) {
            $$vars{$_}{usage}='namvar';
          }
        }
      }
    }
    if(exists $href->{inc_statm}) { # We also have to look in include files
      my $incs=$href->{inc_statm};
      foreach my $hrefi (@$incs) {
        if($hrefi->{content} eq 'NAMELIST') {
          $_=$hrefi->{statement};
          s/\!.*\n/\n/g;     # Remove trailing comments in all lines
          s/\s+//g;          # Remove all white-space
#RJ: this doesn't feel right, looks like only variables are needed, thus stripping is easier and no warnings
#RJ-fix Use of uninitialized value $1 in uc at Fortran90_stuff.pm
#RJ       m:NAMELIST/\w+/(.+):;
          s%NAMELIST/\w+/%%;
#RJ           my @namvars=split(',',uc($1));
          my @namvars=split(',',uc($_));
          for (@namvars) {
            if( exists $$vars{$_} ) {
              if($$vars{$_}{scope} == $href->{prog_unit}) {
                $$vars{$_}{usage}='namvar';
              }
            }
          }
        }
      }
    }
  }
# -----------------------------------------------------------------------------
# Find use variables
  my %use_count=();
  foreach $href (@$statements) {
    if($href->{content} eq 'USE') {
      $prog_unit=$href->{prog_unit};
      $_=$href->{statement};
      s/\!.*\n/\n/g;                               # Remove trailing comments in all lines
      s/\s+//g;                                    # Remove all white-space
#RJ-temp: for now will do, but might break intfb generation if any varaible is locally renamed yet used dor decl
#RJ: maybe variable is locally renamed "=>"? assuming whitespaces are already stripped
      s/[\=][\>][\w]++//g;
      $_=uc($_);                                   # Upcase to avoid /.../i
      if(/^USE($name),ONLY:(.+)$/){
        my $modname=$1;
        if( exists $use_count{$modname}) {
          if($prog_unit == $use_count{$modname}) {
            print "-> $href->{statement}";
            print "USE $modname appears more than once in program unit $prog_unit \n\n";

          }
        }
        $use_count{$modname} = $prog_unit;
        my @usevars = split /,/ ,$2;
        my %usevars=();
        foreach my $usevar (@usevars) {
          $usevars{$usevar}++;
          $$use_vars{$usevar}{statement}=$href;
          $$use_vars{$usevar}{module}=$modname;
          $$use_vars{$usevar}{scope}=$prog_unit;
          $$use_vars{$usevar}{count}++;
        }
#RJ: force sorting of keys, reproducible reports
#RJ         foreach my $usevar (keys (%usevars)) {
        foreach my $usevar (sort(keys (%usevars))) {
          if($usevars{$usevar} >1) {
            print "DUPLICATE USE ONLY VARIABLE ","$modname $usevar $prog_unit \n";
            $_=$href->{statement};
            s/\b$usevar\b//i;
            s/,\s*,/,/;
            s/,\s*\n$/\n/;
            s/\n *\n/\n/;
            s/^(.+:\s*),/$1/;
            $href->{statement}=$_;
          }
        }
      }
      else {
#        print "WARNING:USE without ONLY \n";
      }
    }
  }
}
#==========================================================================
sub find_unused_vars {
# Find declared variables not used
  my($statements,$vars,$unused_vars,$use_vars,$unused_use_vars) = @_;
  my ($var,@tokens,$href);
  @tokens=();
# Find all tokens in file
  foreach $href (@$statements) {
    next if($href->{content} eq 'comment');
    if(exists $href->{inc_statm}) {  # Look also in include files
      my $incs=$href->{inc_statm};
      foreach my $hrefi (@$incs) {
        die "Failed[FUV]: $href->{content} $href->{statement}" unless exists $hrefi->{statement};
        $_=$hrefi->{statement};
        if(/\b[a-zA-Z]\w*\b/) {
          push(@tokens,/\b[a-zA-Z]\w*\b/g);
        }
      }
    }
    else {
      $_=$href->{statement};
      push(@tokens,/\b[a-zA-Z]\w*\b/g);
    }
  }
  @tokens= map {uc} @tokens; # Upcase array of tokens, the variables are upper-case

# Find out how many times the variable appears in array tokens
#RJ: force sorting of keys, reproducible reports
#RJ   foreach $var (keys (%$vars)) {
  foreach $var (sort(keys (%$vars))) {
    $$vars{$var}{uses}=0;
  }
#RJ: force sorting of keys, reproducible reports
#RJ   foreach $var (keys (%$use_vars)) {
  foreach $var (sort(keys (%$use_vars))) {
    $$use_vars{$var}{uses}=0;
  }
  for (@tokens) {
    if(exists($$vars{$_})){
      $$vars{$_}{uses}++;
    }
    if(exists($$use_vars{$_})){
      $$use_vars{$_}{uses}++;
    }
  }
# If it appears only one time (which must be in a declaration) it is unused
  @$unused_vars=();
#RJ: force sorting of keys, reproducible reports
#RJ   foreach $var (keys (%$vars)) {
  foreach $var (sort(keys (%$vars))) {
    push(@$unused_vars,$var) if($$vars{$var}{uses} < 2);
  }
  @$unused_use_vars=();
#RJ: force sorting of keys, reproducible reports
#RJ   foreach $var (keys (%$use_vars)) {
  foreach $var (sort(keys (%$use_vars))) {
    push(@$unused_use_vars,$var) if($$use_vars{$var}{uses} < 2);
  }
}
#==========================================================================
sub remove_unused_vars {
# Does what it says on the tin
  my($statements,$unused_vars,$unused_use_vars) = @_;
  my ($var,$href);
  our $nest_par;
  for (@$unused_vars) {
    $var=$_;
    foreach $href (@$statements) {
      $_=$href->{statement};
      next unless(($href->{decl}) | ($href->{content} eq 'comment'));
      if($href->{content} eq 'comment') {
        next unless(/^ *!\$OMP/);
      }
      if(/\b$var\b/i) {
#        print $_;

        if(/\b$var\b *\(/i) {
#          print "ZYZ $var $_";
          s/\b$var\b *$nest_par *(=\s*\(\/.*\/\))*//si;
#          print "ZZZ $var $_";
        }
        s/\b$var\b\s*=\s*\d+(\.\d*)*//i;
        s/\b$var\b *(\* *\d+)*//i if($href->{content} eq 'CHARACTER') ;
        s/\b$var\b//i;
#        print $_;
        s/^.+:: *\n$//;
        s/^.+:: *\!.*\n$//;
#        print $_;
        s/,\s*,/,/;
#        print $_;
        s/, *\n$/\n/;
#        print $_;
        s/(::\s*),(.+)$/$1$2/s;
        s/\n *\n/\n/;
        s/\n *!.*\n/\n/;
        s/, *\n$/\n/;
# Remove "empty" lines
        s/^.+::\s*$//;
        s/^.+::\s*=.*$//;
        s/^.+::\s*!.*$//;
#        print $_;
        s/^CHARACTER *\*\d+ *\n$//i if($href->{content} eq 'CHARACTER') ;
        $href->{statement}=$_;
      }
    }
  }
  for (@$unused_use_vars) {
    $var=$_;
    foreach $href (@$statements) {
      next unless($href->{decl} == 4);
      $_=$href->{statement};
      next if(/PARKIND/); #I am sure this could be done betterh

      if(/\b$var\b/i) {
        s/\b$var\b//i;
        s/,\s*,/,/;
        s/,\s*\n$/\n/;
        s/\n *\n/\n/;
        s/^(.+:\s*),/$1/;
        s/^.+:\s*$//;
        $href->{statement}=$_;
      }
    }
  }
}
#==========================================================================
sub tidy_decl {
# Tidy up declarions
  my($statements) = @_;
  my($href,$content);

  foreach $href (@$statements) {
    next unless($href->{decl} == 2);
    $_=$href->{statement};
    $content=$href->{content};

    if($content eq 'CHARACTER') {
      s/CHARACTER *\* *(\w+)/CHARACTER \(LEN = $1\)/i;
      s/CHARACTER *\* *\(\*\)/CHARACTER \(LEN = \*\)/i;
      s/CHARACTER *\* *\( *(\w+) *\)/CHARACTER \(LEN = $1)/i;
    }
    if($content eq 'INTEGER') {
      if(/^ *INTEGER[^\(]/i) {
        s/INTEGER\b/INTEGER(KIND=JPIM)/;
      }
    }
    unless (/::/) {
      s/^( *LOGICAL )/$1:: /i;
      s/^( *INTEGER\(KIND=JPI\w\) )/$1:: /;
      s/^( *REAL\(KIND=JPR\w\) )/$1:: /;
      if(/^ *CHARACTER/i) {
        if( s/^( *CHARACTER *\( *LEN *= *\w+ *\))/$1 :: /i) {
          $href->{statement}=$_;
          next;
        }
        if(s/^( *CHARACTER *\( *LEN *= *\* *\))/$1 :: /i) {
          $href->{statement}=$_;
          next;
        }
        s/^( *CHARACTER )/$1:: /i;
      }
    }
    $href->{statement}=$_;
  }
}
#==========================================================================

sub doctor_viol {
# Find Doctor violations

  my($vars,$fix_doc) = @_;
  my ($var,$type,$zz,$prog_unit,$usage);
  %$fix_doc=();

#RJ: force sorting of keys, reproducible reports
#RJ   foreach $var (keys (%$vars)) {
  foreach $var (sort(keys (%$vars))) {
    $type=$$vars{$var}{type_spec};
    $prog_unit=$$vars{$var}{scope};
    $usage=$$vars{$var}{usage};
#    print "DOC $var $type $prog_unit $usage \n";
    if($zz=&doc_char($type,$usage,$var)) {
#      print "DOCTOR VIOL - ",$var," $type $zz $prog_unit\n";
      $$fix_doc{$var}=$zz.'_'.$var.','.$prog_unit;
    }
  }
}
#==========================================================================

sub doctor_viol_v2 {
# Find Doctor violations

  my($vars,$fix_doc) = @_;
  my ($var,$type,$zz,$prog_unit,$usage);
  %$fix_doc=();

#RJ: force sorting of keys, reproducible reports
#RJ   foreach $var (keys (%$vars)) {
  foreach $var (sort(keys (%$vars))) {
    $type=$$vars{$var}{type_spec};
    $prog_unit=$$vars{$var}{scope};
    $usage=$$vars{$var}{usage};
#    print "DOC $var $type $prog_unit $usage \n";
    if($zz=&doc_char($type,$usage,$var)) {
#      print "DOCTOR VIOL - ",$var," $type $zz $prog_unit\n";
      $fix_doc->{$var}={prefix=>$zz,
                       var=>$var,
                       prog_unit=>$prog_unit,
                       statement=>$$vars{$var}{statement},
                      };
    }
  }
}
#==========================================================================
sub fix_doctor_viol {
# Fix Doctor violations
  my($statements,$fix_doc) = @_;
  my($doc_viol,$repl,$prog_unit,$cur_prog_unit,@allowed,$href,$content);
  my($tmp_name,@pu_args);

  @allowed=('NRGRI'); # Hack

  VIOL:foreach $doc_viol (keys (%$fix_doc)) {
    # Let's allow some violations
    for (@allowed){
      next VIOL if($doc_viol eq $_);
    }

    ($repl,$prog_unit)=split(',',$$fix_doc{$doc_viol});

    print "FIX $repl $prog_unit \n";
    foreach $href (@$statements) {
      $content=$href->{content};
      $_=$href->{statement};
      if($href->{content} eq 'comment') {
        next unless(/^ *!\$OMP/);
      }
      $cur_prog_unit=$href->{prog_unit};
      if($prog_unit == $cur_prog_unit) {  # Could be fine in other program units
        if(/\b$doc_viol\b/i) {
          s/%$doc_viol\b/_X_$doc_viol/ig; # Protect type-components
          s/\b$doc_viol\b/$repl/ig;
          s/_X_$doc_viol\b/%$doc_viol/ig; # Restore type-components
        }
      }
      $href->{statement}=$_;
    }
  }

}
#==========================================================================
sub various{
#
  my($statements,$prog_info,$vars) = @_;
  my($punit,@args,$tmp_name,$cont,$statm);
  my($href,$exec);
  our $nest_par;
#------------------------------------------------------------------
# Remove unneccesary RETURN statement
  foreach $href (@$statements) {
    $cont=$href->{content};
    if($cont eq 'RETURN') {
      if($href->{exec} == 3) {   # $href->{exec} == 3 means last executable statement
        $href->{remove} = 1;     # Post remove line for later
      }
    }
  }


# Make sure all CALL MPL_... has a CDSTRING argument
  foreach $href (@$statements) {
    $cont=$href->{content};
    if($href->{content} eq 'CALL' ) {
      $_=$href->{statement};
      if(/^\s*CALL\s+MPL_/i) {
        next if(/^\s*CALL\s+MPL_ABORT/i);
        next if(/^\s*CALL\s+MPL_WRITE/i);
        next if(/^\s*CALL\s+MPL_READ/i);
        next if(/^\s*CALL\s+MPL_OPEN/i);
        next if(/^\s*CALL\s+MPL_CLOSE/i);
        next if(/^\s*CALL\s+MPL_INIT/i);
        next if(/^\s*CALL\s+MPL_GROUPS_CREATE/i);
        next if(/^\s*CALL\s+MPL_BUFFER_METHOD/i);
        next if(/^\s*CALL\s+MPL_IOINIT/i);
        next if(/^\s*CALL\s+MPL_CART_COORD/i);
#        print "CDSTRING=$$prog_info{'unit_name'}[$href->{prog_unit}]: \n";
        unless(/CDSTRING\s*=/i) {
          s/\)(\s)$/,CDSTRING=\'$$prog_info{'unit_name'}[$href->{prog_unit}]:\'\)$1/;
          $href->{statement}=$_;
        }
      }
    }
  }



#------------------------------------------------------------------
# Add Standard Modification Line

  my $start=0;
  foreach $href (@$statements) {
    $cont=$href->{content};
    if($cont eq 'comment') {
      $_=$href->{statement};
      if($start) {                        # Found header - look for end of mod lines
        if(/^ *$/ || /^! *------------------------/) {
          $href->{pre_insert} = "!        M.Hamrud      01-Oct-2003 CY28 Cleaning\n";
          last;
        }
        next;
      }
      $start=1 if(/^! +Modifications/i) ;  # This how the header should look
      next;
    }
    last if($href->{exec});                # We have failed - bail out
  }

# Change subroutine and call multi-line statements so that the comma
# beetwen variables comes at the end of the line
  my @lines=();
  foreach $href (@$statements) {
    if(exists $href->{multi_line}) {
      $cont=$href->{content};
      if($cont eq 'SUBROUTINE' | $cont eq 'CALL' ) {
        $statm=$href->{statement};
        @lines=split "\n", $statm;
        @lines = reverse @lines;
        my $append_comma=0;
        for (@lines) {
#          print "A $append_comma $_ \n";
          next if(/^ *!/);
          if($append_comma) {
            if(/\S *!.*$/) {
              s/(\S)( *!.*)$/$1,$2/;
            }
            else {
              s/(\S) *$/$1,/;
            }
          }
          $append_comma=s/^ *,//;
#          print "B $append_comma $_ \n";
        }
        @lines = reverse @lines;
        $statm=join  "\n",@lines;
        $statm=$statm."\n";
        $href->{statement}=$statm;
      }
    }
  }
  our $name;
  foreach $href (@$statements) {
    if($href->{content} eq 'USE') {
      $_=$href->{statement};
      unless(/^\s*USE\s+$name\s*,\s*ONLY\s*:/i){
        print $_;
        print "Warning[VARIOUS]: USE without ONLY \n";
      }
    }
  }
}
#==========================================================================
sub insert_hook{
#
  my($statements,$prog_info,$vars) = @_;
  my($punit,@args,$tmp_name,$cont,$statm);
  my($href,$exec);
  our $nest_par;
#------------------------------------------------------------------
# Add HOOK function
  my $unit_name='';
  my $last_use=0;
  my $hook_status=0;
  my $in_contain=0;
  my $prev_prog=0;
  my ($decl,$remember);
  foreach $href (@$statements) {
    $cont=$href->{content};
    next if($cont eq 'comment');

    $decl=$href->{decl};
    $exec=$href->{exec};
    $in_contain=$href->{in_contain};
    if(! $in_contain and $href->{prog_unit} > $prev_prog) {
      $hook_status=0;
      $prev_prog=$href->{prog_unit};
      print "resetting hook status \n";
    }

    if($cont eq 'FUNCTION' or $cont eq 'SUBROUTINE' or $cont eq 'PROGRAM'){ # Need name of routine
      $_=$href->{statement};
      &parse_prog_unit(\$unit_name,\@args);
      $unit_name=uc($unit_name);
# If in module pre-pend module name
      $unit_name=$$prog_info{module_name}.':'.$unit_name if($$prog_info{is_module});
      $remember=0;
    }

    if($hook_status == 0) {   # $hook_status == 0 means we have not done anything yet
      if($cont eq 'USE') {    # Add USE YOMHOOK as second use statement
        $href->{post_insert}="USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK\n";
        $hook_status=1;
      }
      elsif($cont eq 'IMPLICIT NONE') { # No previous USE, add USE YOMHOOK before IMPLICIT NONE
        $href->{pre_insert} ="USE PARKIND1  ,ONLY : JPRB\n"."USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK\n";
        $hook_status=1;
      }
    }
    $remember=$href->{number} if($decl == 2);

#   Use statement added ($hook_status == 1), now insert HOOK switch on statement
#   before first executable statement in program unit ($exec == 2)
    if($hook_status == 1 && $exec == 2) {
      if($remember) {
        $$statements[$remember]->{post_insert}="REAL(KIND=JPRB) :: ZHOOK_HANDLE\n";
        $href->{pre_insert}="IF (LHOOK) CALL DR_HOOK(\'${unit_name}\',0,ZHOOK_HANDLE)\n";
      }
      else {
        $href->{pre_insert}="REAL(KIND=JPRB) :: ZHOOK_HANDLE\n"."IF (LHOOK) CALL DR_HOOK(\'${unit_name}\',0,ZHOOK_HANDLE)\n";
      }
      if($cont eq 'IF') {
        if($href->{content2} eq 'RETURN') {
          $_=$href->{statement};
          s/(\s*IF\s*$nest_par).*\n/$1/i;
          s/\)$/ .AND. LHOOK\)/;
          $href->{pre_insert}=$href->{pre_insert}."$_ CALL DR_HOOK(\'${unit_name}\',1,ZHOOK_HANDLE)\n";
        }
      }
      $hook_status=2;
    }
#   Hook switched on($hook_status == 2), switch off after last executable statement
#   ($exec == 3)
    elsif($hook_status == 2) {
      if($exec == 3 or $exec == 23) {
        $href->{post_insert}="IF (LHOOK) CALL DR_HOOK(\'${unit_name}\',1,ZHOOK_HANDLE)\n";
        $hook_status=3;
      }
      elsif($cont eq 'RETURN') {
        $href->{pre_insert}="IF (LHOOK) CALL DR_HOOK(\'${unit_name}\',1,ZHOOK_HANDLE)\n";
      }
      elsif($cont eq 'IF') {
        if($href->{content2} eq 'RETURN') {
          $_=$href->{statement};
          s/(\s*IF\s*$nest_par).*\n/$1/i;
          s/\)$/ .AND. LHOOK\)/;
          $href->{pre_insert}="$_ CALL DR_HOOK(\'${unit_name}\',1,ZHOOK_HANDLE)\n";
        }
      }
    }
    $hook_status=1 if($in_contain && $hook_status==3); # Reset hook status in CONTAIN region
  }
  die "Failed[INSERT_HOOK]: Adding HOOK function failed " if($hook_status == 2);
}
#==========================================================================

sub doc_char{
# Returns suggested prefix in case of DOCTOR violation (otherwise null string)
  my($type,$usage,$var) = @_;
  my $prefix="";
# INTEGER variables
  if( $type eq "i") {
    if($usage eq "arg") {
      $prefix="K" unless($var=~/^K/i);
    }
    elsif($usage eq "local") {
      $prefix="I" unless($var=~/^[IJ]/i);
    }
    elsif($usage eq "module") {
      $prefix="N" unless($var=~/^[MN]/i);
    }
    elsif($usage eq "namvar") {
      $prefix="I" unless($var=~/^[MNIJ]/i);
    }
    else {
      die "Failed[DOC_CHAR]: Unknown usage";
    }
  }
# REAL variables
  elsif( $type eq "r") {
    if($usage eq "arg") {
      $prefix="P" unless($var=~/^P/i);
    }
    elsif($usage eq "local") {
      $prefix="Z" unless($var=~/^Z|^PP/i);
    }
    elsif($usage eq "module") {
      $prefix="R" if ($var=~/^[ZPIJKLMNCY]/i);
    }
    elsif($usage eq "namvar") {
      $prefix="Z" if ($var=~/^[PIJKLMNCY]/i);
    }
    else {
      die "Failed[DOC_CHAR]: Unknown usage";
    }
  }
#LOGICAL variables
  elsif( $type eq "l") {
    if($usage eq "arg") {
      $prefix="LD" unless($var=~/^LD/i);
    }
    elsif($usage eq "local") {
      $prefix="LL" unless($var=~/^LL/i);
    }
    elsif($usage eq "module") {
      $prefix="L" unless($var=~/^L[^LD]/i);
    }
    elsif($usage eq "namvar") {
      $prefix="LL" unless($var=~/^L/i);
    }
    else {
      die "Failed[DOC_CHAR]: Unknown usage";
    }
  }
#CHARACTER variables
  elsif( $type eq "c") {
    if($usage eq "arg") {
      $prefix="CD" unless($var=~/^CD/i);
    }
    elsif($usage eq "local") {
      $prefix="CL" unless($var=~/^CL/i);
    }
    elsif($usage eq "module") {
      $prefix="C" unless($var=~/^C[^LD]/i);
    }
    elsif($usage eq "namvar") {
      $prefix="CL" unless($var=~/^C/i);
    }
    else {
      die "Failed[DOC_CHAR]: Unknown usage";
    }
  }
# USER DEFINED TYPES
# PB - removed thse 020312 as these are no longer required
# by norms_2011
#  elsif( $type eq 't') {
#    if($usage eq "arg") {
#      $prefix="YD" unless($var=~/^YD/i);
#    }
#    elsif($usage eq "local") {
#      $prefix="YL" unless($var=~/^YL/i);
#    }
#    elsif($usage eq "module") {
#      $prefix="Y" unless($var=~/^Y[^LD]/i);
#    }
#    elsif($usage eq "namvar") {
#      $prefix="YL" unless($var=~/^Y/i);
#    }
#    else {
#      die "Unknown usage";
#    }
#  }
# FUNCTION/EXTERNAL declarations
  elsif( $type eq 'f' || $type eq 'e' || $type eq 's' || $type eq 't') {
# Everything is OK
  }
  else {
    die "Failed[DOC_CHAR]: Unknown type $type";
  }
  ($prefix);
}
#==========================================================================

sub parse_prog_unit {
# Find out program type,program name and arguments for program statement
  my($unit_name,$args)=@_;
  my($type)='';
  $$unit_name='';
  @$args=();
#RJ: I would discourage the use of $name like this with 'o' modifiers in regexses, mainly portability
  our($name,$type_spec);
  my $t_args=$_;

#RJ: detect continuated too
#RJ   if(/^ *MODULE +($name) *$/io) {
#RJ   if(/^[ ]*+MODULE[\s ]++($name) *$/io) {
  if(/^[ ]*+MODULE[\s ]++((?:[A-Z][\w]*+)) *$/i) {
    $type='module';
    $$unit_name=$1;
  }
#RJ: detect continuated too
#RJ   elsif(/^ *SUBMODULE +($name) *$/io) {
#RJ   elsif(/^[ ]*+SUBMODULE[\s ]++($name) *$/io) {
  elsif(/^[ ]*+SUBMODULE[\s ]++((?:[A-Z][\w]*+)) *$/i) {
    $type='submodule';
    $$unit_name=$1;
  }
#RJ: detect continuated too
#RJ   elsif(/^ *PROGRAM +($name) *$/io) {
#RJ   elsif(/^[ ]*+PROGRAM[\s ]++($name) *$/io) {
  elsif(/^[ ]*+PROGRAM[\s ]++((?:[A-Z][\w]*+)) *$/i) {
    $type='program';
    $$unit_name=$1;
  }
#RJ-later
#RJ: allow elemental/pure attribute, plus simplify by splitting
#RJ    elsif(/^ *(?:RECURSIVE)? *(SUBROUTINE) +($name)\b/io | /^ *(?:$type_spec)?\s*(FUNCTION) +($name)\b/io) {
  elsif($t_args=~s/^[ ]*+(?:RECURSIVE[\s ]++|ELEMENTAL[\s ]++|PURE[\s ]++)*+SUBROUTINE\b//i) {
    my $tdummy_args;
#RJ: get function name
#RJ     $t_args=~s/^[\s ]*($name)//i;
    $t_args=~s/^[\s ]*((?:[A-Z][\w]*+))[\s ]*+//i;
    $type='subroutine';
    $$unit_name=$1;
#    print "FOUND PPU  $type $$unit_name \n ";
#RJ: fix some corner cases here, try to check if exsists "(...)" after name, not closed
#RJ     if(/^[^\(]+\([^\)]+\)/) {
#RJ: first strip comments if any, that shouldn't be there, and trim newlines too
#RJ       $tstatm=~ s/\!.*\n/\n/g;
      $t_args=~s/[\!][^\n]*+[\n]//g;
#RJ: concatenate lines by remowing newlines if any
      $t_args=~s/[\s]++//g;
    if($t_args=~/^[\(][\s ]*+[^)]/) {
#RJ       my $tstatm=$_;
      my $tstatm=$t_args;
      if($tstatm=~s/[(]([^)]++)[)]//){
        $tdummy_args=$1;
#RJ: trim spaces too
#RJ       $tstatm=~s/[\s]//g;
        $tdummy_args=~s/[\s ]+//g;
#RJ       $tstatm=~s/.+\((.+)\)/$1/;
#  warn "zzz: $tdummy_args";
        @$args=split(',',uc($tdummy_args));
      }
      else{
        die "Failed[PARSE_PROG_UNIT]: failed to get arguments";
      }
    }
  }
#RJ: almost the same for functions, but more complicated
  elsif($t_args=~s/^[ ]*+(?:RECURSIVE[\s ]++|ELEMENTAL[\s ]++|PURE[\s ]++|(?:$type_spec)[\s ]*+)*+[\s ]*+FUNCTION\b//io) {
    my $tdummy_args;
#RJ: get function name
#RJ     $t_args=~s/^[\s ]*+($name)//io;
    $t_args=~s/^[\s ]*+((?:[A-Z][\w]*+))[\s ]*+//i;

    $type='function';
    $$unit_name=$1;
#    print "FOUND PPU  $type $$unit_name \n ";
#RJ: fix some corner cases here, try to check if exsists "(...)" after name, not closed
#RJ     if(/^[^\(]+\([^\)]+\)/) {
#RJ: first strip comments if any, that shouldn't be there, and trim newlines too
#RJ       $tstatm=~ s/\!.*\n/\n/g;
      $t_args=~s/[\!][^\n]*[\n]//g;
#RJ: concatenate lines by remowing newlines if any
      $t_args=~s/[\s ]*+//g;
    if($t_args=~/^[(][ ]*[^)]/) {
#RJ       my $tstatm=$_;
      my $tstatm=$t_args;
      if($tstatm=~s/[(]([^)]++)[)]//){
        $tdummy_args=$1;
#RJ: trim spaces too
#RJ       $tstatm=~s/[\s]//g;
        $tdummy_args=~s/[\s ]+//g;
#RJ       $tstatm=~s/.+\((.+)\)/$1/;
        @$args=split(',',uc($tdummy_args));
      }
      else{
        die "Failed[PARSE_PROG_UNIT]: failed to get arguments";
      }
#RJ-remark should we treat either function name or result one as dummy arg for functions?
    }

  }
#RJ-debug   warn "zzz_=".$_;
#RJ-debug   warn "ttt_=".$type."                          666";
  return $type;
}
#==========================================================================

#RJ: alternative more advanced version, no passing in $_
sub parse_prog_unit_v2 {
# Find out program type,program name and arguments for program statement
  my($line,$unit_exit,$unit_type,$unit_name,$unit_args,$unit_attrs)=@_;
  our (${f90s_VERBOSITY});
  $$unit_exit=-13;
  $$unit_type='';
  $$unit_name='';
  @$unit_args=();
  @$unit_attrs=();
  our($name,$type_spec);
  my $ttt=$$line;

  $ttt=~s/^[\s ]*+//;

  if($ttt=~s/^END[\s ]*+//) {
    $$unit_exit=1;
  }
  else {
    $$unit_exit=0;
  }

  $ttt=~s/[\!][^\n]*+[\n]//g;
  if($ttt=~s/^MODULE[\s ]*+//i) {
    $$unit_type='module';
    if($ttt=~s/((?:[A-Z][\w]*+))[\s ]*+$//i) {
      $$unit_name=$1;
    }
    elsif($$unit_exit == 1) {
      $$unit_exit=11;
    }
  }
  elsif($ttt=~s/^SUBMODULE[\s ]*+//i) {
    $$unit_type='submodule';
    if($ttt=~s/((?:[A-Z][\w]*+))[\s ]*+$//i) {
      $$unit_name=$1;
    }
    elsif($$unit_exit == 1) {
      $$unit_exit=11;
    }
  }
  elsif($ttt=~s/^PROGRAM[\s ]++//i) {
    $$unit_type='program';
    if($ttt=~s/((?:[A-Z][\w]*+))[\s ]*+$//i) {
      $$unit_name=$1;
    }
    elsif($$unit_exit == 1) {
      $$unit_exit=21;
    }
  }
  else {
    if($ttt=~s/^((?:RECURSIVE[\s ]++|ELEMENTAL[\s ]++|PURE[\s ]++)++)//i) {
      my $t_attrs=$1;
      $t_attrs=~s/[\s ]++/,/g;
      $t_attrs=~s/[\,]++$//;
      push (@$unit_attrs,split(',',uc($t_attrs)));
    }
    if($ttt=~s/^SUBROUTINE\b[\s ]*+//i) {
      $$unit_type='subroutine';
#RJ-temp       if($ttt=~s/^((?:[A-Z][\w]*+))[\s ]*+//i) {
#RJ: since there are some prototyping at xrd/fa/ellips.F90 and ellips.h 'SUBROUTINE _ELLIPS_ (KSMAX,KMSMAX,KNTMP,KMTMP)'
#RJ: expanding to include '_' case, this could and should be avoided
      if($ttt=~s/^((?:[A-Z_][\w]*+))[\s ]*+//i) {
        $$unit_name=$1;
      }
      elsif($$unit_exit == 1) {
        $$unit_exit=31;
      }
 # warn "yyy: $ttt";
      if($ttt=~/^[\(][\s ]*+[^)]/) {
#RJ-ups         if($ttt=~s/^([(]([^)]++)[)])[\s ]*+//){
        if($ttt=~s/^[(]([^)]++)[)][\s ]*+//){
          my $tdummy_args=$1;
          $tdummy_args=~s/[\s ]+//g;
          push(@$unit_args,split(',',uc($tdummy_args)));
        }
        else{
          die "Failed[PARSE]: failed to get arguments";
        }
      }
      else {
        $ttt=~s/[(][\s ]*+[)][\s ]*+//;
      }
 # warn "yyy: $ttt";
      if($ttt=~s/^(BIND[\s ]*+[(][^)]*+[)])[\s ]*+//i){
        push(@$unit_attrs,$1);
      }
      unless($ttt=~/^$/){
        if(${f90s_VERBOSITY}>=5) {
          warn "Warning[PARSE]: failed to parse all '$_'->'$ttt'";
        }
      }
    }
    else {
      if($ttt=~s/^((?:$type_spec))[\s ]*+//io) {
        push(@$unit_attrs,$1);
      }
      if($ttt=~s/^((?:RECURSIVE[\s ]++|ELEMENTAL[\s ]++|PURE[\s ]++)++)//i) {
        my $t_attrs=$1;
        $t_attrs=~s/[\s ]++/,/g;
        $t_attrs=~s/[\,]++$//;
        push (@$unit_attrs,split(',',uc($t_attrs)));
      }
      if($ttt=~s/^FUNCTION\b[\s ]*+//i){
        $$unit_type='function';
#RJ-old         if($ttt=~s/^[\s ]*+((?:[A-Z][\w]*+))[\s ]*+//i){
        if($ttt=~s/^((?:[A-Z][\w]*+))[\s ]*+//i){
          $$unit_name=$1;
          if($ttt=~/^[\(][\s ]*+[^)]/) {
            if($ttt=~s/^[(]([^)]++)[)][\s ]*+//){
              my $tdummy_args=$1;
              $tdummy_args=~s/[\s ]+//g;
              push(@$unit_args,split(',',uc($tdummy_args)));
            }
            else{
              die "Failed[PARSE]: failed to get arguments";
            }
          }
          else {
            $ttt=~s/[(][^)]*+[)][\s ]*+//;
          }
#RJ: do twice, RESULT(...) and/or BIND(..)
#RJ-remark should we treat either function name or result one as dummy arg for functions?
          if($ttt=~s/^((?:BIND|RESULT)[\s ]*+[(][^)]*+[)])[\s ]*+//i){
            push(@$unit_attrs,$1);
          }
          if($ttt=~s/^((?:BIND|RESULT)[\s ]*+[(][^)]*+[)])[\s ]*+//i){
            push(@$unit_attrs,$1);
          }
          unless($ttt=~/^$/){
            if(${f90s_VERBOSITY}>=5) {
              warn "Warning[PARSE]: failed to parse all '$_'->'$ttt'";
            }
          }
        }
        elsif($$unit_exit == 1) {
          $$unit_exit=41;
        }

#RJ: if function has no explicit declaration of result, force it
        {
          my $has_result=0;
          foreach my $ii (0..$#$unit_attrs) {
            my $ttt=$$unit_attrs[$ii];
             if($ttt=~/^(RESULT\b)/i) {
              $has_result=1;
            }
          }
          if($has_result==0) {
            push(@$unit_attrs,"RESULT(".uc($$unit_name).")");
          }
        }

      }
      else {
 #       if($unit_exit == 1){
 #         warn "Warning[PARSE]: failed to get unit type for '$_'";
          $$unit_exit=-1
 #       }
#        $$unit_exit=-1;
      }
    }
  }
 # warn "  www: $$unit_exit $$unit_type $$unit_name";
}

#RJ: setup parse moved up

#==========================================================================

sub f90_indent {
# Indent free-format F90 program to our standards
  my($line_hash,$lines)=@_;
  my($delta)='  ';
  my($cur_indent)='';
  @$lines=();
  foreach my $href (@$line_hash) {
    $_=$href->{line};
    if($href->{content} eq 'comment') {
      push(@$lines,$_);
      next;
    }
    s/^ *//; # Remove current indentation
    my($post_chg)=0;
    my($pre_chg)=0;
    my($cont_line)='';
    exit if (! exists $href->{content});
    if($href->{content} eq 'DO') {
      $post_chg=1 unless /^DO\s+\d/;
    }
    elsif($href->{content} eq 'ENDDO') {
      $pre_chg=1;
    }
    elsif($href->{content} eq 'IF_construct') {
      $post_chg=1;
    }
    elsif($href->{content} eq 'ELSEIF') {
      $post_chg=1;
      $pre_chg=1;
    }
    elsif($href->{content} eq 'ELSE') {
      $post_chg=1;
      $pre_chg=1;
    }
    elsif($href->{content} eq 'ENDIF') {
      $pre_chg=1;
    }
    elsif($href->{content} eq 'ENDIF') {
      $pre_chg=1;
    }
    elsif($href->{content} eq 'WHERE_construct') {
      $post_chg=1;
    }
    elsif($href->{content} eq 'ELSEWHERE') {
      $post_chg=1;
      $pre_chg=1;
    }
    elsif($href->{content} eq 'ENDWHERE') {
      $pre_chg=1;
    }
    elsif($href->{content} eq 'ENDIF') {
      $pre_chg=1;
    }
    elsif($href->{content} eq 'SELECT CASE') {
      $post_chg=1;
    }
    elsif($href->{content} eq 'CASE') {
      $post_chg=1;
      $pre_chg=1;
    }
    elsif($href->{content} eq 'END SELECT') {
      $pre_chg=1;
    }
    $cont_line=' ' if($href->{content} eq 'cont_line');
    if( $pre_chg ) {
      unless($cur_indent=~s/^$delta//o) {
      print $_;
      die  "Failed[f90_indent]: something wrong,indent negative\n";;
      }
    }
#    print "$cur_indent$cont_line$_";

    $_=$cur_indent.$cont_line.$_;
    push(@$lines,$_);
    $cur_indent.=$delta if( $post_chg );
  }

  if(! ($cur_indent eq '')) {
    die "Failed[f90_indent]: something wrong, indent=XX${cur_indent}XX\n";
  }
}

#==========================================================================

sub tidy {
# Straigthforward tidiyng of statements
  my($statements) = @_;
  my($href,$content);
  foreach $href (@$statements) {
    $_=$href->{statement};
    $content=$href->{content};
# Substitute tab with four blanks
    s/\t/    /g;
    if($content eq 'comment') {
# Substitute empty comment line with empty line
      s/^[!] *\n$/\n/;
      $href->{statement}=$_;
      next;
    }
    if($href->{exec}) {
      if($content eq 'ENDDO') {
        s/\bEND DO\b/ENDDO/i;
        $href->{statement}=$_;
        next;
      }
      if($content eq 'ENDIF') {
        s/\bEND IF\b/ENDIF/i;
        $href->{statement}=$_;
        next;
      }
      if($content eq 'ENDWHERE') {
        s/\bEND WHERE\b/ENDWHERE/i;
        $href->{statement}=$_;
        next;
      }

      s/\bELSE IF\b/ELSEIF/i  if($content eq 'ELSEIF');

      if(/\./) {
        s/ *\.EQ\. */ == /gi;
        s/ *\.NE\. */ \/= /gi;
        s/ *\.LT\. */ < /gi;
        s/ *\.LE\. */ <= /gi;
        s/ *\.GT\. */ > /gi;
        s/ *\.GE\. */ >= /gi;
      }

#
      s/\bA?MAX[01]\b/MAX/gi;
      s/\bA?MIN[01]\b/MIN/gi;
      s/\bAMOD\b/MOD/gi;
      s/\bALOG\b/LOG/gi;
      s/\bALOG10\b/LOG10/gi;
#      s/\bI(SIGN *\()/$1/gi; # Goes wrong in larcinad etc.
      s/\bFLOAT\b/REAL/g;
      s/\bfloat\b/real/g;
    }

    $href->{statement}=$_;
  }
}

#==========================================================================

sub process_include_files {
# Read include files and put reference to the anonomys array
# holding the array of "statement" hashes in $href->{inc_statm}
#RJ: $inc_statements is unused, api should be changed
  my($statements,$prog_info,$inc_statements) = @_;
  my ($content,$fname,$href);
  return unless ($$prog_info{has_include});
#RJ: looks like this should be moved into foreach loop, creates include explosion
#RJ: fixing just in _v2 version, just in case
  my @lines=();
  foreach $href (@$statements) {
#    print "doing $href->{first_line} : $href->{content}\n";
    $content=$href->{content};
    if($content eq 'include'){
      $_=$href->{statement};
      /["](\S+)["]/;
      $fname=$1;
      &get_inc_lines($fname,\@lines);
# Macro-removal
      &remove_macro(\@lines);
# Expand lines into statements and put refernce to this
# array of hashes into $href->{inc_statm}
      my @inc_statms=();
      my $dum={};
      &expcont(\@lines,\@inc_statms);
      $href->{inc_statm}=[@inc_statms];
      my $incs=$href->{inc_statm};
# Study the read in file and add more attributes
      &study($incs);
#      print Dumper($incs,$dum);

    }
  }
}

#==========================================================================

sub process_include_files_v2 {
#RJ: faster version
# Read include files and put reference to the anonomys array
# holding the array of "statement" hashes in $href->{inc_statm}
  my($statements,$prog_info) = @_;
  my ($content,$fname,$href);

  return unless ($$prog_info{has_include});

  foreach $href (@$statements) {
    my @lines=();
#    print "doing $href->{first_line} : $href->{content}\n";
    $content=$href->{content};
    if($content eq 'include'){
      $_=$href->{statement};
#RJ: generalization
#RJ       /["](\S+)["]/;
      if(/[\"\'][\s]*+([\w\.]++)[\s]*+[\"\']/) {
        $fname=$1;
        &get_inc_lines($fname,\@lines);
      }
      else {
        die "Bailout[INCLUDE]: failed to extract include name from $_";
      }

#RJ: in harmonie cy40 no longer needed
#RJ # Macro-removal
#RJ       &remove_macro(\@lines);

# Expand lines into statements and put refernce to this
# array of hashes into $href->{inc_statm}
      my @inc_statms=();
      &expcont(\@lines,\@inc_statms);
      $href->{inc_statm}=[@inc_statms];;
      my $incs=$href->{inc_statm};
      $href->{inc_info}{'inc_name'}=($fname);
      my $incs_info=$href->{inc_info};
# Study the read in file and add more attributes
#RJ: should this pass %prog_info just in case? adding anyway
      &study($incs,$incs_info);
 # warn "aaa:\n".Dumper($incs);
 # warn "bbb:\n".Dumper($incs_info);
 # warn "bbb:\n".Dumper($href->{inc_info});
 # warn "ccc:\n".Dumper($statements);
 # warn "ddd:\n".Dumper($prog_info);
    }
  }
}
#==========================================================================
sub get_inc_lines{
# Recurcivly get lines from include files, flatten into array of lines
  my ($fname,$lines) = @_;
  our (${f90s_VERBOSITY});
  my ($VPATH,@vpath,@tmp_lines);

  $VPATH=$ENV{VPATH} or die "Failed[GET_INC_LINES]: VPATH not defined ";
  @vpath=split(":",$VPATH);
# Look for include file in VPATH
  foreach my $path (@vpath) {
    my $ffname=$path.'/'.$fname;
    if( -f $ffname) {
# Read lines from include file
#RJ: changing to a bit faster read function
#RJ-old       @tmp_lines = &readfile($ffname);
#RJ: slurp version, just dump file to string, faster by a few seconds
     my $slurp;
     &slurpfile(\$ffname,\$slurp);
     &slurp2array(\$slurp,\@tmp_lines);
#      print "$ffname \n";
      for (@tmp_lines) {
        if(/^\#include\b/){
#RJ           /["](\S+)["]/;
          if(/[\"\'][\s]*+([\w\.]++)[\s]*+[\"\']/) {
            my $fname2=$1;
            &get_inc_lines($fname2,$lines);
          }
          else {
            die "Bailout[INCLUDE]: failed to extract include name from $_";
          }
        }
        else {
          push(@$lines,$_);
        }
      }
      last;
    }
  }
#RJ: warn if not found, useful for e.g. mpif.h, external stuff, especially when working with partial projects
#RJ   die "Include file $fname not found in VPATH=$VPATH " unless(@$lines);
  unless(@tmp_lines){
    if(${f90s_VERBOSITY}>=2) {
      warn "Warning[GET_INC_LINES]: include file $fname not found in VPATH=$VPATH \n";
    }
#RJ     push(@$lines,"\n");
    push(@$lines,"\#include \"$fname\"\n");
  }
}

#==========================================================================

sub create_interface_block {
# Create a "minimal" interface block for subroutines
  my($statements,$interface_block) = @_;
  my($href,$content,@pu_args,%pu_args,$func,%tokens,%seen,%params,%allparams,%param_tokens,$sha1,
     %param_tokens_required,$finished,$token);
  our($name,$nest_par);
  @$interface_block=();
  @pu_args=();
# Gather information needed to create interface block for routine
  foreach $href (@$statements) {
    last if($href->{exec});
    if($href->{content} eq 'SUBROUTINE') {   # Get arguments of subroutine
      $_=$href->{statement};
      my $dum=&parse_prog_unit(\$func,\@pu_args);
      for(@pu_args) {
        $_=uc($_);
        $pu_args{$_}++;
      }
      next;
    }
    if($href->{decl} == 2) {                 # Get all tokens from lines where argument present
      $_=uc($href->{statement});
      my @line_tokens=/\b$name\b/g;
      for (@line_tokens) {
	if($pu_args{$_} && ! $seen{$_}) {
          $seen{$_}=1;
          for (@line_tokens) {
            $tokens{$_}++;
          }
          last;
        }
      }
    }
  }
 
# Process parameter statements. First build up list of statements directly required
# by subroutine argument requirements

  for $href (@$statements) {
    $content=$href->{content};
    $sha1=$href->{sha1};
    next if($content eq 'comment');
    next if($href->{in_contain});
    last if($href->{exec});
    if($href->{decl} == 1 or $href->{decl} == 2) {
      $_=uc($href->{statement});
      s/\!.*\n/\n/g; # Remove trailing comments
      if($href->{content} eq 'INTEGER' and /\bPARAMETER\b/) { # Integer parameters may be used for dimensioning
        $_=~s/.*PARAMETER//; # Remove everything before the PARAMETER statement
	my @line_tokens=/\b$name\b/g;
        $allparams{$sha1}=1;
        # Save all line tokens for later
        for (@line_tokens) {
          $param_tokens{$sha1}{$_}=1;
          if ($tokens{$_}) { # This param statment is directly required
            $params{$sha1}=1;
          }
        }
      }
    }
  }
  
# Now recursively go around all parameter statements getting any that are required

$finished=0;

while ($finished ne 1) {
  # Build up list of all required tokens
  for $sha1 (keys(%params)) {
    for $token (keys(%{$param_tokens{$sha1}})) {
      $param_tokens_required{$token}=1;
    }
  }
  
  # Find all parameter statements containing required tokens
  $finished=1;
  for $sha1 (keys(%allparams)) {
    if (! exists($params{$sha1})) { # Only process those not already selected
      for $token (keys(%param_tokens_required)) {
        if (exists($param_tokens{$sha1}{$token})) { # This parameter contains a required token
          $params{$sha1}=1;
          $finished=0;
        }
      }
    }
  }
}

# Now %params contains a list of sha1 identifying PARAMETER lines which are required
# Create interface block
  foreach $href (@$statements) {
    my %myhref=%$href;       # We have to make a copy rather that another reference
    my $myhref=\%myhref;     # since we have to modify statements for this purpose only
    $content=$myhref->{content};
    next if($content eq 'comment');
    next if($myhref->{exec});
    next if($myhref->{in_contain});
    delete $myhref->{pre_insert} if(exists $myhref->{pre_insert}); #Delete existing pre- and post -inserts
    delete $myhref->{post_insert} if(exists $myhref->{post_insert});
    if($myhref->{content} eq 'SUBROUTINE') { # Put subroutine statement into interface block
      $myhref->{pre_insert} = "INTERFACE\n";
      push(@$interface_block,$myhref);
    }
    if($myhref->{decl} == 4) { # Include USE statement in interface block if needed
      $_=$myhref->{statement};
      tr/ \n//d;
      $_=uc($_);
      if(/^USE$name,ONLY:(.+)$/) {
        $_=$1;
        my @line_tokens=/\b$name\b/g;
        for (@line_tokens) {
          if($tokens{$_}) {
            push(@$interface_block,$myhref);
            last;
          }
        }
      }
      else {
        push(@$interface_block,$myhref);  # Always include USE without ONLY for safety
      }
    }
    if($myhref->{decl} == 1 or $myhref->{decl} == 2) {
      $_=uc($myhref->{statement});
      s/\!.*\n/\n/g; # Remove trailing comments
      if($myhref->{content} eq 'INTEGER' and /\bPARAMETER\b/) { # Integer parameters may be used for dimensioning
        if (exists($params{$myhref->{sha1}})) { # This parameter statement is required
          push (@$interface_block,$myhref);
        }

      }
      else{    #Include only lines where an argument is present
        s/$nest_par//g;
        my @line_tokens=/\b$name\b/g;
        for (@line_tokens) {
          if($pu_args{$_}) {
            push(@$interface_block,$myhref);
            last;
          }
        }
      }
    }
#RJ: changed in study content type to 'ENDSUBROUTINE'
#RJ-old     if($content eq 'END SUBROUTINE') { # Add END statement to interface block
    if($content=~/^END[ ]?+SUBROUTINE/) { # Add END statement to interface block
      $myhref->{post_insert} = "END INTERFACE\n";
      push(@$interface_block,$myhref);
      last;
    }
  }
  foreach $href (@$interface_block) {
    $_=$href->{statement};
    s/\!.*\n/\n/g;      # Remove trailing comments
    s/ +/ /g;           # Only one space
    s/\n *\n/\n/g;      # Remove empty lines
    s/\n *\n/\n/g;      # Remove empty lines again
    s/ +\n/\n/g;        # No trailing spaces
    $href->{statement}=$_;
  }
}

#==========================================================================
sub change_var_names{
  my($statements) = @_;
  foreach my $href (@$statements) {
    $_=$href->{statement};
    s/\bVAZX\b/YVAZX/ig;
    s/\bPVAZX\b/YDVAZX/ig;
    s/\bVAZG\b/YVAZG/ig;
    s/\bPVAZG\b/YDVAZG/ig;
    s/\bSCALP_DV\b/YSCALP/ig;
    s/\bRSCALP_DV\b/YRSCALP/ig;
    s/\bSCALPSQRT_DV\b/YSCALPSQRT/ig;
    s/\bRSCALPSQRT_DV\b/YRSCALPSQRT/ig;
    s/\bPYBAR\b/YDYBAR/ig;
    s/\bPSBAR\b/YDSBAR/ig;
    s/\bVCGLPC\b/YVCGLPC/ig;
    s/\bVCGLEV\b/YVCGLEV/ig;
    s/\bSKFROT\b/YSKFROT/ig;
    s/\bSKFMAT\b/YSKFMAT/ig;
    s/\bSTATE_VECTOR_4D\b/YSTATE_VECTOR_4D/ig;
    s/\bVAZX0\b/YVAZX0/ig;
    s/\bVAZG0\b/YVAZG0/ig;
    s/\bRSPFORCE\b/YSPFORCE/ig;
    $href->{statement}=$_;
  }
}
# =========================================================================
sub remake_arg_decl{
  my($statements,$prog_info) = @_;
  my($href,$content,@pu_args,$func,%tokens);
  my($left,$right,%arghash,$dim);
  our($nest_par,$name);

  my $dims='';
# Crack existing dummy declarations, build hash arghash
  foreach $href (@$statements) {
    last if($href->{prog_unit} >0);
    if($href->{content} eq 'SUBROUTINE') {   # Get arguments of subroutine
      $_=$href->{statement};
      my $dum=&parse_prog_unit(\$func,\@pu_args);
#      print Dumper(\@pu_args);
      for(@pu_args) {
        $_=uc($_);
        $arghash{$_}{other}='';
        $arghash{$_}{dimuse}=0;
        $arghash{$_}{intent}='';
        $arghash{$_}{used}=0;
        $arghash{$_}{set}=0;
        $arghash{$_}{reallyset}=0;
        $arghash{$_}{type}='';
        $arghash{$_}{comment}='';
        $arghash{$_}{inif}=0;
      }
      next;
    }
    if($href->{decl} == 2) {
      $_=$href->{statement};
      my $comment='';
      $comment=$1 if(/.*(\!.*)$/);
      s/\!.*\n/\n/g;                        # Remove trailing comments in all lines
      $_=uc($_);
      s/\s//g;
      if(/^(.+)::(.+)$/){
        $left=$1;
        $right=$2;
        $_=$right;
        s/$nest_par//g;
        s/($name)\*\w+/$1/g;
#        print "XX  $_ \n";
        foreach my $arg (@pu_args) {
          if(/\b$arg\b/) {
#            print "ARG $arg $left $_ \n";
            $arghash{$arg}{linedec}=$href->{number};
            $arghash{$arg}{comment}=$comment;
            my @locdec =split ',',$left;
            my $i=0;
            foreach my $locdec (@locdec) {
              if($i == 0) {
                $arghash{$arg}{type}=$locdec;
              }
              elsif($locdec=~/\bINTENT/) {
                $arghash{$arg}{intent}=','.$locdec;
              }
              else {
                $arghash{$arg}{other}=$arghash{$arg}{other}.','.$locdec;
              }
              $i++;
            }
            if($right=~/\b$arg\b(\*\w+)/) {
              $dim=$1;
            }
            elsif($right=~/\b$arg\b($nest_par\*$nest_par)/) {
              $dim=$1;
            }
            elsif($right=~/\b$arg\b($nest_par\*\w+)/) {
              $dim=$1;
            }
            elsif($right=~/\b$arg\b(\*$nest_par)/) {
              $dim=$1;
            }
            elsif($right=~/\b$arg\b($nest_par)/) {
              $dim=$1;
            }
            else {
              $dim='';
            }
              $arghash{$arg}{dim}=$dim;
              $dims=$dims.$dim;
          }
        }
        foreach my $arg (@pu_args) {  # Is arg. used for dimensioning other args?
          if($dims=~/\b$arg\b/i) {
            $arghash{$arg}{dimuse}=1;
          }
        }
      }
    }
  }
  my $insert_line=0;
  foreach $href (@$statements) {
    last if($href->{prog_unit} >0);
    if($href->{decl} == 2 or $href->{content} eq 'PARAMETER') {
      $_=uc($href->{statement});
      next unless /\bPARAMETER\b/;
      my @tmpvar=/\b$name\b/g;
      foreach my $token (@tmpvar) {
        if($dims=~/\b$token\b/) {
          $insert_line=$href->{number};
        }
      }
    }
  }

# Gather info to decide INTENT status
  my $inif=0;
  my @inif_stack=();
  my $cur_inif=0;
  foreach $href (@$statements) {
    last if($href->{prog_unit} >0);
    if($href->{exec}) {
      if($href->{content} eq 'ENDIF') {
        $inif--;
        $cur_inif=pop @inif_stack;
        next;
      }
      elsif($href->{content} eq 'ELSEIF' or $href->{content} eq 'ELSE') {
        $cur_inif=pop @inif_stack;
        $cur_inif=$href->{number};
        push @inif_stack,$cur_inif;
      }
      my ($left,$right);
      $_=$href->{statement};
      s/\!.*\n/\n/g;                        # Remove trailing comments in all lines
      my %setnow=();
      foreach my $arg (@pu_args) {
        $setnow{$arg}=0;
        $setnow{$arg}=1 if($arghash{$arg}{reallyset});
        unless ($setnow{$arg}) {
          foreach my $xx (@inif_stack) {
            $setnow{$arg}=1 if($xx == $arghash{$arg}{inif});
          }
        }
      }

      if($href->{content} eq 'scal_assign' or $href->{content} eq 'array_assign') {
        s/\s//g;
        ($left,$right)=/^(.+)=(.+)$/;
        $_=$right;
        foreach my $arg (@pu_args) {
          if(/\b$arg\b/i) {
            $arghash{$arg}{used}=1 unless $setnow{$arg};
          }
        }
        $_=$left;
        if(/($nest_par)/) {
          $_=$1;
          foreach my $arg (@pu_args) {
            if(/\b$arg\b/i) {
              $arghash{$arg}{used}=1 unless $setnow{$arg};
            }
          }
        }
        $_=$left;
        foreach my $arg (@pu_args) {
          if(/^$arg\b/i) {
            $arghash{$arg}{set}=1;
            $arghash{$arg}{inif}=$cur_inif;
            $arghash{$arg}{reallyset}=1 unless($inif);
          }
        }
      }
      elsif($href->{content} eq 'IF' ) {
        if($href->{content2} eq 'scal_assign' or $href->{content2} eq 'array_assign' or $href->{content2} eq 'CALL') {
          s/\n//g;
          ($left,$right)=/^\s*(IF\b\s*$nest_par)(.+)/i;
          $_=$left;
          foreach my $arg (@pu_args) {
            if(/\b$arg\b/i) {
              $arghash{$arg}{used}=1 unless $setnow{$arg};
            }
          }
          $_=$right;
          if($href->{content2} eq 'CALL') {
            my $statement=$right;
            my $inifx=1;
            &propag_arg(\$statement,\%arghash,\$inifx,\%setnow);
          }
          else {
            s/\s//g;
            ($left,$right)=/^(.+)=(.+)$/;
            $_=$right;
            foreach my $arg (@pu_args) {
              if(/\b$arg\b/i) {
                $arghash{$arg}{used}=1 unless $setnow{$arg};
              }
            }
            $_=$left;
            if(/($nest_par)/) {
              $_=$1;
              foreach my $arg (@pu_args) {
                if(/\b$arg\b/i) {
                  $arghash{$arg}{used}=1 unless $setnow{$arg};
                }
              }
            }
            $_=$left;
            foreach my $arg (@pu_args) {
              if(/^$arg\b/i) {
                $arghash{$arg}{inif}=$cur_inif;
                $arghash{$arg}{set}=1;
              }
            }
          }
        }
        else {
          foreach my $arg (@pu_args) {
            if(/\b$arg\b/i) {
              $arghash{$arg}{used}=1 unless $setnow{$arg};
            }
          }
        }
      }
      elsif($href->{content} eq 'WHERE' ) {
        s/\s//g;
        ($left,$right)=/^(WHERE$nest_par)(.+)/i;
        $_=$left;
        foreach my $arg (@pu_args) {
          if(/\b$arg\b/i) {
            $arghash{$arg}{used}=1 unless $setnow{$arg};
          }
        }
        $_=$right;
        ($left,$right)=/^(.+)=(.+)$/;
        $_=$right;
        foreach my $arg (@pu_args) {
          if(/\b$arg\b/i) {
            $arghash{$arg}{used}=1 unless $setnow{$arg};
          }
        }
        $_=$left;
        foreach my $arg (@pu_args) {
          if(/^$arg\b/i) {
            $arghash{$arg}{inif}=$cur_inif;
            $arghash{$arg}{set}=1;
          }
        }
      }
      elsif($href->{content} eq 'CALL') {
        my $statement=$_;
        &propag_arg(\$statement,\%arghash,\$inif);
      }
      else{
        foreach my $arg (@pu_args) {
          if(/\b$arg\b/i) {
            $arghash{$arg}{used}=1 unless $setnow{$arg};
          }
        }
      }
      if($href->{content} eq 'IF_construct') {
        $inif++;
        $cur_inif=$href->{number};
        push @inif_stack,$cur_inif;
      }
    }
  }

# Create INTENT statemant based on gathered info
  foreach my $arg (@pu_args) {
    if($arghash{$arg}{linedec}) {
      if($arghash{$arg}{nointent}) {
        unless($arghash{$arg}{intent}) {
          $arghash{$arg}{intent}=' ';
          $arghash{$arg}{comment}='! UNDETERMINED INTENT';
        }
      }
      else{
        my $intent='';
        $intent='IN' if($arghash{$arg}{used} or $arghash{$arg}{dimuse});
        $intent=$intent.'OUT' if($arghash{$arg}{set});
        if($intent) {
          if($arghash{$arg}{intent} and $intent eq 'OUT') {
            $intent='INOUT' if $arghash{$arg}{intent}=~/INOUT/i;
          }
          $arghash{$arg}{intent}=',INTENT('.$intent.')';
        }
        else {
          $arghash{$arg}{intent}=' ';
          $arghash{$arg}{comment}='! Argument NOT used';
        }
      }
    }
  }

# Remove existing argument declarations
  foreach my $arg (@pu_args) {
    if($arghash{$arg}{linedec}) {
      $_=$$statements[$arghash{$arg}{linedec}]->{statement};
      #   print "BEFORE $arg $_";
      if(/.*::\s*\b$arg\b\s*(\!.*\n)*$/i) {
        $_='';
      }
      elsif(/.*::\s*\b$arg\b\s*$nest_par\s*(\!.*\n)*$/i) {
        $_='';
      }
      elsif(/.*::\s*\b$arg\b\s*\*\s*\w+\s*(\!.*\n)*$/i) {
        $_='';
      }
      elsif(/.*::\s*\b$arg\b\s*\*\s*$nest_par\s*(\!.*\n)*$/i) {
        $_='';
      }
      elsif(/.*::\s*\b$arg\b\s*$nest_par\s*\*\s*\w+\s*(\!.*\n)*$/i) {
        $_='';
      }
      elsif(/.*::\s*\b$arg\b\s*$nest_par\s*\*\s*$nest_par\s*(\!.*\n)*$/i) {
        $_='';
      }
      else{
        /^(.*::)(.*)$/s;
        my $left=$1;
        $_=$2;
        s/\b$arg\b\s*$nest_par//i;
        s/\b$arg\b\s*\*\s*\w+//i;
        s/\b$arg\b\s*\*\s*$nest_par//i;
        s/\b$arg\b//i;
        s/,\s*,/,/;
        s/,(\s*)$/$1/;
        s/\n\s*\n/\n/g;
        $_=$left.$_;
        s/::\s*,/::/;
      }
 #   print "AFTER $arg $_\n";
      $$statements[$arghash{$arg}{linedec}]->{statement}=$_;
    }
  }

 # Write out

  my $newdecl='';
  my $linedec;
  foreach my $arg (@pu_args) {
    if($arghash{$arg}{linedec}) {
      if($arghash{$arg}{other} and ! $arghash{$arg}{dim}) {
        $arghash{$arg}{other}=~s/\s//g;
        if($arghash{$arg}{other}=~/^,DIMENSION($nest_par)$/i) {
          $arghash{$arg}{other}='';
          $arghash{$arg}{dim}=$1;
        }
      }
      if($arghash{$arg}{dimuse}) { # Put declerations of args first
        $linedec=sprintf "%-18s%s%-14s%s%s%s%s %s",
        $arghash{$arg}{type},$arghash{$arg}{other},$arghash{$arg}{intent},
            ' :: ',$arg,$arghash{$arg}{dim},$arghash{$arg}{comment},"\n";
        $newdecl=$newdecl.$linedec;
      }
    }
  }
  foreach my $arg (@pu_args) {
    if($arghash{$arg}{linedec}) {
      unless($arghash{$arg}{dimuse}) {
        $linedec=sprintf "%-18s%s%-14s%s%s%s %s%s",
        $arghash{$arg}{type},$arghash{$arg}{other},$arghash{$arg}{intent},
            ' :: ',$arg,$arghash{$arg}{dim},$arghash{$arg}{comment},"\n";
        $newdecl=$newdecl.$linedec;
      }
    }
  }
#  print "INSERT_LINE $insert_line \n";
  if($insert_line) {
    $$statements[$insert_line]->{post_insert}=$newdecl;
  }
  else{
    foreach $href (@$statements) {
      if($href->{decl} == 2) {
        $href->{pre_insert}=$newdecl;
        last;
      }
    }
  }

#  print $newdecl;
#  print Dumper(\%arghash);
}

sub propag_arg{
  my ($statement,$arghash,$inif,$setnow) = @_;
  our ($name,$nest_par);
  my (%argpos);
  $_=$$statement;
  s/^\s*CALL\s+($name)//i;
  my $called=lc($1);
  s/\s//g;
  s/^\((.*)\)$/$1/s;
  my @inpars=/$nest_par/g;
  s/$nest_par//g;
  s/($name)%$name/$1/g;
  $_=uc($_);
#  print "PROPAG $called $_ @inpars \n";
  my @call_args=split ',' , $_;
  my $i=0;
  my $interesting=0;
  %argpos=();
  foreach my $call (@call_args) {

#    print "CALL $called $call \n" ;
    if($call=~/(.+)=(.+)/) {
      $call=$2; #This just by-passes the problem
    }
    if(exists $$arghash{$call}) {
      if(exists $argpos{$call}) {
        push @{$argpos{$call}},$i;
      }
      else {
        my @i=($i);
        $argpos{$call}=[@i];
      }
      $interesting=1;
    }
    $i++;
  }
  if($interesting) {
    my $fname='/tmp/intblocks/'.$called.'.intfb.h';
    if( -f $fname ) {
      my @dumargs=();
      my $unit_name;
      print "FILE $fname FOUND \n";
      my @lines = &readfile($fname);
      my @loc_statements=();
      &expcont(\@lines,\@loc_statements);
      foreach my $href (@loc_statements) {
        $_=$href->{statement};
        if(/^\s*SUBROUTINE/i) {
          my $dum=&parse_prog_unit(\$unit_name,\@dumargs);
          next;
        }
        if(/::/) {
          s/\s//g;
          foreach my $arg (keys (%argpos)) {
            my $set_before=$$setnow{$arg};
            foreach my $i (@{$argpos{$arg}}){
              if(/::$dumargs[$i]/) {
                if(/INTENT\(IN\)/i) {
                  $$arghash{$arg}{used}=1 unless $set_before;
                }
                elsif(/INTENT\(OUT\)/i) {
                  $$arghash{$arg}{set}=1;
                  $$setnow{$arg}=1 unless($$inif);
                }
                elsif(/INTENT\(INOUT\)/i) {
                  $$arghash{$arg}{set}=1;
                  $$arghash{$arg}{used}=1 unless $set_before;;
                  $$arghash{$arg}{reallyset}=1 unless($$inif);
                }
                elsif(/\! UNDETERMINED INTENT/) {
                  $$arghash{$arg}{nointent}=1;
                }
              }
            }
          }
        }
      }
    }
    else {
      foreach my $arg (keys (%argpos)) {
        $$arghash{$arg}{nointent}=1;
      }
    }
  }
  for (@inpars) {
    foreach my $arg (keys (%$arghash)) {
      if(exists $$arghash{$arg}) {
        if(/\b$arg\b/i) {
          $$arghash{$arg}{used}=1 unless $$setnow{$arg};
        }
      }
    }
  }
}

sub add_interface_blocks {
# Add interface block for called routines
  use File::Find;
  my($statements,$prog_info) = @_;
  my($href,$call);
  our($name,$nest_par);
  our(@call_names,@call_names_found,%call_names);

  return unless ($$prog_info{no_calls}); # Skip if there are no calls
  @call_names=();
  %call_names=();

  my $last_decl=0;
  my $in_intfblk=0;
  my %already_in=();
  ST:foreach $href (@$statements) {
    last if($href->{prog_unit} > 0);  # Only consider first program unit (no contains)
    if($href->{content} eq 'INTERFACE') {
      $in_intfblk=1;
      next;
    }
    if($href->{content} eq 'END INTERFACE') {
      $in_intfblk=0;
      next;
    }
    if($in_intfblk) {
      $_=$href->{statement};
      s/\#include\s*\"(\w+)\.h\"\s*$/$1/;
      $_=lc($_);
      $already_in{$_}++;
      next;
    }

# Find last declaration
    if($href->{decl}) {
      next if($href->{content} eq 'FORMAT');
      next if($href->{content} eq 'DATA');
      $last_decl = $href->{number} ;
    }
# Find calls
    next unless($href->{exec});
    if($href->{content} eq 'CALL' or (exists  $href->{content2} and $href->{content2} eq 'CALL') ) {
      $_=$href->{statement};
      /\s*\bCALL\b\s*($name)/i;
      my $call=lc($1);
      next if($already_in{$call}); # Exclude already existing interface block
      next if($call eq 'packmsg'); # A couple of special exceptions
      next if($call eq 'unpkmsg');
      $call_names{$call}++;
    }
  }


# Check that routine exists in IFS
  @call_names_found=();
  find(\&calls_wanted,'/tmp/27/ifs/');
#  find(\&calls_wanted,'/home/mats/work/cy28/ifs/');
#  find(\&calls_wanted,'/tmp/27/trans/');
  @call_names_found=sort(@call_names_found);
#  print "P2 @call_names_found \n";
  @call_names=@call_names_found;

# Contruct include block
  my $block='';
  for (@call_names) {
    $block=$block.'#include "'.$_.'.intfb.h"'."\n";
  }
#  print $block;

  my $clean=0;
  if(@call_names) {
    if($$prog_info{has_interface_block}) {
      foreach $href (@$statements) {
# Add interface block to routine that already has INTERFACE statement
        if($href->{content} eq 'END INTERFACE'){
          if($href->{post_insert}) {
            $href->{post_insert}=$href->{post_insert}."\n".$block;
          }
          else {
            $href->{post_insert}="\n".$block;
          }
          last;
        }
      }
    }
# Add interface block to routine that does not have previous INTERFACE statement
    else {
      $href=@$statements[$last_decl];
      if($href->{post_insert}) {
        $href->{post_insert}=$href->{post_insert}."\n".$block;
      }
      else {
        $href->{post_insert}="\n".$block;
      }
    }
# Remove from EXTERNAL statement where interface block has been added
    foreach $href (@$statements) {
      if($href->{content} eq 'EXTERNAL') {
        $_=$href->{statement};
        foreach my $ext (@call_names) {
          s/\b$ext\b//i;
        }
        s/,\s*,/,/g;
        s/^(\s*EXTERNAL\s*),/$1/i;
        s/^(\s*EXTERNAL.*),\s*$/$1/i;
        s/^\s*EXTERNAL\s*,*\s*$//i;
        $href->{statement}=$_;
      }
    }
  }
}
#======================================================================================
sub calls_wanted {
  # Used by Find as called from add_interface_blocks
  our(%call_names,@call_names_found);
  return unless (/^(\w+)\.F90$/);
  my $call=$1;
  if($call_names{$call}) {
    push(@call_names_found,$call);
  }
}
sub remove_some_comments{
  my($statements) = @_;
  my $prev_empty=0;
  foreach my $href (@$statements) {
    if($href->{content} eq 'comment'){
      $_=$href->{statement};
      if(/^\s*$/) {
        if($prev_empty) {
          s/\s*//;
          $href->{statement}=$_;
        }
        else {
          $prev_empty=1;
        }
        next;
      }
      $prev_empty=0;
      s/^\s*![\s\*]*\bLOCAL\s+(INTEGER|REAL|LOGICAL|CHARACTER)\s+(SCALARS|ARRAYS).*\n$//i;
      s/^\s*![\s\*]*\bDUMMY\s+(INTEGER|REAL|LOGICAL|CHARACTER)\s+(SCALARS|ARRAYS).*\n$//i;
      s/^\s*![\s\*]*\bLOCAL\s+(INTEGER|REAL|LOGICAL|CHARACTER).*\n$//i;
      s/^\s*![\s\*]*\bDUMMY\b\s*$//i;
      s/^\s*![\s\*]*\bLOCAL\b\s*$//i;
      s/^\s*![\s\*]*\bLOCAL\b:\s*$//i;
      s/^\s*![\s\*]*\bLOCAL ARRAYS\b[\s\*]*$//i;
      s/^\s*![\s\*]*\bLOCAL SCALARS\b\s*$//i;
      s/^\s*![\s\*]*\s*\d\.\d+\s*\bLOCAL ARRAYS\b\s*$//i;
      s/^\s*![\s\*]*\s*=== LOCAL ARRAYS ===\s*$//i;
      $href->{statement}=$_;
    }
    else {
      $prev_empty=0;
    }
  }
}
sub get_calls_inc {
  my($statements,$calls,$intfb) = @_;
  foreach my $href (@$statements) {
    if($href->{content} eq 'CALL') {
      $_=$href->{statement};
#RJ: detect "998 call logmsg("..." // &" in aeolus
#RJ: or optionally even openmp ones "!$ call ..." in context==omp
#RJ-old       /^\s*CALL\s+([A-Z]\w*)/i;
      /^[\s\d]*+CALL\s+([A-Z]\w*)/i;
      $$calls{lc($1)}++;
    }
    elsif($href->{content} eq 'IF') {
      if($href->{content2} eq 'CALL') {
        $_=$href->{statement};
        /\bCALL\s+([A-Z]\w*)/i;
        $$calls{lc($1)}++;
      }
    }
    elsif($href->{content} eq 'include') {
      $_=$href->{statement};
      $$intfb{$1}=1 if(/["](\S+)\.intfb\.h["]/);
      $$intfb{$1}=2 if(/["](\S+)\.h["]/); # For old-style interface blocks
    }
  }
}

sub get_calls_inc_v2 {
  my($statements,$calls,$intfb) = @_;
  foreach my $href (@$statements) {
    if($href->{content} eq 'CALL') {
      $_=$href->{statement};
#RJ: detect "998 call logmsg("..." // &" in aeolus
#RJ-old       /^\s*CALL\s+([A-Z]\w*)/i;
      /^[\s\d]*+CALL\s+([A-Z]\w*)/i;
      #$$calls{lc($1)}++;
      $calls->{lc($1)}->{count}++;
      $calls->{lc($1)}->{statement}=$href unless (exists($calls->{lc($1)}->{statement}));
    }
    elsif($href->{content} eq 'IF') {
      if($href->{content2} eq 'CALL') {
        $_=$href->{statement};
        /\bCALL\s+([A-Z]\w*)/i;
        #$$calls{lc($1)}++;
        $calls->{lc($1)}->{count}++;
        $calls->{lc($1)}->{statement}=$href unless (exists($calls->{lc($1)}->{statement}));
      }
    }
    elsif($href->{content} eq 'include') {
      $_=$href->{statement};
      #$$intfb{$1}=1 if(/["](\S+)\.intfb\.h["]/);
      #$$intfb{$1}=2 if(/["](\S+)\.h["]/); # For old-style interface blocks
      if (/["](\S+)\.intfb\.h["]/) {
        $intfb->{$1}->{type}=1;
        $intfb->{$1}->{statement}=$href unless (exists($intfb->{$1}->{statement}));
      } elsif  (/["](\S+)\.h["]/) {
        $intfb->{$1}->{type}=2;
        $intfb->{$1}->{statement}=$href unless (exists($intfb->{$1}->{statement}));
      }
    }
  }
}

sub getcalls {
  my($statements,$calls,$intfbs) = @_;
  foreach my $href (@$statements) {
    if($href->{content} eq 'CALL') {
      $_=$href->{statement};
#RJ: detect "998 call logmsg("..." // &" in aeolus
#RJ: or optionally even openmp ones "!$ call ..." in content==omp
#RJ       /^\s*CALL\s+([A-Z]\w*)/i;
      /^[\s\d]*+CALL\s+([A-Z]\w*)/i;
      $$calls{lc($1)}++;

      if (! /^[\s\d]*+CALL\s+[A-Z]\w*?\s*%/i) { # Don't add "CALL var%function" style calls
        /^[\s\d]*+CALL\s+([A-Z]\w*)/i;
        $$calls{lc($1)}++;
      }

    }
    elsif($href->{content} eq 'IF') {
      if($href->{content2} eq 'CALL') {
      $_=$href->{statement};
        if (! /^\bCALL\s+[A-Z]\w*?\s*%/i) { # Don't add "CALL var%function" style calls
	  /\bCALL\s+([A-Z]\w*)/i;
	  $$calls{lc($1)}++;
        }
      }
    }
    elsif($href->{content} eq 'include') {
      $_=$href->{statement};
      /["](\S+)\.intfb\.h["]/;
      $$intfbs{lc($1)}++;
    }
  }
}

#==========================================================================
sub cont_lines_surfex {
#
# Put back continuation character in correct place and execute delayed actions
#
  my($statements,$lines,$line_hash) = @_;
  my(@temp,$i,$iup,$href);


# Put back continuation characters and split statements into lines as they were
  @$lines=();
  @$line_hash=();
  foreach $href (@$statements) {
    $_=$href->{statement};
    if (/\n.*\n/){                      # This is a multi-line statement
      @temp=split /\n/;                 # Split statement into lines (removes EOL)
      $iup=scalar(@temp);               # Number of lines in statement
      for ($i=0;$i < $iup;$i++) {       # Loop through lines
	$_=$temp[$i];
	if($i == 0 ){                   # First line
	  if(/^([^!]+)(!.*)$/) {        # Line has trailing comment
	    s/^([^!]+)(!.*)$/$1&$2\n/;  # Put back & at end of line before comment
	  }
	  else {                        # No trailing comment
	    s/^([^!]+)$/$1&\n/;         # Put back & and EOL at end of line
	  }	    
	}
	elsif ($i == ($iup-1)) {        # Last line
#	  s/^( *)(.*)$/$1& $2 \n/;      # Put back & at beginning of line
	  s/^( *)(.*)$/$1$2\n/;      # Put back & at beginning of line
	}
	else {                          # Other lines
	  if (/^ *!/) {                 # Line is comment line
	    $_=$_."\n";                 # Restore EOL for comments
	  }
	  else {
	    if(/^( *)([^!]*)(!.*)$/) {  # Line has trailing comment
#	      s/^( *)([^!]*)(!.*)*$/$1& $2&$3\n/;  # & at beginning and end of line
     	      s/^( *)([^!]*)(!.*)*$/$1$2&$3\n/;  # & at beginning and end of line
	    }
	    else {                      # No trailing comment
#	      s/^( *)([^!]*)$/$1& $2&\n/; # & at beggining and end of line
      	      s/^( *)([^!]*)$/$1$2&\n/; # & at beggining and end of line
	    }	 
	  }  
	}
	if($i == 0        && exists $href->{pre_insert}) {
	  my @templines=split('\n',$href->{pre_insert});
	  foreach my $tline (@templines) {
	    my $rec={};
	    $rec->{'content'}='unknown';
	    $rec->{'line'}=$tline."\n";
	    push(@$lines,$rec->{'line'});
	    push(@$line_hash,$rec);
	  }
	}
	unless(exists $href->{remove}) {
	  my $rec={};
	  $rec->{'line'}=$_;
	  if($i == 0) {
	    $rec->{'content'}=$href->{content};
	  }
	  else {
	    $rec->{'content'}='cont_line';
	  }
	  push(@$lines,$rec->{'line'});
	  push(@$line_hash,$rec);
	}
	if($i == ($iup-1) && exists $href->{post_insert}) {
	  my @templines=split('\n',$href->{post_insert});
	  foreach my $tline (@templines) {
	    my $rec={};
	    $rec->{'content'}='unknown';
	    $rec->{'line'}=$tline."\n";
	    push(@$lines,$rec->{'line'});
	    push(@$line_hash,$rec);
	  }
	}
      }
    }
    else {  # Not multiline statement
      if(exists $href->{pre_insert}) {
	my @templines=split('\n',$href->{pre_insert});
	foreach my $tline (@templines) {
	  my $rec={};
	  $rec->{'content'}='unknown';
	  $rec->{'line'}=$tline."\n";
	  push(@$lines,$rec->{'line'});
	  push(@$line_hash,$rec);
	}
      }
      unless(exists $href->{remove}) {
	my $rec={};
	$rec->{'line'}=$_;
	$rec->{'content'}=$href->{content};
	push(@$lines,$rec->{'line'});
	push(@$line_hash,$rec);
#	print $rec;
      }
      if(exists $href->{post_insert}) {
	my @templines=split('\n',$href->{post_insert});
	foreach my $tline (@templines) {
	  my $rec={};
	  $rec->{'content'}='unknown';
	  $rec->{'line'}=$tline."\n";
	  push(@$lines,$rec->{'line'});
	  push(@$line_hash,$rec);
	}
      }
    }
  }
}
#==========================================================================
     
sub parse_prog_unit_surfex {
# Find out program type,program name and arguments for program statement
  my($unit_name,$args)=@_;
  my($type)='';
  $$unit_name='';
  @$args=();
  our($name,$type_spec);
  if(/^ *MODULE +($name) *$/io) {
    $type='module';
    $$unit_name=$1;
  }
  elsif(/^ *SUBMODULE +($name) *$/io) {
    $type='submodule';
    $$unit_name=$1;
  }
  elsif(/^ *PROGRAM +($name) *$/io) {
    $type='program';
    $$unit_name=$1;
  }
  elsif(/^ *(?:RECURSIVE)? *(SUBROUTINE) +($name)\b/io |
	/^ *(?:$type_spec)?\s*(FUNCTION) +($name)\b/io) {
    $type=lc($1);
    $$unit_name=$2;
    #print $2,"\n";
#    print "FOUND PPU  $type $$unit_name \n ";
    if(/^[^\(]+\([^\)]+\)/) {
      my $tstatm=$_;
      $tstatm=~ s/\!.*\n/\n/g;   
      $tstatm=~s/\s//g;
      #print "ok1\n",$tstatm,"\n";
      if (/.+\((.+)\).+\((.+)\)/) {
	      #print "block1\n";
      	$tstatm=~s/.+\((.+)\).+\((.+)\)/$1,$2/;
	}
	else {
		# print "block2\n";
	 $tstatm=~s/.+\((.+)\)/$1/;
	}
#      $tstatm=~s/.+\((.+)\)/$1/;	
     @$args=split(',',uc($tstatm));
     # print 'args ',@$args,"\n";
    }
  }
  return $type;
}

#==========================================================================
sub insert_use_modi{
# 
  my($statements,$prog_info,$vars,$modi) = @_;
  my($punit,@args,$tmp_name,$cont,$statm);
  my($href,$exec);
  our $nest_par;
#------------------------------------------------------------------
# Add HOOK function
  my $unit_name='';
  my $last_use=0;
  my $parkind1_inserted=0;
  my $hook_status=0;
  my $in_contain=0;
  my $prev_prog=0;
  my $nb_comment=0;
  my $remember3=0;
  my $prev_cont=0;
  my $indent="";
  my $implicitnone=0;
#  my $indent2="";
  my $indent3=0;
  my ($decl,$remember,$remember2);

  foreach $href (@$statements) {
    $cont=$href->{content};
    $implicitnone=1 if($cont eq 'IMPLICIT NONE');
    }

  foreach $href (@$statements) {
    $cont=$href->{content};

#    print "cont $cont \n";
#    print "exec $href->{exec} \n";

    if ($cont ne 'comment') {
      $remember3=$cont;
      $indent=$href->{indent};
      }
      
    if ($cont eq 'comment'){
      $nb_comment++ if ($remember3 =~ /^(MODULE|SUBMODULE)$/);
      $prev_cont='comment';
      next;
    }

    $decl=$href->{decl};
    $exec=$href->{exec};
#    print $href->{statement},$exec,"\n";
    $in_contain=$href->{in_contain};
    if(! $in_contain and $href->{prog_unit} > $prev_prog) {
      $parkind1_inserted=0;
      $hook_status=0;
      $prev_prog=$href->{prog_unit};
#      print "resetting hook status \n";
    }

    if($cont eq 'FUNCTION' or $cont eq 'SUBROUTINE' or 
       $cont eq 'PROGRAM'){ # Need name of routine
      $_=$href->{statement};
      &parse_prog_unit_surfex(\$unit_name,\@args);
      $unit_name=uc($unit_name);
# If in module pre-pend module name
      $unit_name=$$prog_info{module_name}.':'.$unit_name if($$prog_info{is_module}); 
      $remember=0;
    }

    $remember=$href->{number} if($decl == 2); 
    $indent3=$href->{indent} if($decl == 2);
    $remember2=$href->{number} if ($cont eq 'MODULE' or $cont eq 'SUBMODULE' or $cont eq 'SUBROUTINE' or $cont eq 'FUNCTION');
           
    if (($cont eq 'END SUBROUTINE' or $cont eq 'END FUNCTION') and !$$prog_info{is_module} and !$in_contain) {
	$hook_status = 0;
	}
    $nb_comment = 0 if ($cont eq 'MODULE' or $cont eq 'SUBMODULE' or $cont eq 'SUBROUTINE' or $cont eq 'FUNCTION');

#    print "$href->{statement} statement \n";
#    print "$hook_status hook_status \n";
    $href->{pre_insert}='';
    if($hook_status == 0) {   # $hook_status == 0 means we have not done anything yet
#      if($cont eq 'USE') {    # Add USE YOMHOOK as second use statement
#	$parkind1_inserted=1 if ($parkind1_inserted == 0 && $href->{statement} =~ m/\bparkind1\b/i);
#	$href->{post_insert}="USE YOMHOOK   ,ONLY : LHOOK,   DR_HOOK\n";
#	$hook_status=1;
#      }
#      els
     if($cont eq 'IMPLICIT NONE') { # No previous USE, add USE YOMHOOK before IMPLICIT NONE
	$href->{pre_insert} = "";
	$href->{pre_insert} = "!\n" if ($prev_cont ne 'comment');
	$href->{pre_insert} = $href->{pre_insert}.$indent."USE MODI_".$modi."\n!\n";
	$parkind1_inserted=1;
	$hook_status=1;
      }
     elsif ($cont eq 'CONTAINS') {
       $$statements[$remember2+$nb_comment]->{post_insert}= $indent."USE MODI_".$modi."\n!\n";
       $hook_status=1;
       $parkind1_inserted=1;
      }
      elsif (!$$prog_info{is_module} && ($cont eq 'SUBROUTINE' or $cont eq 'FUNCTION') && $implicitnone==0 ) {
        $$statements[$remember2+$nb_comment]->{post_insert}= "!\n".$indent."USE MODI_".$modi."\n!\n";
 	$hook_status=1;
       $parkind1_inserted=1;
	      
      }
    }

    $hook_status=1 if($in_contain && $hook_status==3); # Reset hook status in CONTAIN region
    #$indent2=$href->{indent};
    #print "$indent aa \n";
  }
  die "Adding USE MODI function failed " if($hook_status == 2);
}

#==========================================================================
sub create_interface_module {
# Create a "minimal" interface block for subroutines or functions
  my($statements,$interface_block,$fname) = @_;
  my($href,$content,@pu_args,%pu_args,$func,%tokens,$tstatm,$tstatm0,$debut);
  our($name,$nest_par);
  @$interface_block=();
  @pu_args=();
  $debut=0;
  print 'create_interface_module',"\n";
# Gather information needed to create interface block for routine
  foreach $href (@$statements) {
    last if($href->{exec});
    if($href->{content} eq 'SUBROUTINE' or $href->{content} eq 'FUNCTION') {   # Get arguments of subroutine
      $debut=1;
      $_=$href->{statement};
      my $dum=&parse_prog_unit_surfex(\$func,\@pu_args);
      for(@pu_args){
	$_=uc($_);
	$pu_args{$_}++;
      }
      next;
    }
    if($href->{decl} == 2) {                 # Get all tokens from lines where argument present
      $_=uc($href->{statement});
      my @line_tokens=/\b$name\b/g;
      for (@line_tokens) {
	if($pu_args{$_}) {
	  for (@line_tokens) {
	    $tokens{$_}++;
	  }
	  last;
	}
      }
    }
  }

# Create interface block
  if($debut eq 1) {
  foreach $href (@$statements) {
    my %myhref=%$href;       # We have to make a copy rather that another reference
    my $myhref=\%myhref;     # since we have to modify statements for this purpose only
    $content=$myhref->{content};
#    print 'content',$href->{statement},$content,"\n";
    next if($content eq 'comment');
    next if($myhref->{exec});
    next if($myhref->{in_contain});
    delete $myhref->{pre_insert} if(exists $myhref->{pre_insert}); #Delete existing pre- and post -inserts
    delete $myhref->{post_insert} if(exists $myhref->{post_insert});
    if($myhref->{content} eq 'SUBROUTINE' or $myhref->{content} eq 'FUNCTION')  { # Put subroutine statement into interface block
      $_=$myhref->{statement};
      s/ +\n/\n/g;        # No trailing spaces
      s/^ +//g;           # No beginning spaces
      s/ +/ /g;           # Only one space
      $tstatm=$_;
      $tstatm=~s/^([A-Za-z0-9]+)\ ([A-Za-z0-9]+)/$2/;
      $tstatm=~s/^([^\(]+)(.*)/$1/;
      $tstatm0=$tstatm; 
      $tstatm0=~s/(^[^\n]+\n)(((.*)\n)+)/$1/;   
      my $fname2=$fname;
      $fname2=~s/\.f90/.D/;
      $myhref->{pre_insert} = "!depfile:".$fname2."\n";
      $myhref->{pre_insert} = $myhref->{pre_insert}."MODULE MODI_".$tstatm0."INTERFACE\n";
#      print '1',$myhref->{statement};
      push(@$interface_block,$myhref);
    }
    if($myhref->{decl} == 4) { # Include USE statement in interface block if needed
      $_=$myhref->{statement};
      #print "aaaa ",$_,"\n";
      s/\!.*\n/\n/g;      # Remove trailing comments
      #print "bbbb ",$_,"\n";     
      tr/ \n//d;
      $_=uc($_);
      if(/^USE$name,ONLY:(.+)$/) {
	$_=$1;
	my @line_tokens=/\b$name\b/g;
	#print 'line_tokens',@line_tokens,"\n";
	#print $_,"\n";
	for (@line_tokens) {
	  if($tokens{$_}) {
#        print '2',$myhref->{statement};
	    push(@$interface_block,$myhref);
	        last;
	      }
	    }
      }
      else{ 
        if (/^USEMODD_TYPE/ || /^USEMODD_FMDECLAR/) {
	push(@$interface_block,$myhref);  # Always include USE without ONLY for safety
      }  
    }}
    if($myhref->{decl} == 1 or $myhref->{decl} == 2) {
      $_=uc($myhref->{statement});
      s/\!.*\n/\n/g;      # Remove trailing comments
      if($myhref->{content} eq 'INTEGER' and /\bPARAMETER\b/) { # Integer parameters may be used for dimensioning
	my @line_tokens=/\b$name\b/g;
	for (@line_tokens) {
	  if($tokens{$_}) {
#		      print '3',$myhref->{statement};		  
	    push(@$interface_block,$myhref);
	    last;
	  }
	}
      }
      else{    #Include only lines where an argument is present
	s/$nest_par//g;
	my @line_tokens=/\b$name\b/g;
#		print 'line_tokens',@line_tokens,"\n";
#		print $_,"\n";
	for (@line_tokens) {
#		print 'toto',$_,"\n";
	  if($pu_args{$_}) {
#		        print '4',$myhref->{statement};
	    push(@$interface_block,$myhref);
	    last;
	  }
	}
      }
    }
       if($content=~/^END[ ]*+SUBROUTINE/ or $content=~/^END[ ]*+FUNCTION/) { # Add END statement to interface block
      $myhref->{post_insert} = "\nEND INTERFACE\n"."END MODULE MODI_".$tstatm0;
#       print '5',$myhref->{statement};     
      push(@$interface_block,$myhref);
    #  last;
    }
  }}
#  foreach $href (@$interface_block) {
#    $_=$href->{statement};
#    s/\!.*\n/\n/g;      # Remove trailing comments
#    s/ +/ /g;           # Only one space
#    s/\n *\n/\n/g;      # Remove empty lines
#    s/\n *\n/\n/g;      # Remove empty lines again
#    s/ +\n/\n/g;        # No trailing spaces
#    $href->{statement}=$_;
#  }
  else {
    foreach $href (@$statements) {
      my %myhref=%$href;       # We have to make a copy rather that another reference
      my $myhref=\%myhref;     # since we have to modify statements for this purpose only
      # print '6',$myhref->{statement};
      push(@$interface_block,$myhref);
  }
}
}

fiat
