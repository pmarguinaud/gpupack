#!/usr/bin/env perl  
#

use FindBin qw ($Bin);
use lib $Bin;

package db;

use strict;
use Data::Dumper;
use FileHandle;

sub save
{
  my $db = shift;
  'FileHandle'->new ('>'. $_[0])->print (Dumper ($db));
}

sub load
{
  my $class = shift;
  return do ($_[0]) || bless {}, $class;
}

sub merge_db
{
  my $class = shift;

  my $db = bless {}, $class;
  %$db = map { %{$_->{h} || {}} } reverse @_;
  $db->{_count} ||= 0;

  return $db;
}

sub get_keys
{
  my $db = shift;
  return keys (%{$db->{h}});
}

package dbf;

use strict;
our @ISA = qw (db);

sub get_val
{
  my ($db, $x, $dontcreate) = @_;

  $x =~ s,^\./,,o;

  if ((!exists $db->{h}{$x}) && (!$dontcreate))
    {
      $db->{_count}++;
      $db->{h}{$x} = sprintf ('%6.6x', $db->{_count});
    }
  return $db->{h}{$x};
}

package dbm;

use strict;
our @ISA = qw (db);

sub get_val
{
  my ($db, $x) = @_;
  $x =~ s,^\./,,o;
  return $db->{h}{$x};
}

sub set_val
{
  my ($db, $x, $v) = @_;
  $x =~ s,^\./,,o;
  $db->{h}{$x} = $v;
}

package dbp;

use strict;
our @ISA = qw (db);

sub get_val
{
  my ($db, $x, $dontcreate) = @_;

  if ((!exists $db->{h}{$x}) && (!$dontcreate))
    {
      $db->{_count}++;
      $db->{h}{$x} = sprintf ('%6.6x', $db->{_count});
    }
  return $db->{h}{$x};
}

package main;

use strict;
use File::Find;
use File::Basename;
use Data::Dumper;
use FileHandle;
use Cwd;
use File::Path;
use Getopt::Long;
use File::Copy;

my %opts;

my @opts = (
	     [ 'ldflags',        '',     0, "Get ldflags",                                                         ],
	     [ 'fflags',         '',     0, "Get fflags for a given file"                                          ],
             [ 'noscan-file',    '',     0, "Do not scan source code file to lookup the exact spelling of yomhook" ],
             [ 'base-dir',       '=s',   0, "Base directory to be removed from the filename passed as argument"    ],
             [ 'preprocess',     '',     0, "Pre-process source code (change yomhook and lhook)"                   ],
             [ 'create-library', '',     0, "Create dr_hook module"                                                ],
             [ 'full-cpp-flags', '',     0, "Print full cpp flags"                                                 ],
             [ 'fc',             '=s',   0, "Fortran compiler and options"                                         ],
             [ 'ar',             '=s',   0, "ar and options"                                                       ],
             [ 'clean-code',     '',     0, "Cleanup dr_hook code (keep .pl db)",                                  ],
             [ 'clean',          '',     0, "Cleanup dr_hook data"                                                 ],
             [ 'debug',          '',     0, "Generate debug code"                                                  ],
	     [ 'help',           '',     0, "Help message"                                                         ],
	   );

my $prog = basename ($0);

sub help
{
  print "Usage : $prog\n";
  for my $opt (@opts)
    {
      printf ("  %-20.20s |   %s\n", "--$opt->[0]$opt->[1]", $opt->[3]);
    }
  exit (0);
}

GetOptions (
	     map ({ ($_->[0] . $_->[1], \$opts{$_->[0]}) } @opts)
           );

$opts{help} && &help ();

unless ($opts{'clean'} or $opts{'clean-code'})
  {
    for my $v (qw (TARGET_PACK GMKVIEW MODINC))
      {
        my $err = 0;
        unless (exists ($ENV{$v}))
          {
            warn ("$prog requires environment variable $v\n");
    	$err = 1;
          }
        $err && exit (1);
      }
  }


my ($src_drhook, @src_drhook) = map ({ "$ENV{TARGET_PACK}/src/$_/.dr_hook" } reverse split (m/\s+/o, $ENV{GMKVIEW} || 'local'));


my ($dbf, $dbm, $dbp);

sub slurp
{
  my ($f, $dontfail) = @_;

  local $/ = undef; 
  my $fh = 'FileHandle'->new ("<$f"); 

  if (!$fh)
    {
      return if ($dontfail);
      die ("Cannot open <$f\n"); 
    }
  my $text = <$fh>;
  return $text;
}

