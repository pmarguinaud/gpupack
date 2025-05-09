package Interface;

use strict;
use FileHandle;
use Data::Dumper;
use File::Basename;
use File::Path;
use File::Spec;
use File::Temp;
use Getopt::Long;
use FindBin qw ($Bin);
use lib "$Bin/../../../fxtran-acdc/lib";

use local::lib;

use fxtran;
use fxtran::xpath;
use fxtran::parser;

use Bt;

sub stmt
{
  my $e = shift;
  my @anc = reverse &F ('./ancestor::*', $e);
  my ($stmt) = grep { $_->nodeName =~ m/-stmt$/o } @anc;
  return $stmt;
}

sub intfbBody
{
  my $doc = shift;
  
  my @pu = &F ('./object/file/program-unit', $doc);
  
  for my $pu (@pu)
    {
      for (&F ('.//program-unit', $pu))
        {
          $_->unbindNode ();
        }

      for (&F ('.//cpp-section|.//cpp', $pu))
        {
          $_->unbindNode ();
        }

      my $first = $pu->firstChild;
   
      if ($first->nodeName =~ m/^(?:module|program)-stmt$/o)
        {
          $pu->unbindNode ();
          next;
        }
  
      # Strip blocks (these may contain use statements)
      
      for (&F ('.//ANY-construct', $pu))
        {
          $_->unbindNode ();
        }
  
      (my $kind = $first->nodeName ()) =~ s/-stmt$//o;
  
      my ($name) = &F ('./' . $kind . '-N/N/n/text()', $first, 1);
      my @args = &F ('.//dummy-arg-LT//arg-N/N/n/text()', $first, 1);
      
      my %stmt;
      
      # Keep first & last statements
      
      $stmt{$pu->firstChild} = $pu->firstChild;
      $stmt{$pu->lastChild}  = $pu->lastChild;
      
      # %symb holds symbols whose declaration should be kept
      # %undf holds symbols which are not defined with T-decl-stmt nor imported by use statements

      my (%symb, %undf);

      for my $arg (@args)
        {
          $symb{$arg} = 1;
        }
      
      # Keep result declaration (function)

      if ($first->nodeName eq 'function-stmt')
        {
          my ($result) = &F ('./result-spec/N', $first, 1);
           
          unless ($result)
            {
              ($result) = &F ('./function-N', $first, 1);
            }

          $symb{$result} = 1;
        }

      # Index decl statements

      my %s2d;

      for my $decl (&F ('./ANY-stmt[.//EN-decl]', $pu))
        {
          for my $symb (&F ('.//EN-N', $decl, 1))
            {
              push @{ $s2d{$symb} }, $decl;
            }
        }

      # Index use statements
      
      my %s2u;

      for my $use (&F ('./use-stmt', $pu))
        {
          for my $symb (&F ('.//use-N', $use, 1))
            {
              push @{ $s2u{$symb} }, $use;
            }
        }
      
      
      # Symbols used in decl statements of arguments
      
      my @symb = sort keys (%symb);

      while (my $symb = shift (@symb))
        {
          if (my @decl = @{ $s2d{$symb} || [] })
            {
              for my $decl (@decl)
                {
                  $stmt{$decl} = $decl;
                  for my $s (&F ('.//named-E/N', $decl), &F ('.//T-N', $decl))
                    {
                      my $t = $s->parentNode;
                      if ($t->nodeName ne 'intrinsic-T-spec')
                        {
                          $s = $s->textContent;
                          push @symb, $s unless ($symb{$s});
                          $symb{$s} = 1; 
                        }
                    }
                }
            }
          elsif (my @use = @{ $s2u{$symb} || [] })
            {
              for my $use (@use)
                {
                  $stmt{$use} = $use; 
                }
            }
          else
            {
              $undf{$symb} = 1;
            }
        }

      if (%undf)
        {
          # Keep use statements without ONLY list : they may import some of the undefined symbols

          for my $use (&F ('./use-stmt[not(./rename-LT)]', $pu))
            {
              $stmt{$use} = $use;
            }
        }

      my @stmt = &F ('./ANY-stmt', $pu);
      
      for my $stmt (@stmt)
        {
          next if ($stmt->nodeName eq 'implicit-none-stmt');
          $stmt->unbindNode () unless ($stmt{$stmt});
        }
  
    }
  

  # Strip labels
  for (&F ('.//label', $doc))
    {
      $_->unbindNode ();
    }
  
  # Strip comments
  
  for (&F ('.//C', $doc))
    {
      next if ($_->textContent =~ m/^!\$acc\s+routine/o);
      $_->unbindNode ();
    }
  
  # Strip includes
  
  for (&F ('.//include', $doc))
    {
      $_->unbindNode ();
    }

  # Strip defines

  for (&F ('.//cpp[starts-with (text(),"#define ")]', $doc))
    {
      $_->unbindNode ();
    }


  for (&F ('.//unseen', $doc))
    {
      $_->unbindNode ();
    }


  $doc->documentElement->normalize ();

  my @text = &F ('.//text()[translate(.," ?","")=""]', "\n", $doc);

  for my $text (@text)
    {
      if ($text->data =~ m/\n/goms)
        {
          $text->setData ("\n");
        }
    }


}

sub fold
{
  my $d = shift;
  my @stmt = &F ('.//ANY-stmt', $d);
  for my $stmt (@stmt)
    {
      my $s = $stmt->textContent;
      my @s;
      while (length ($s))
        {
          push @s, substr ($s, 0, 64, '');
          if ($s =~ s/^(\w+)//o)
            {
              $s[-1] .= $1;
            }
        }
      $s = join ("&\n&", @s);
      $stmt->replaceNode (&t ($s));
    }
}


sub pp
{
  'FileHandle'->new (">>/tmp/runCommand.log")->print ("@_\n");
}

sub runCommand
{
  my @cmd = @_;
  system (@cmd)
    && die ("Command `@cmd' failed");
}

sub intfb
{
  my %args = @_;

  my ($defines, $file) = @args{qw (defines file)};

  my ($text, $text_openacc, $text_parallel) = ('', '', '');

  if (-s $file)
    {
      my $tmpdir = 'File::Temp'->newdir (CLEANUP => 0, DIR => "$ENV{GPUPACK_PREFIX}/tmp");
      
      my $doc = &parse (location => $file, fopts => [@$defines, '-canonic', '-construct-tag', '-no-include', '-line-length' => 500], dir => $tmpdir);

      my @text = do { my $fh = 'FileHandle'->new ("<$file"); <$fh> };

      my ($openacc) = map { m/^!\$ACDC (singlecolumn.*)/o ? ($1) : ()  } @text;
      my ($parallel) = map { m/^!\$ACDC (pointerparallel.*)/o ? ($1) : ()  } @text;
      
      &intfbBody ($doc);

      if ($openacc)
        {    
          my $tmp = 'File::Temp'->new (SUFFIX => '.F90', UNLINK => 0);

          my $Bin = "/home/gmap/mrpm/marguina/gpupack-w/fxtran-acdc/bin";
          $tmp->print ($doc->textContent);
          $tmp->close ();

          &runCommand ("$Bin/fxtran-gen $openacc --dir " . &dirname ($tmp) .  " $tmp");

          (my $tmp_openacc = $tmp) =~ s/\.F90$/_openacc.F90/go;

          my $doc_openacc = &parse (location => $tmp_openacc, fopts => ['-construct-tag', '-no-include', '-line-length' => 500], dir => $tmpdir);
          $_->unbindNode () for (&F ('.//a-stmt', $doc_openacc), &F ('.//call-stmt', $doc_openacc));
          $text_openacc = $doc_openacc->textContent ();
          $text_openacc =~ s/^\s*\n$//goms;

        }    

      if ($parallel)
        {    
          my $tmp = 'File::Temp'->new (SUFFIX => '.F90', UNLINK => 1);
          my $Bin = "/home/gmap/mrpm/marguina/gpupack-w/fxtran-acdc/bin";
          $tmp->print ($doc->textContent);
          $tmp->close ();

          my $PACK = $ENV{TARGET_PACK};

          for my $dt ('types-fieldapi', 'types-constant')
            {   
              if (-d "$PACK/$dt")
                {
                  &runCommand ('cp', '-r', "$PACK/$dt", "$tmpdir/$dt");
                }
            }   
         
          &runCommand ("$Bin/fieldRB.pl", '--types-fieldapi-dir' => "$tmpdir/types-fieldapi");
          &runCommand ("$Bin/linkTypes.pl", '--types-fieldapi-dir' => "$tmpdir/types-fieldapi");

          &runCommand ("$Bin/fxtran-gen $parallel --types-fieldapi-dir $tmpdir/types-fieldapi --dir " . &dirname ($tmp) . " $tmp");

          (my $tmp_parallel = $tmp) =~ s/\.F90$/_parallel.F90/go;

          my $doc_parallel = &parse (location => $tmp_parallel, fopts => ['-construct-tag', '-no-include', '-line-length' => 500], dir => $tmpdir);
          $_->unbindNode () for (&F ('.//a-stmt', $doc_parallel), &F ('.//call-stmt', $doc_parallel));
          $text_parallel = $doc_parallel->textContent ();
          $text_parallel =~ s/^\s*\n$//goms;

        }    

      &fold ($doc);
      
      # Strip empty lines
      
      $text = $doc->textContent ();
      
      $text =~ s/^\s*\n$//goms;
    }

  if ($text)
    {
      $text = << "EOF";
INTERFACE
$text
$text_openacc
$text_parallel
END INTERFACE
EOF
    }

  &writefile (%args, data => $text);
}

sub modi
{
  my %args = @_;

  my ($defines, $file) = @args{qw (defines file)};

  my $TEXT = '';

  if (-s $file)
    {
      my $tmpdir = $ENV{TMPDIR} || '/tmp';
      $tmpdir = &dirname ($tmpdir . 'File::Spec'->rel2abs ($file));
      &mkpath ($tmpdir);
     
      my $doc = &parse (location => $file, fopts => [@$defines, '-canonic', '-construct-tag', '-no-include', '-line-length' => 500], dir => $tmpdir);
      
      &intfbBody ($doc);

      for my $pu (&F ('.//program-unit', $doc))
        {
     
          my ($stmt) = &F ('./ANY-stmt', $pu);
          my ($N) = &F ('./ANY-N', $stmt, 1);

          &fold ($pu);
      
          # Strip empty lines
          
          my $text = $pu->textContent ();
          
          $text =~ s/^\s*\n$//goms;

          $TEXT .= << "EOF";

MODULE MODI_$N

INTERFACE

$text

END INTERFACE

END MODULE

EOF
        }

    }

  &writefile (%args, data => $TEXT);
}

sub writefile
{
  my %args = @_;
  my $data = &slurp ($args{reference});

  if ($data eq $args{data})
    {
      print ("INTERFACE BLOCK $args{output} UNCHANGED \n");
    }
  else
    {
      print ("WRITE INTERFACE BLOCK $args{output} \n");
      &mkpath (&dirname ($args{output}));
      'FileHandle'->new (">$args{output}")->print ($args{data}) 
    }
}

sub slurp
{
  my $file = shift;
  (my $fh = 'FileHandle'->new ("<$file")) or return '';
  local $/ = undef;
  my $data = <$fh>;
  return $data;
}

1;