sub cmd
{
  system (@_)
    and die ("@_ failed\n");
}

sub resolve_filename
{
  my $f = shift;
  for my $v (reverse (split (m/\s+/o, $ENV{GMKVIEW})))
    {
      my $g = "$ENV{TARGET_PACK}/src/$v/$f";
      return $g if (-f $g);
    }
}

sub update
{
  my ($f, $text, $failifdiff) = @_;

  my $text1 = &slurp ($f, 1);

  if ($failifdiff && defined ($text1) && ($text1 ne $text))
    {
      die ("Updating $f would yield different code\n");
    }

  if ((!defined ($text1)) or ($text1 ne $text))
    {
      'FileHandle'->new ('>' . $f)->print ($text);
    }
}


sub uniq
{
  my $x = shift;
  my %s = map { ($_, 1) } @$x;
  @$x = keys (%s);
}

sub yomhook_fN
{
  return sprintf ('yomhook_%6.6d', $_[0]);
}

sub subhook1_fN
{
  return sprintf ('subhook1_%6.6d', $_[0]);
}

sub subhook2_fN
{
  return sprintf ('subhook2_%6.6d', $_[0]);
}

sub subhook3_fN
{
  return sprintf ('subhook3_%6.6d', $_[0]);
}

sub subhook4_fN
{
  return sprintf ('subhook4_%6.6d', $_[0]);
}

sub lhook_f
{
  my $v = $dbf->get_val (@_);
  $v or return;
  return 'lhook_f_' . $v;
}

sub yomhook_f
{
  my $v = $dbm->get_val (@_);
  $v or return;
  return &yomhook_fN ($v);
}


# if base packages have been updated, then restart from scratch
if ($opts{'create-library'})
  {
    my @x = qw (f m p);
    for my $x (@x)
      {
        my ($dbx, @dbx) = map {"$_/db$x.pl"} ($src_drhook, @src_drhook);
        @dbx = grep { -f } @dbx;
	if ((-f $dbx) && (grep { (stat ($dbx))[9] < (stat ($_))[9] } @dbx))
	  {
            unlink ("$src_drhook/db$_.pl") for (@x);
	    last;
          }
      }
    
  }



if (-f "$src_drhook/dbf.pl")
  {
    $dbf = do ("$src_drhook/dbf.pl");
    $dbm = do ("$src_drhook/dbm.pl");
    $dbp = do ("$src_drhook/dbp.pl");
  }
else
  {
    &mkpath ($src_drhook);
    # get dr_hook db from base packs
    $dbf = 'dbf'->merge_db (map {'dbf'->load ("$_/dbf.pl")} @src_drhook);
    $dbm = 'dbm'->merge_db (map {'dbm'->load ("$_/dbm.pl")} @src_drhook);
    $dbp = 'dbp'->merge_db (map {'dbp'->load ("$_/dbp.pl")} @src_drhook);
  }

if ($opts{'create-library'})
  {

    my (@f, @p, %p2f);


    my $wanted = sub
    {
      my $f = $File::Find::name;
      for ($f)
        {
          s,^\./,,o;
        }
      return if ($f =~ m/(?:yomhook|dr_hook|drhook)/o);
      return unless ($f =~ m/\.F(?:90)?$/io);
      push @f, $f;
    };
    
    
    
    my $cwd = &cwd ();
    
    @f = $dbf->get_keys ();
    for my $d (grep { -d } <$ENV{TARGET_PACK}/src/*>)
      {
        chdir ($d);
        find ({wanted => $wanted, no_chdir => 1}, '.');
        chdir ($cwd);
      }

    &uniq (\@f);
    @f = sort { $dbf->get_val ($a) cmp $dbf->get_val ($b) } @f;

    for my $f (@f)
      {
        my $p = dirname ($f);
	push @p, $p;
	push @{$p2f{$p}}, $f;
      }

    &uniq (\@p);

    @p = sort { $dbp->get_val ($a) cmp $dbp->get_val ($b) } @p;

    
    chdir ($src_drhook);

        
   
    my $N = scalar (@f);
    my $Q = 100;

    for (my $I = 0; $I < $N; $I += $Q)
      {


	my $IQ = 1 + $I/$Q;


	my $text;
	$text = '';

	my ($I1, $I2) = ($I, $I+$Q-1 < $N ? $I+$Q-1 : $N-1);

        for my $f (@f[$I1 .. $I2])
          {
	    $dbm->set_val ($f, $IQ);
	  }


# modules
        $text .= "module " . &yomhook_fN ($IQ) . "\n";
        $text .= << "EOF";
use yomhook__all, only : dr_hook
EOF
        for my $f (@f[$I1 .. $I2])
          {
            $text .= "logical, save :: ". &lhook_f ($f) ." = .true. ! $f\n";
          }
	$text .= "end module\n";

# subhook1; pointer initialisation 
	$text .= "subroutine " . &subhook1_fN ($IQ) . "(lhook)\n";
        $text .= "use ". &yomhook_fN ($IQ) ."\n";
	$text .= << "EOF";
implicit none
logical, intent(in) :: lhook
EOF
       
        for my $I ($I1 .. $I2)
	  {
            my $f = $f[$I];
            $text .= &lhook_f ($f) . " = lhook ! $f\n";
          }
        $text .= "end subroutine\n";


# subhook2; project selection
	$text .= "subroutine " . &subhook2_fN ($IQ) . "(px,nx)\n";
        $text .= "use ". &yomhook_fN ($IQ) ."\n";
	$text .= << "EOF";
implicit none
integer :: nx
character(len=*) :: px(nx)

integer :: i
character :: c

do i = 1, nx
c = px(i)(1:1)
select case (px(i)(2:))
EOF
	for my $p (@p)
	  {
	    my %f = map { ($_, 1) } @{$p2f{$p}};

            next unless (grep { $f{$_} } @f[$I1..$I2]);

            $text .= << "EOF";
case ('$p')
select case (c)
case ('+')
EOF

            for my $I ($I1 .. $I2)
	      {
                my $f = $f[$I];
		next unless ($f{$f});
                $text .= &lhook_f ($f) . " = .true.\n";
              }

            $text .= "case ('-')\n";

            for my $I ($I1 .. $I2)
	      {
                my $f = $f[$I];
		next unless ($f{$f});
                $text .= &lhook_f ($f) . " = .false.\n";
              }

            $text .= "end select\n";
          }

        $text .= << "EOF";
case ('')
exit
end select
enddo
end subroutine
EOF


# subhook3; file selection
	$text .= "subroutine " . &subhook3_fN ($IQ) . "(fx,nx)\n";
        $text .= "use ". &yomhook_fN ($IQ) ."\n";
	$text .= << "EOF";
implicit none
integer :: nx
character(len=*) :: fx(nx)

integer :: i
character :: c

do i = 1, nx
c = fx(i)(1:1)
select case (fx(i)(2:))
EOF
        for my $I ($I1 .. $I2)
          {
            my $f = $f[$I];
	    $text .= "case ('$f')\n"
	           . "select case (c)\n"
		   . "case ('+')\n"
	           . &lhook_f ($f) . " = .true.\n"
	           . "case ('-')\n"
		   . &lhook_f ($f) . " = .false.\n"
		   . "end select\n";
          }

        $text .= << "EOF";
case ('')
exit
end select
enddo
end subroutine
EOF

	if ($opts{debug})
	  {
# subhook4; print settings
            $text .= "subroutine " . &subhook4_fN ($IQ) . "\n";
            $text .= "use ". &yomhook_fN ($IQ) ."\n";
            $text .= << "EOF";
implicit none
character :: c
EOF

          for my $I ($I1 .. $I2)
            {
              my $f = $f[$I];
              $text .= "c = '-'\n"
	             . "if(" . &lhook_f ($f) . ") c = '+'\n"
	             . "print *, c//\"$f\"\n";
            }

          $text .= << "EOF";
end subroutine
EOF
	  }

	# fail if file is different and IQ+1 exists
	my $failifdiff = -f &yomhook_fN ($IQ+1) .'.f90';
        &update (&yomhook_fN ($IQ) .'.f90', $text, $failifdiff);
      }




# main module

    my $NP = scalar (@p);
    my $NF = scalar (@f);

    my $text = '';

    my $debug_drhook  = $opts{debug} ? "print *, \" cdname = \", cdname, \" kswitch = \", kswitch \n" : "";
    my $debug_suhook1 = $opts{debug} ? "print *, \" suhook \"\n" : "";

    $text .= << "EOF";
module yomhook__all

use yomhook, only : yomhook_dr_hook => dr_hook
use parkind1, only : jpim, jprb

implicit none

public :: dr_hook

interface dr_hook
module procedure &
  dr_hook_default, &
  dr_hook_file, &
  dr_hook_size, &
  dr_hook_file_size, &
  dr_hook_multi_default, &
  dr_hook_multi_file, &
  dr_hook_multi_size, &
  dr_hook_multi_file_size
end interface

logical, save :: first_time = .true. 

contains

subroutine dr_hook_default(cdname,kswitch,pkey)
character(len=*),   intent(in)    :: cdname
integer(kind=jpim), intent(in)    :: kswitch
real(kind=jprb),    intent(inout) :: pkey

$debug_drhook
if (first_time) call suhook__all
call yomhook_dr_hook(cdname,kswitch,pkey)

end subroutine dr_hook_default

subroutine dr_hook_multi_default(cdname,kswitch,pkey)
character(len=*), intent(in) :: cdname
integer(kind=jpim),        intent(in) :: kswitch
real(kind=jprb),        intent(inout) :: pkey(:)

if (first_time) call suhook__all
call yomhook_dr_hook(cdname,kswitch,pkey)

end subroutine dr_hook_multi_default

subroutine dr_hook_file(cdname,kswitch,pkey,cdfile)
character(len=*), intent(in) :: cdname,cdfile
integer(kind=jpim),        intent(in) :: kswitch
real(kind=jprb),        intent(inout) :: pkey

if (first_time) call suhook__all
call yomhook_dr_hook(cdname,kswitch,pkey,cdfile)

end subroutine dr_hook_file

subroutine dr_hook_multi_file(cdname,kswitch,pkey,cdfile)
character(len=*), intent(in) :: cdname,cdfile
integer(kind=jpim),        intent(in) :: kswitch
real(kind=jprb),        intent(inout) :: pkey(:)

if (first_time) call suhook__all
call yomhook_dr_hook(cdname,kswitch,pkey,cdfile)

end subroutine dr_hook_multi_file

subroutine dr_hook_size(cdname,kswitch,pkey,ksizeinfo)
character(len=*), intent(in) :: cdname
integer(kind=jpim),        intent(in) :: kswitch,ksizeinfo
real(kind=jprb),        intent(inout) :: pkey

if (first_time) call suhook__all
call yomhook_dr_hook(cdname,kswitch,pkey,ksizeinfo)

end subroutine dr_hook_size

subroutine dr_hook_multi_size(cdname,kswitch,pkey,ksizeinfo)
character(len=*), intent(in) :: cdname
integer(kind=jpim),        intent(in) :: kswitch,ksizeinfo
real(kind=jprb),        intent(inout) :: pkey(:)

if (first_time) call suhook__all
call yomhook_dr_hook(cdname,kswitch,pkey,ksizeinfo)

end subroutine dr_hook_multi_size

subroutine dr_hook_file_size(cdname,kswitch,pkey,cdfile,ksizeinfo)
character(len=*), intent(in) :: cdname,cdfile
integer(kind=jpim),        intent(in) :: kswitch,ksizeinfo
real(kind=jprb),        intent(inout) :: pkey

if (first_time) call suhook__all
call yomhook_dr_hook(cdname,kswitch,pkey,cdfile,ksizeinfo)

end subroutine dr_hook_file_size

subroutine dr_hook_multi_file_size(cdname,kswitch,pkey,cdfile,ksizeinfo)
character(len=*), intent(in) :: cdname,cdfile
integer(kind=jpim),        intent(in) :: kswitch,ksizeinfo
real(kind=jprb),        intent(inout) :: pkey(:)

if (first_time) call suhook__all
call yomhook_dr_hook(cdname,kswitch,pkey,cdfile,ksizeinfo)

end subroutine dr_hook_multi_file_size

subroutine suhook__all

integer, parameter :: pmax = $NP
integer, parameter :: fmax = $NF

logical :: lhook

character(len=32) :: projects_hook(3*pmax)
character(len=64) :: files_hook(3*fmax)

namelist /namhook__all/ lhook, projects_hook, files_hook

integer :: ioerr

$debug_suhook1

if(first_time) then
  first_time = .false.
else
  return
endif

lhook         = .false.
projects_hook = ''
files_hook    = ''

EOF

    for (my $I = 0; $I < $N; $I += $Q)
      {
        $text .= "call ". &subhook1_fN (1+$I/$Q) . "(lhook)\n";
      }

    $text .= << "EOF";

open (77, file = 'namelist.hook_all', form = 'formatted', status = 'old', iostat = ioerr)
if (ioerr .ne. 0) goto 999
    
read(77, nml = namhook__all, iostat = ioerr)
if (ioerr .ne. 0) call abor1 ('ERROR WHILE READING namhook__all')

close (77)

EOF


    for (my $I = 0; $I < $N; $I += $Q)
      {
        $text .= "call ". &subhook1_fN (1+$I/$Q) . "(lhook)\n";
      }

    for (my $I = 0; $I < $N; $I += $Q)
      {
        $text .= "call ". &subhook2_fN (1+$I/$Q) . "(projects_hook,size(projects_hook))\n";
      }

    $text .= "\n";

    for (my $I = 0; $I < $N; $I += $Q)
      {
        $text .= "call ". &subhook3_fN (1+$I/$Q) . "(files_hook,size(files_hook))\n";
      }

    $text .= "\n 999 continue\n";

    if ($opts{debug})
      {
        $text .= "\n"
	      .  "print *, \"! yomhook__all settings\n";

        for (my $I = 0; $I < $N; $I += $Q)
          {
            $text .= "call ". &subhook4_fN (1+$I/$Q) . "\n";
          }

      }
    $text .= << "EOF";

end subroutine
end module

EOF

    &update ('yomhook__all.f90', $text);

    my @H = qw (
              xrd/include/dr_hook_util.h
              xrd/include/dr_hook_util_multi.h
	    );
    my @F = qw (
              xrd/module/parkind1.F90 
              xrd/module/yomhook.F90
	    );
    for my $F (@H, @F)
      {
        my $F1 = &resolve_filename ($F);
	my $F2 = basename ($F1);
        copy ($F1, $F2)
          or die ("Cannot copy $F1\n");
      }

    for my $F (map ({basename ($_)} @F), 
	       'yomhook__all.f90',
	       <yomhook_??????.f90>, 
              )
      {
	(my $O = $F) =~ s/\.f.*$/.o/oi;
	next if (-f $O && (-M $O <= -M $F));
        &cmd ("$opts{fc} $F");
      }

    my $A = 'libyomhook__all.a';
    my @O = ('yomhook__all.o', <yomhook_??????.o>);
    unlink ($A);
    &cmd ("$opts{ar} $A @O");
  
    $dbf->save ("$src_drhook/dbf.pl");
    $dbm->save ("$src_drhook/dbm.pl");
    $dbp->save ("$src_drhook/dbp.pl");
  }
elsif ($opts{'ldflags'})
  {
    print join (' ', '-L', $src_drhook, '-lyomhook__all') . "\n";
  }
elsif ($opts{'fflags'})
  {
    my ($f) = @ARGV;

    if ($opts{'base-dir'})
      {
        $f =~ s/^$opts{'base-dir'}//o;
	$f =~ s,^/,,o;
      }

    unless ($opts{'full-cpp-flags'})
      {
        print join (' ', '-D_YOMHOOK__ALL', "$ENV{MODINC} $src_drhook") . "\n";
        goto END;
      }

    my @yomhook = qw (YOMHOOK yomhook);
    my @lhook   = qw (LHOOK   lhook);

    unless ($opts{'noscan-file'})
      {
	my $g = &resolve_filename ($f);
        my $code = &slurp ($g);
	@yomhook = (@yomhook, ($code =~ m/\b(yomhook)\b/gomis));
	@lhook   = (@lhook,   ($code =~ m/\b(lhook)\b/gomis));

	&uniq (\@yomhook);
	&uniq (\@lhook);
      }

    (my $yomhook_d = &yomhook_f ($f, 1)) 
      or (@yomhook = ());

    (my $lhook_d = &lhook_f ($f, 1)) 
      or (@lhook = ());

    print join (' ', '-D_YOMHOOK__ALL', "$ENV{MODINC} $src_drhook", 
	        map ({ "-D$_=$yomhook_d" } @yomhook),
	        map ({ "-D$_=$lhook_d" } @lhook),
	       ) . "\n";
  }
elsif ($opts{'preprocess'})
  {
    my ($f, $f1) = @ARGV;

    if ($opts{'base-dir'})
      {
        $f =~ s/^$opts{'base-dir'}//o;
	$f =~ s,^/,,o;
      }

    my $g = &resolve_filename ($f);
    my $code = &slurp ($g);


    if (my $yomhook_d = &yomhook_f ($f, 1)) 
      {
        $code =~ s/\b(yomhook)\b/$yomhook_d/gomis;
      }

    if (my $lhook_d = &lhook_f ($f, 1)) 
      {
        $code =~ s/\b(lhook)\b/$lhook_d/gomis;
      }


    'FileHandle'->new ('>'. $f1)->print ($code);

    
  }
elsif ($opts{'clean-code'})
  {
    chdir ($src_drhook);
    for (<*>)
      {
        next if (m/\.pl$/o);
        unlink ($_);
      }
  }
elsif ($opts{'clean'})
  {
    rmtree ($src_drhook);
  }


END:



