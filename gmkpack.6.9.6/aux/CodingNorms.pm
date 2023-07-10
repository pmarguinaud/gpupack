package CodingNorms;

use strict;
use warnings;
use Digest::SHA    qw(sha1_base64);
use File::Basename qw(basename);
use Getopt::Long   qw(GetOptions);

use Data::Dumper   qw(Dumper);

$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

#RJ-later something fishy happens if I don't include $study_called here
#RJ       for odb/aux/cma_prt_stat.F90
use Fortran90_stuff qw( $name $nest_par
                        parse_prog_unit getvars find_unused_vars
                        doctor_viol_v2 get_calls_inc_v2 );

use base 'Exporter';
our @EXPORT    = qw();
our @EXPORT_OK = qw( %FORMAT_RULES %NORMS %NORMS_BY_ID %NORMS_BY_NAME Id2Seq
                     $norms_reportFile %norms_config
                     setup_checker PrintStats PrintReportFile
                     simple_checks check_variables
                     check_line_rules check_interface_blocks
                     check_cpp_simple );

our (%{norms_config},%{norms_whitelist},@{norms_supress});

our (${norms_reportFile},%{norms_stats});

our %FORMAT_RULES=(NESTING_INDENTATION=>2,
                   MAX_LINE_LENGTH=>132,
                   MAX_NESTING_DEPTH=>3,
                   MAX_MODULE_ENTITIES=>20,
                   MAX_SUBROUTINE_STATEMENTS=>300,
                   MAX_DUMMY_ARGS=>50,
                  );

#RJ: for fortran keyword/intrinsics name use detection, based on gfortran frontend
our %RESERVED = map { $_ => 1 } qw(
    ABORT ABS ABSTRACT ACCESS ACHAR ACOS ACOSH ADJUSTL ADJUSTR
    AIMAG AINT ALARM ALL ALLOCATABLE ALLOCATE ALLOCATED
    AND ANINT ANY ASIN ASINH ASSIGN ASSOCIATE ASSOCIATED
    ASYNCHRONOUS ATAN ATAN2 ATANH ATOMIC_DEFINE ATOMIC_REF
    BACKSPACE BACKTRACE
    BESSEL_J0 BESSEL_J1 BESSEL_JN BESSEL_Y0 BESSEL_Y1 BESSEL_YN
    BGE BGT BIND BIT_SIZE BLE BLOCK BLT BTEST
    CALL CASE C_ASSOCIATED CEILING
    C_F_POINTER C_F_PROCPOINTER C_FUNLOC
    CHAR CHDIR CHMOD CLASS C_LOC CLOSE CMPLX CODIMENSION
    COMMAND_ARGUMENT_COUNT COMMON COMPILER_OPTIONS COMPILER_VERSION
    COMPLEX CONJG CONTAINS CONTIGUOUS CONTINUE COS COSH COUNT
    CPU_TIME CRITICAL CSHIFT C_SIZEOF CTIME CYCLE
    DATA DATE_AND_TIME DBLE DCMPLX DEALLOCATE DEFERRED DIGITS DIM
    DIMENSION DO DOT_PRODUCT DPROD DREAL DSHIFTL DSHIFTR DTIME
    ELEMENTAL ELSE ELSEWHERE END ENDDO ENDFILE ENDFUNCTION ENDIF
    ENDINTERFACE ENDMODULE ENDPROGRAM ENDSUBROUTINE ENDTYPE ENDWHERE
    ENTRY ENUM ENUMERATOR EOSHIFT EPSILON EQUIVALENCE
    ERF ERFC ERFC_SCALED ERROR ETIME EXECUTE_COMMAND_LINE EXIT
    EXIT EXP EXPONENT EXTENDS EXTENDS_TYPE_OF EXTERNAL
    FDATE FGET FGETC FINAL FLOOR FLUSH FMT FNUM FORALL FORMAT
    FPUT FPUTC FRACTION FREE FSEEK FSTAT FTELL FUNCTION
    GAMMA GENERIC GERROR
    GETARG GET_COMMAND GET_COMMAND_ARGUMENT
    GETCWD GETENV GET_ENVIRONMENT_VARIABLE
    GETGID GETLOG GETPID GETUID GMTIME GOTO
    HOSTNM HUGE HYPOT
    IACHAR IALL IAND IANY IARGC IBCLR IBITS IBSET ICHAR IDATE
    IEOR IERRNO IF IMAGE_INDEX IMPLICIT IMPORT INCLUDE
    INDEX INQUIRE INT INT2 INT8 INTENT INTERFACE INTRINSIC
    IOR IPARITY IRAND ISATTY ISHFT ISHFTC ISIGN ISNAN ITIME
    IS_IOSTAT_END IS_IOSTAT_EOR
    KILL KIND
    LBOUND LCOBOUND LEADZ LEN LEN_TRIM LGE LGT LINK LLE LLT LNBLNK
    LOC LOCK LOG LOG10 LOG_GAMMA LOGICAL LONG LSHIFT LSTAT LTIME
    MALLOC MASKL MASKR MATMUL MAX MAXEXPONENT MAXLOC MAXVAL
    MCLOCK MCLOCK8 MERGE MERGE_BITS MIN MINEXPONENT
    MINLOC MINVAL MOD MODULE MODULO MOVE_ALLOC MVBITS
    NAME NAMELIST NEAREST NEW_LINE NINT NON_OVERRIDABLE NOPASS
    NORM2 NOT NULL NULLIFY NUM_IMAGES
    OFFSET ONLY OPEN OPERATOR OPTIONAL OR
    PACK PARAMETER PARITY PASS PAUSE PERROR POINTER
    POPCNT POPPAR PRECISION PRESENT PRINT PRIVATE PROCEDURE
    PRODUCT PROGRAM PROTECTED PUBLIC PURE
    RADIX RAN RAND RANDOM_NUMBER RANDOM_SEED RANGE RANK READ
    REAL RECURSIVE REF RENAME REPEAT RESHAPE RESULT RETURN
    REWIND REWRITE RRSPACING RSHIFT
    SAME_TYPE_AS SAVE SCALE SCAN SECNDS SECOND SELECT
    SELECTED_CHAR_KIND SELECTED_INT_KIND SELECTED_REAL_KIND
    SEQUENCE SET_EXPONENT SHAPE SHIFTA SHIFTL SHIFTR SIGN
    SIGNAL SIN SINH SIZE SIZEOF SLEEP SPACING SPREAD
    SQRT SRAND STAT STOP STORAGE_SIZE SUBMODULE
    SUBROUTINE SUM SYMLNK SYNC SYSTEM SYSTEM_CLOCK
    TAN TANH TARGET THEN THIS_IMAGE TIME TIME8 TINY
    TRAILZ TRANSFER TRANSPOSE TRIM TTYNAM
    UBOUND UCOBOUND UMASK UNLINK UNLOCK UNPACK USE
    VAL VALUE VERIFY VOLATILE
    WAIT WHERE WHILE WRITE
    XOR );


our %NORMS=(PRESENTATION=>{_id=>1,
                           _title=>"Standards for presentation of the code",
                           HEADER=>{_id=>1,
                                    _title=>"Procedures must start with a properly formatted English documentation header",
                                   },
                           VARIABLE_DECLARATIONS=>{_id=>2,
                                                   _title=>"Rules for variable declarations",
                                                   LOCATION=>{_id=>"a",
                                                              _title=>"Variables must be declared just after declaration header, in order",
                                                             },
                                                   SEPARATION=>{_id=>"b",
                                                                _title=>"Variables should be declared separately and grouped by type and attributes with separating commas at the end of the line",
                                                               },
                                                   READABLE_USE=>{_id=>"c",
                                                                  _title=>"In USE lists, the items must be presented in an easily readable manner",
                                                                 }
                                                  },
                           CODE_BODY=>{_id=>3,
                                       _title=>"Rules for Code Body",
                                       SPLIT=>{_id=>"a",
                                               _title=>"The code body must be split in sections and subsections which should be clearly separated",
                                              },
                                       LINE_LENGTH=>{_id=>"b",
                                                     _title=>"Lines should be broken in a readable manner with no more than $FORMAT_RULES{MAX_LINE_LENGTH} characters per line",
                                                    },
                                       NESTING=>{_id=>"c",
                                                 _title=>"Nesting of conditional blocks should not be more than $FORMAT_RULES{MAX_NESTING_DEPTH} levels deep",
                                                },
                                       LABELED=>{_id=>"d",
                                                 _title=>"Deeply nested, long or complex blocks should be given character labels",
                                                },
                                      },
                           INDENTATION=>{_id=>4,
                                         _title=>"Rules for Indentation",
                                         START_COLUMN=>{_id=>"a",
                                                        _title=>"Code starts at column 1, except within conditional block and DO loops",
                                                       },
                                         BLOCK_INDENT=>{_id=>"b",
                                                        _title=>"Within nested blocks, code must be indented by $FORMAT_RULES{NESTING_INDENTATION} blank spaces for every level of nesting",
                                                       },
                                        },
                           MODULE_NAMING=>{_id=>5,
                                           _title=>"Naming scheme for modules",
                                           MOD_POSTFIX=>{_id=>"a",
                                                         _title=>"All modules should end with \"_mod\"",
                                                        },
                                           MODULE_NAME_CONSISTENCY=>{_id=>"b",
                                                                     _title=>"Module file name should match the name of the module it contains",
                                                                    },
                                          },
                           OPT_ARGS_LABELED=>{_id=>6,
                                              _title=>"In calls, optional arguments must be lavelled, not resolved by position",
                                             },
                           CONTINUATION_LINES=>{_id=>7,
                                                _title=>"An ampersand (&) followed by identation is mandatory for continuation lines",
                                               },
                           CALL_ARG_BREAKS=>{_id=>8,
                                             _title=>"Long lists of arguments to CALL statements should be broken in the same places as the continuation marks in the SUBROUTINE statement",
                                            },
                           DR_HOOK=>{_id=>9,
                                     _title=>"Rules for DR_HOOK",
                                     _type=>"S",
                                     FIRST_LAST_STATEMENTS=>{_id=>"a",
                                                             _type=>"S",
                                                             _title=>"The first and last executable statements in a subroutine must be calls to DR_HOOK",
                                                            },
                                     STRING_ARG_NAME=>{_id=>"b",
                                                       _type=>"S",
                                                       _title=>"The string argument to DR_HOOK call must give the name of the subroutine",
                                                      },
                                     CONTAINED_SUBROUTINE=>{_id=>"c",
                                                            _title=>"Contained subroutine name in DR_HOOK should be <parent_routine>\%<contained_routine>",
                                                           },
                                     ONOFF_ARG=>{_id=>"d",
                                                 _type=>"S",
                                                 _title=>"Second argument to DR_HOOK should be 0 or 1",
                                                },
                                     ZHOOK_HANDLE=>{_id=>"e",
                                                    _type=>"S",
                                                    _title=>"Third argument to DR_HOOK should be \"ZHOOK_HANDLE\"",
                                                   },
                                    },
                           END_STATEMENT=>{_id=>10,
                                           _title=>"END statement must include the name of the subroutine",
                                          },
                          },
            PRELIMINARY_DESIGN=>{_id=>2,
                                 _title=>"Preliminary design of the code",
                                 ENCAPSULATION=>{_id=>1,
                                                 _title=>"Rules for Encapsulation",
                                                 SPLITTING=>{_id=>"a",
                                                             _title=>"Modules should be split to avoid length or over complex files",
                                                            },
                                                 MAX_ENTITIES=>{_id=>"b",
                                                                _title=>"The number of entities should be limited to a reasonable number ($FORMAT_RULES{MAX_MODULE_ENTITIES})",
                                                               },
                                                },
                                 LIMIT_SUBROUTINE_STATEMENTS=>{_id=>2,
                                                               _title=>"Subroutines should have no more than $FORMAT_RULES{MAX_SUBROUTINE_STATEMENTS} executable statements",
                                                              },

                                 COSMETIC_CHANGES=>{_id=>3,
                                                    _title=>"Avoid cosmetic changes that will make merges difficult",
                                                   },
                                 DECLARATIONS_UNUSED_VARIABLES=>{_id=>4,
                                                                 _title=>"Declarations of unused variables must be removed",
                                                                },
                                 VARIABLE_SUFFIX=>{_id=>5,
                                                   _title=>"Rules for variable suffixes",
                                                  LOCAL=>{_id=>"a",
                                                          _title=>"Variables suffixed with \"L\" are local in the sense of the parallel distribution",
                                                         },
                                                  GLOBAL=>{_id=>"b",
                                                           _title=>"Variables suffixed with \"G\" are global in the sense of the parallel distribution",
                                                          },
                                                 },
                                 ARRAY_SYNTAX=>{_id=>6,
                                                _title=>"The use of array syntax is not recommended except for initialization and very basic computations",
                                               },
                                 COMMON_CODE=>{_id=>7,
                                               _title=>"Common code should be extracted to a separate subroutine or function. Cut and paste of existing code should be avoided",
                                              },
                                 LECMWF=>{_id=>8,
                                          _title=>"The variable \"LECMWF\" should only be used in setup subroutines",
                                         },
                                 LELAM=>{_id=>9,
                                         _title=>"The variable \"LELAM\" is not to be used below the subroutine \"SCAN2M\"",
                                        },
                                 LFILFA_OR_GRIB=>{_id=>10,
                                                  _title=>"The choice between LFI/LFA or GRIB format should only be made using variables \"LARPEGEF\"/\"LARPEGEF_xx\" (not \"LECMWF\")",
                                                 },
                                 MPL=>{_id=>11,
                                       _title=>"The MPL package must be used as the interface for any message passing",
                                      },
                                 DERIVED_TYPES=>{_id=>12,
                                                 _title=>"Derived tyoes should be declared in a module",
                                                },
                                 THREADSAFE=>{_id=>13,
                                              _title=>"Code must be threadsafe",
                                             },
                                },
            DETAILED_DESIGN=>{_id=>3,
                              _title=>"Detailed design of the code",
                              ABNORMAL_TERMINATION=>{_id=>1,
                                                     _title=>"Abnormal termination must be invoke by \"ABORT1\"",
                                                    },
                              SAVE_VARS_IN_DATA_MODULES=>{_id=>2,
                                                          _title=>"Variables in data modules must be saved using the SAVE statement",
                                                         },
                              PERM_ARRAY_SHAPE_TYPE=>{_id=>3,
                                                      _title=>"Array shape and variable type must not be changed when passed to a subroutine",
                                                     },
                              SELECT_CASE=>{_id=>4,
                                            _title=>"Use SELECT CASE where possible instead of IF/ELSEIF/ELSE/ENDIF",
                                           },
                              INTERFACE_BLOCK=>{_id=>5,
                                                _title=>"For each called routine there must be a \"#include\" statement including an explicit interface block for the routine",
                                                NO_INTERFACE_BLOCK=>{_id=>"a",
                                                                     _title=>"For each called routine there must be a \"#include\" statement including an explicit interface block for the routine",
                                                                     _type=>"E",
                                                                    },
                                                UNNECESSARY_INTERFACE_BLOCK=>{_id=>"b",
                                                                              _title=>"Unnecessary interface blocks should not be included",
                                                                             },
                                               },
                              MAX_DUMMY_ARGS=>{_id=>6,
                                               _type=>"I",
                                               _title=>"Routines should have no more than $FORMAT_RULES{MAX_DUMMY_ARGS} dummy arguments",
                                              },
                              VAR_NAMES=>{_id=>7,
                                          _title=>"Rules for variable names",
                                          ENGLISH=>{_id=>"a",
                                                    _title=>"Variable names should be meaningful to an English reader",
                                                   },
                                          SHORT=>{_id=>"b",
                                                  _title=>"Very short variable names should be reserved for loop indicies",
                                                 },
                                         },
                              VAR_PREFIX_SUFFIX=>{_id=>8,
                                                  _title=>"Conventional prefixes or suffixes are to be used for all variables except derived types",
                                                 },
                              ALADIN=>{_id=>9,
                                       _title=>"Rules for Aladin subroutine names",
                                       GENERAL=>{_id=>"a",
                                                 _title=>"Aladin routines that are counterparts of IFS/Arpege routines should have the same name prefixed with \"E\"",
                                                },
                                       SETUP=>{_id=>"b",
                                               _title=>"Aladin setup routines that are counterparts of IFS/Arpege routines (prefixed \"SU\") should have the same name prefixed with \"SUE\"",
                                              },
                                      },
                              OUTPUT_UNIT=>{_id=>10,
                                            _title=>"Rules for output unit",
                                            OUTPUT=>{_id=>"a",
                                                     _title=>"The logical unit for output listing is \"NULOUT\"",
                                                    },
                                            DETERMINISTIC=>{_id=>"b",
                                                            _title=>"Output to \"NULOUT\" must be deterministic and should not chnage according to parallel distribution or time of running the job",
                                                           },
                                            ERROR_MESSAGES=>{_id=>"c",
                                                             _title=>"Error messages should be written to unit \"NULERR\"",
                                                            },
                                           },
                              UNIVERSAL_CONSTANTS=>{_id=>11,
                                                    _title=>"Rules for universal constants",
                                                    YOMCST=>{_id=>"a",
                                                             _title=>"Universal constants must be stored, saved and initialized in data module \"YOMCST\"",
                                                            },
                                                    MODIFICATION=>{_id=>"b",
                                                                   _title=>"Universal constants cannot be modified",
                                                                  },
                                                    DUMMY_ARGS=>{_id=>"c",
                                                                 _title=>"Universal constants should not be access via dummy arguments",
                                                                },
                                                   },
                              MPL_CDSTRING=>{_id=>12,
                                             _type=>"S",
                                             _title=>"Calls to MPL subroutines should provide a \"CDSTRING\" identifying the caller",
                                            },
                              SOURCE_DIRECTORY=>{_id=>13,
                                                 _title=>"Each source file must be put in the proper directory for its project",
                                                },
                              RUNTIME_VAR_SPECIFICATION=>{_id=>14,
                                                          _title=>"Runtime specification of variables must be done using namelists",
                                                         },
                              DATA_STATEMENT=>{_id=>15,
                                               _title=>"DATA statement should be avoided if possible, and is only permitted for small lists",
                                              },
                             },
            FORTRAN_CODING_STANDARDS=>{_id=>4,
                                       _title=>"Detailed Fortran coding standards",
                                       F90_FREE_FORMAT=>{_id=>1,
                                                         _title=>"The code should be Fortran 90 free format",
                                                        },
                                       CONSISTENT_STYLE=>{_id=>2,
                                                          _title=>"Use a consistent style throughout each module and subroutine",
                                                         },
                                       NO_TAB=>{_id=>3,
                                                _title=>"The TAB character is not permitted",
                                                _type=>"S",
                                               },
                                       IMPLICIT_NONE=>{_id=>4,
                                                       _type=>"S",
                                                       _title=>"\"IMPLICIT NONE\" is mandatory in all routines",
                                                      },
                                       ARRAY_DIM_HARD_CODED=>{_id=>5,
                                                              _title=>"Array dumensions must not be hard coded",
                                                             },
                                       DECLARATION_DOUBLE_COLON=>{_id=>6,
                                                                  _type=>"S",
                                                                  _title=>"Declarations must use the notation \"::\"",
                                                                 },
                                       EXPLICIT_KIND=>{_id=>7,
                                                       _type=>"S",
                                                       _title=>"Variables and constants must be declared with explicit kind, using the kinds defined in \"PARKIND1\" and \"PARKIND2\"",
                                                      },
                                       USE_ONLY=>{_id=>8,
                                                  _title=>"All USE statements must include an \"ONLY\" clause, except for modules that override ASSIGNMENT",
                                                 },
                                       CONSTANT_PARAMETER=>{_id=>9,
                                                            _title=>"Constants should be PARAMETERs wherever possible",
                                                           },
                                       VARIABLE_PREFIX=>{_id=>10,
                                                         _title=>"Variable names should follow the prefix convention as defined in the programming standards document",
                                                        },
                                       BANNED_STATEMENTS=>{_id=>11,
                                                           _title=>"Banned statements",
                                                           STOP=>{_id=>"a", _title=>"The STOP statment is banned"},
                                                           PRINT=>{_id=>"b", _title=>"The PRINT statement is banned"},
                                                           RETURN=>{_id=>"c", _type=>"S", _title=>"The RETURN statement is banned"},
                                                           ENTRY=>{_id=>"d", _title=>"The ENTRY statement is banned"},
                                                           DIMENSION=>{_id=>"e", _type=>"S", _title=>"The DIMENSION statement is banned"},
                                                           DOUBLE_PRECISION=>{_id=>"f", _type=>"S", _title=>"The DOUBLE PRECISION statement is banned"},
                                                           COMPLEX=>{_id=>"g", _type=>"S", _title=>"The COMPLEX statement is banned"},
                                                           GOTO=>{_id=>"h", _title=>"The GO TO statement is banned"},
                                                           CONTINUE=>{_id=>"i", _title=>"The CONTINUE statement is banned"},
                                                           FORMAT=>{_id=>"j", _title=>"The FORMAT statement is banned"},
                                                           COMMON=>{_id=>"k", _type=>"S", _title=>"The COMMON statement is banned"},
                                                           EQUIVALENCE=>{_id=>"l", _title=>"The EQUIVALENCE statement is banned"},
                                                          },
                                       IMPLICIT_SIZED_ARRAYS=>{_id=>12,
                                                               _title=>"Arrays should not be declared with implicit size",
                                                              },
                                       ALLOCATABLE_AUTOMATIC=>{_id=>13,
                                                               _title=>"Rules for allocatable or automatic arrays",
                                                               ALLOCATABLE=>{_id=>"a",
                                                                             _title=>"Large arrays should be allocatable",
                                                                            },
                                                               AUTOMATIC=>{_id=>"b",
                                                                           _title=>"Small or low-level arrays should be automatic",
                                                                          },
                                                             },
                                       DEALLOCATION=>{_id=>14,
                                                      _title=>"All allocated arrays should be explicitly deallocated",
                                                     },
                                       F90_OPERATORS=>{_id=>15,
                                                       _title=>"Use Fortran90 comparison operators",
                                                      },
                                       COMPARISON=>{_id=>16,
                                                    _title=>"Rules for comparing variables",
                                                    EXPLICTLY_SET=>{_id=>"a",
                                                                    _title=>"Explicit set variables (parameters, constants, namelist variables) should always exactly compared (using \"==\" or \"\\=\" etc.",
                                                                   },
                                                    EVALUATED=>{_id=>"b",
                                                                _title=>"Evaluated variables (that may be subject to roundoff error) should be tested against a reference using a threshold",
                                                               },
                                                   },
                                       DUMMY_INTENT=>{_id=>17,
                                                      _type=>"S",
                                                      _title=>"All dummy arguments must specify the INTENT attribute",
                                                     },
                                       OPT_ARGS_ORDER=>{_id=>18,
                                                        _title=>"Optional arguments must be called in the same order they are declared",
                                                       },
                                       BLOCK_SPACE=>{_id=>19,
                                                     _title=>"Space in END/ELSE block",
                                                     END_SPACE=>{_id=>"a",
                                                                 _title=>"END statement for blocks should not have a space after END",
                                                                },
                                                     ELSE_SPACE=>{_id=>"b",
                                                                 _title=>"\"ELSEIF\" should be used in preference to \"ELSE IF\"",
                                                                },
                                                    },
                                       INACTIVE_CODE=>{_id=>20,
                                                       _title=>"Inactive (eg. commented out) code must be removed. However, explanatory comments can contain example code"},
                                       ALTERNATE_RETURNS=>{_id=>21,
                                                           _title=>"Alternate RETURNs to be avoided",
                                                          },
                                      },
           );

our (%NORMS_BY_ID,%NORMS_BY_NAME);

CreateNormsById(\%NORMS,[],[],[]);

1;

sub setup_checker{

# our (%{norms_config},%{norms_whitelist},@{norms_supress});

 my $usage="check_norm --intfbdir=<dir> [--wcheck_off] [--icheck_off] [--supress=<supress_list>] [--whitelist=<file>]\n".
           "  --intfbdir=<dir>           : Directory containing interface blocks\n".
           "  --wcheck_off               : Don\'t print status \"W\" warnings\n".
           "  --icheck_off               : Don\'t print status \"I\" warnings\n".
           "  --supress_message=<list>   : List of \":\" separated \"section.item\" pairs to ignore\n".
           "  --whitelist=<file>         : File containing list of warnings to ignore\n".
           "  --gen_whitelist            : Generate strings suitable for whitelist file\n".
           "  --stats                    : Generate stats on the frequency of each violation\n".
           "  --quiet                    : Don\'t report files that have no violations\n".
           "\n".
           "Note, all options can be supplied as enviroment variables of the same name in upper case, eg.\n".
           "INTFBDIR=<dir> or WCHECK_OFF=1 but that arguments will take precedence.\n\n".
           "whitelist file should contain lines in the format:\n".
           "FILE : <norm> : <hash>|* : <filename>|*\n".
           "or\n".
           "STRING : <norm> : <string>\n".
           "where \"*\" is a wildcard which will match anything - so be careful!\n".
           "\n";

 ${norms_config}{wcheck_off}=0;
 ${norms_config}{icheck_off}=0;
 ${norms_config}{gen_whitelist}=0;
 ${norms_config}{quiet}=0;
 ${norms_config}{supress_message}="";
 ${norms_config}{whitelist}="";
 ${norms_config}{intfbdir}="";

 for my $item (qw/intfbdir wcheck_off icheck_off supress_message whitelist gen_whitelist stats quiet/) {
   ${norms_config}{$item}=$ENV{uc($item)} if exists($ENV{uc($item)});
 }
 
 GetOptions( "intfbdir:s"        => \${norms_config}{intfbdir},
             "wcheck_off"        => \${norms_config}{wcheck_off},
             "icheck_off"        => \${norms_config}{icheck_off},
             "supress_message:s" => \${norms_config}{supress_message},
             "whitelist:s"       => \${norms_config}{whitelist},
             "gen_whitelist"     => \${norms_config}{gen_whitelist},
             "quiet"             => \${norms_config}{quiet},
             "stats"             => \${norms_config}{stats},
             "help"              => \${norms_config}{help},
           );
  if (${norms_config}{help}) { warn "$usage";exit; }

  die "INTFBDIR not defined.\n\n$usage" unless (${norms_config}{intfbdir} ne "");
  @{norms_supress}=split(/:/,${norms_config}{supress_message}) if ${norms_config}{supress_message};
  GetWhitelistFile(-file=>${norms_config}{whitelist},whitelist=>\%{norms_whitelist}) if (${norms_config}{whitelist});
}

sub CreateNormsById {
  my ($Norms,$SectionStack,$TitleStack,$NameStack)=@_;
  my ($item,$sectionId,@SectionStack,@TitleStack,@NameStack,$NameId,$count,$type);
  @SectionStack=@{$SectionStack};
  @TitleStack=@{$TitleStack};
  if (exists($Norms->{_id})) {
    push(@SectionStack,$Norms->{_id});
  }
  if (exists($Norms->{_title})) {
    push(@TitleStack,$Norms->{_title});
  }
  $sectionId=join(".",@SectionStack);
  $NameId=join(":",@{$NameStack});

  $count=0;
#RJ: force sorting of keys, reproducible reports
#RJ   for $item (keys(%{$Norms})) {
  for $item (sort(keys(%{$Norms}))) {
    next if ($item=~/^_/);
    @NameStack=(@{$NameStack},$item);
    CreateNormsById($Norms->{$item},\@SectionStack,\@TitleStack,\@NameStack);
    $count++;
  }
    if (exists($Norms->{_id}) && exists($Norms->{_title})) {
      if (! exists($NORMS_BY_ID{$sectionId})) {
        if (exists($Norms->{_type})) {
          $type=$Norms->{_type};
        } else {
          $Norms->{_type}=$type="W";
        }
#        warn "Adding $sectionId : ".join(":",@{$NameStack})." : $Norms->{_title}\n";
        $NORMS_BY_ID{$sectionId}={description=>$Norms->{_title},
                                  titleStack=>$TitleStack,
                                  nameStack=>$NameStack,
                                  type=>$type,
                                 };
        $NORMS_BY_NAME{$NameId}={sectionId=>$sectionId,
                                 description=>$Norms->{_title},
                                 titleStack=>$TitleStack,
                                 sectionStack=>$SectionStack,
                                 type=>$type,
                                };
      } else {
        warn "Attempt to redefine $sectionId : $NameId : $Norms->{_title}\n";
        warn "Existing : ".join(":",@{$NORMS_BY_ID{$sectionId}{nameStack}})." : $NORMS_BY_ID{$sectionId}{description}\n";
      }
    } else {
      warn "No _id and/or _title found for $sectionId : $NameId\n" if ($sectionId);
    }
}

sub Id2Seq {
  my ($id)=(@_);

  my ($major,$minor,$sub);
  ($major,$minor,$sub)=split(/\./,$id);
  if ($sub) {
    $sub=(ord($sub)-ord("a")+1);
  } else {
    $sub=0;
  }
  return sprintf("$major%02d%02d",$minor,$sub);
}


#RJ: should be moved to CodingNorms.pm
sub check_variables{
    my ($statements,$prog_info,$full_fname) = @_;
    my %vars=();
    my %use_vars=();

    our %RESERVED;

    &getvars(\@$statements,\%$prog_info,\%vars,\%use_vars);

#RJ: mainly used to detect parser misbehaviours, but quite usefull diagnostics
#RJ: not exactly check_unused_variables, but convenient place, low overhead ~0.6s for all hm source
#RJ: warn on fortran reserved name usage in var declarations, usually fixes are obvious
    foreach my $var (sort(keys (%vars))) {
      if($RESERVED{$var}) {
        warn "Warning[RESERVED]: variable '$var' has reserved name, should be avoided\n";
      }
    }

    my @unused_vars=();
    my @unused_use_vars=();

    &find_unused_vars(\@$statements,\%vars,\@unused_vars,\%use_vars,\@unused_use_vars);
    for (@unused_vars) {
      ReportViolation(-name=>"PRELIMINARY_DESIGN:DECLARATIONS_UNUSED_VARIABLES",
                      -message=>"Local variable \"$_\" declared but not used",
                      -file=>$$full_fname,
                      -line=>$vars{$_}->{statement}->{first_line},
                      -hash=>$vars{$_}->{statement}->{sha1},
                      -statement=>$vars{$_}->{statement}->{statement},
                     );
    }

    for ( @unused_use_vars ) {
      next if (/ASSIGNMENT\(=\)/i); # Not able to handle properly
      ReportViolation(-name=>"PRELIMINARY_DESIGN:DECLARATIONS_UNUSED_VARIABLES",
                      -message=>"Variable \"$_\" found in USE $use_vars{$_}{module}, ONLY: ... but not used",
                      -file=>$$full_fname,
                      -line=>$use_vars{$_}->{statement}->{first_line},
                      -hash=>$use_vars{$_}->{statement}->{sha1},
                      -statement=>$use_vars{$_}->{statement}->{statement},
                     );
    }

    my %doctor_viols=();
    &doctor_viol_v2(\%vars,\%doctor_viols);
    my ($item);
#RJ: force sorting of keys, reproducible reports
#RJ     foreach $item (keys (%doctor_viols)){
    foreach $item (sort(keys (%doctor_viols))){
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:VARIABLE_PREFIX",
                      -message=>"Variable \"$doctor_viols{$item}->{var}\" should have prefix \"$doctor_viols{$item}->{prefix}\"",
                      -file=>$$full_fname,
                      -line=>$doctor_viols{$item}->{statement}->{first_line},
                      -hash=>$doctor_viols{$item}->{statement}->{sha1},
                      -statement=>$doctor_viols{$item}->{statement}->{statement},
                     );
    }
}

#RJ: should be moved to CodingNorms.pm
sub check_line_rules{
    my ($lines,$full_fname)=@_;

    my $i=0;
    my $prev=0;
    my $icont=0;
    for (@$lines) {
      $i++;
      if ( length($_) > $FORMAT_RULES{MAX_LINE_LENGTH}) {
        ReportViolation(-name=>"PRESENTATION:CODE_BODY:LINE_LENGTH",
                        -message=>"Line length ".length($_)." is longer than permitted",
                        -file=>$$full_fname,
                        -line=>$i,
                        -hash=>sha1_base64($_),
                        -statement=>$_,
                       );
      }
      if(! /^ *!.*$/ and $prev) {
        $icont++;
        unless(/^( *)&/) {
          ReportViolation(-name=>"PRESENTATION:CONTINUATION_LINES",
                          -file=>$$full_fname,
                          -line=>$i,
                          -hash=>sha1_base64($_),
                          -statement=>$_,
                         );
        }
      }
      s/^( *)&(.*)$/$1$2/ if(/^ *&/);
      if( !/^ *!.*$/ && /^.+&(?: *!.*)* *$/) {
        $prev=1;
      }
      elsif(! /^ *!.*$/) {
        $prev=0;
        $icont=0;
      }
    }
}

#RJ: should be moved to CodingNorms.pm
sub check_interface_blocks{
    my ($statements,$full_fname) = @_;
    our %{norms_config};

    my %calls;
    my %intfb;
    &get_calls_inc_v2(\@$statements,\%calls,\%intfb);
#    print Dumper(\%calls);
#    print Dumper(\%intfb);
#RJ: force sorting of keys, reproducible reports
#RJ     foreach my $call (keys (%calls)) {
    foreach my $call (sort(keys (%calls))) {
      my $fname=$call.'.intfb.h';
      unless(exists($intfb{$call})) {
        next unless( -f ${norms_config}{intfbdir}.'/'.$fname );
        ReportViolation(-name=>"DETAILED_DESIGN:INTERFACE_BLOCK:NO_INTERFACE_BLOCK",
                        -file=>$$full_fname,
                        -message=>"Missing interface block for call to \"$call\"",
                        -line=>$calls{$call}->{statement}->{first_line},
                        -hash=>$calls{$call}->{statement}->{sha1},
                        -statement=>$calls{$call}->{statement}->{statement},
                       );
      }
    }
#RJ: force sorting of keys, reproducible reports
#RJ     foreach my $intf (keys (%intfb)){
    foreach my $intf (sort(keys (%intfb))){
      next if ($intfb{$intf}->{type} == 2);
      unless (exists($calls{$intf})) {
        ReportViolation(-name=>"DETAILED_DESIGN:INTERFACE_BLOCK:UNNECESSARY_INTERFACE_BLOCK",
                        -file=>$$full_fname,
                        -message=>"Unnecessary interface block for \"$intf\", no call",
                        -line=>$intfb{$intf}->{statement}->{first_line},
                        -hash=>$intfb{$intf}->{statement}->{sha1},
                        -statement=>$intfb{$intf}->{statement}->{statement},
                       );
      }
    }
}

#RJ: unneeded
#RJ sub eq_array {
#RJ     my ($ra, $rb) = @_;
#RJ     return 0 unless $#$ra == $#$rb;
#RJ     for my $i (0..$#$ra) {
#RJ       return 0 unless $ra->[$i] eq $rb->[$i];
#RJ     }
#RJ     return 1;
#RJ }

#RJ: should be moved to CodingNorms.pm
sub simple_checks{
  my ($statements,$prog_info,$full_fname) = @_;
  our($name,$nest_par);
  my(@pu_args,%pu_args,$unit_name,$uc_un);
  my %relops = ('EQ' => '==' , 'NE' => '/=' , 'LT' => '<' , 'LE' => '<=' , 'GT' => '>'  , 'GE' => '>=' );
#RJ: unneeded
#RJ   my $null='';
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
    my $in_contain=$href->{in_contain};
    my $first_line=$href->{first_line};
    my $sha1=$href->{sha1};
    my $statement=$href->{statement};
    s/\!.*\n/\n/g unless ($content eq 'comment');
    if($content eq 'FUNCTION' or $content eq 'SUBROUTINE' or $content eq 'PROGRAM'){ # Need name of routine and args
      @pu_args=();
      %pu_args=();
      my $dum=&parse_prog_unit(\$unit_name,\@pu_args);
      $uc_un=$unit_name;
      $uc_un=$href->{contain_host}.':'.$unit_name if($in_contain);
      $uc_un=$$prog_info{module_name}.':'.$unit_name if($$prog_info{is_module});
      $uc_un=uc($uc_un);

      for(@pu_args) {
        $_=uc($_);
        $pu_args{$_}++;
      }

      if (@pu_args > $FORMAT_RULES{MAX_DUMMY_ARGS}) {
        ReportViolation(-name=>"DETAILED_DESIGN:MAX_DUMMY_ARGS",
                        -message=>"Routine $unit_name has ".scalar(@pu_args),
                        -file=>$$full_fname,
                        -line=>$first_line,
                        -hash=>$sha1,
                        -statement=>$statement,
                       );
      }
    }
    if($decl or $exec) {
      if(/\t/) {
        ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:NO_TAB",
                        -file=>$$full_fname,
                        -line=>$first_line,
                        -hash=>$sha1,
                        -statement=>$statement,
                       );
      }
    }

    if($exec) {
      if (($content eq "ENDDO" && /\bEND DO\b/i) || ($content eq "ENDIF" && /\bEND IF\b/i) || ($content eq "ENDWHERE" && /\bEND WHERE\b/i)) {
        ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BLOCK_SPACE:END_SPACE",
                        -file=>$$full_fname,
                        -line=>$first_line,
                        -hash=>$sha1,
                        -statement=>$statement,
                       );

      } elsif ($content eq "ELSEIF" && /\bELSE IF\b/i) {
        ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BLOCK_SPACE:ELSE_SPACE",
                        -file=>$$full_fname,
                        -line=>$first_line,
                        -hash=>$sha1,
                        -statement=>$statement,
                       );
      }

    }
#RJ: allow fused variants too
    if($content=~/^END[ ]?(SUBROUTINE|MODULE|FUNCTION)/ ) {
      unless(/^\s*END[ ]?(SUBROUTINE|MODULE|FUNCTION) +$name/i){
        ReportViolation(-name=>"PRESENTATION:END_STATEMENT",
                        -file=>$$full_fname,
                        -line=>$first_line,
                        -hash=>$sha1,
                        -statement=>$statement,
                       );
      }
    }
    if($content eq 'RETURN') {
      if($exec == 3) {   # $exec == 3 means last executable statem
        ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:RETURN",
                        -file=>$$full_fname,
                        -line=>$first_line,
                        -hash=>$sha1,
                        -statement=>$statement,
                       );
      }
    }
    if (($content eq "RETURN" && $exec != 3) || ($content eq "IF" && $href->{content2} eq "RETURN")) {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:ALTERNATE_RETURNS",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }

    $implicit_none=1 if($content eq 'IMPLICIT NONE');
    $save=1 if($content eq 'SAVE');
    if($$prog_info{is_module}) {
      if(! $href->{in_contain}) {
        $save_hlp++ if($decl == 2);
      }
    }

    if($content eq 'DIMENSION') {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:DIMENSION",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }
    if($decl == 2) {
      unless(/::/) {
        ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:DECLARATION_DOUBLE_COLON",
                        -file=>$$full_fname,
                        -line=>$first_line,
                        -hash=>$sha1,
                        -statement=>$statement,
                       );
      }
      if($content eq 'INTEGER' or $content eq 'REAL') {
        if( ! /KIND\s*=/i) {
          ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:EXPLICIT_KIND",
                          -file=>$$full_fname,
                          -line=>$first_line,
                          -hash=>$sha1,
                          -statement=>$statement,
                         );
        }
#RJ: split real and integer cases, add missing standard kinds from parkind1 and parkind2
#RJ         elsif( (($content eq "INTEGER") && (! /\bEXTERNAL\b/i) && (! /KIND\s*=\s*JPIM/i)) || (($content eq "REAL") && (! /\bEXTERNAL\b/i) && (! /KIND\s*=\s*JPRB/i))) {
        elsif( ($content eq "INTEGER") && (! /\bEXTERNAL\b/i) && (! /KIND\s*=\s*JPI[MTBASH]/i) ) {
          ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:EXPLICIT_KIND",
                          -message=>"Unusual KIND value used",
                          -file=>$$full_fname,
                          -line=>$first_line,
                          -hash=>$sha1,
                          -statement=>$statement,
                         );
        }
        elsif( ($content eq "REAL") && (! /\bEXTERNAL\b/i) && (! /KIND\s*=\s*JPR[BMSTH]/i) ) {
          ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:EXPLICIT_KIND",
                          -message=>"Unusual KIND value used",
                          -file=>$$full_fname,
                          -line=>$first_line,
                          -hash=>$sha1,
                          -statement=>$statement,
                         );
        }
      }
    }

    if ($decl == 4) {
      unless(/^\s*USE\s*$name\s*,\s*ONLY\s*:/i){
        ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:USE_ONLY",
                        -file=>$$full_fname,
                        -line=>$first_line,
                        -hash=>$sha1,
                        -statement=>$statement,
                       );
      }
    }

    if($content eq 'GOTO' or ($content eq 'IF' and $href->{content2} eq 'GOTO')) {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:GOTO",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }
    if ($content eq 'COMMON') {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:COMMON",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }
    if ($content eq 'EQUIVALENCE') {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:EQUIVALENCE",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }
    if ($content eq 'COMPLEX') {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:COMPLEX",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }

    if ($content eq 'DOUBLE PRECISION') {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:DOUBLE_PRECISION",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }

    if ($content eq 'STOP') {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:STOP",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }

    if ($content eq 'PRINT') {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:PRINT",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }

    if ($content eq 'ENTRY') {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:ENTRY",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }

    if ($content eq 'CONTINUE') {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:CONTINUE",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }

    if ($content eq 'FORMAT') {
      ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:BANNED_STATEMENTS:FORMAT",
                      -file=>$$full_fname,
                      -line=>$first_line,
                      -hash=>$sha1,
                      -statement=>$statement,
                     );
    }

    if ($exec) {
#RJ: force sorting of keys, reproducible reports
#RJ       for my $relop (keys(%relops)) {
      for my $relop (sort(keys(%relops))) {
        if(/\.$relop\./i) {
          ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:F90_OPERATORS",
                          -message=>"Relational operator \"$relops{$relop}\" preferred to \".$relop.\"",
                          -file=>$$full_fname,
                          -line=>$first_line,
                          -hash=>$sha1,
                          -statement=>$statement,
                         );
        }
      }
    }

# Checks related to DR_HOOK
    if ($exec == 2) {
      &doctor_call($_,'0',$uc_un,$href,$$full_fname);
    }
    elsif($exec == 3 ) {
      &doctor_call($_,'1',$uc_un,$href,$$full_fname);
    }
    if($content eq 'RETURN') {
      unless($prev_exec=~/CALL\s+DR_HOOK/i){
        ReportViolation(-name=>"PRESENTATION:DR_HOOK:FIRST_LAST_STATEMENTS",
                        -message=>"RETURN without calling DR_HOOK just before",
                        -file=>$$full_fname,
                        -line=>$first_line,
                        -hash=>$sha1,
                        -statement=>$statement,
                       );
      }
      &doctor_call($prev_exec,'1',$uc_un,$href,$$full_fname);
    }
    if($content eq 'IF') {
      if($href->{content2} eq 'RETURN') {
        unless($prev_exec=~/CALL\s+DR_HOOK/i){
          ReportViolation(-name=>"PRESENTATION:DR_HOOK:FIRST_LAST_STATEMENTS",
                          -message=>"RETURN without calling DR_HOOK under same conditions just before just before",
                          -file=>$$full_fname,
                          -line=>$first_line,
                          -hash=>$sha1,
                          -statement=>$statement,
                         );

        }
        my $temp_exec=$prev_exec;
        $temp_exec=~s/IF\s*$nest_par/IF(LHOOK)/i;
        &doctor_call($temp_exec,'1',$uc_un,$href,$$full_fname);
      }
    }
    if($exec) {
      if(/\bZHOOK_HANDLE\b/i) {
        unless(/CALL\s+DR_HOOK/i){
          ReportViolation(-name=>"PRESENTATION:DR_HOOK:ZHOOK_HANDLE",
                          -file=>$$full_fname,
                          -line=>$first_line,
                          -hash=>$sha1,
                          -statement=>$statement,
                         );
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
          unless (/(CDSTRING|cdstring)\s*=\s*['"]$uc_un.*["']/) {
            ReportViolation(-name=>"DETAILED_DESIGN:MPL_CDSTRING",
                            -message=>"CDSTRING should be a\"$uc_un\"",
                            -file=>$$full_fname,
                            -line=>$first_line,
                            -hash=>$sha1,
                            -statement=>$statement,
                           );
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
              ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:DUMMY_INTENT",
                              -file=>$$full_fname,
                              -line=>$first_line,
                              -hash=>$sha1,
                              -statement=>$statement,
                             );
            }
          }
        }
      }
      $_=$href->{statement};
      s/\!.*\n/\n/g unless ($content eq 'comment');
    }
  }
  unless($implicit_none) {
    ReportViolation(-name=>"FORTRAN_CODING_STANDARDS:IMPLICIT_NONE",
                    -file=>$$full_fname,
                    -line=>"---",
                    -hash=>"---",
                    -statement=>"<NO STATEMENT>\n",
                   );
  }
  if($$prog_info{is_module}) {
    unless($save) {
      if($save_hlp) {
        ReportViolation(-name=>"DETAILED_DESIGN:SAVE_VARS_IN_DATA_MODULES",
                        -file=>$$full_fname,
                        -line=>"---",
                        -hash=>"---",
                        -statement=>"<NO STATEMENT>\n",
                       );
      }
    }
  }
}

#RJ: should be moved to CodingNorms.pm
sub doctor_call{
  my($statement,$onoff,$uc_un,$href,$full_fname1)=@_;
  my $text='first';
  $text='last' if ($onoff);
  if($statement=~/^\s*IF\s*\(\s*LHOOK\s*\)\s*CALL\s+DR_HOOK/i) {
    if($statement=~/^\s*IF\s*\(\s*LHOOK\s*\)\s*CALL\s+DR_HOOK\s*\(\'$uc_un\',$onoff,ZHOOK_HANDLE\b/){
      #All is well
    }
    elsif($statement=~/^\s*IF\s*\(\s*LHOOK\s*\)\s*CALL\s+DR_HOOK\s*\(\'$uc_un\',$onoff\b/){
      ReportViolation(-name=>"PRESENTATION:DR_HOOK:ZHOOK_HANDLE",
                      -file=>$full_fname1,
                      -line=>$href->{first_line},
                      -hash=>$href->{sha1},
                      -statement=>$href->{statement},
                     );
    }
    elsif($statement=~/^\s*IF\s*\(\s*LHOOK\s*\)\s*CALL\s+DR_HOOK\s*\(\'$uc_un\'/){
      ReportViolation(-name=>"PRESENTATION:DR_HOOK:ONOFF_ARG",
                      -message=>"Second argument should be $onoff",
                      -file=>$full_fname1,
                      -line=>$href->{first_line},
                      -hash=>$href->{sha1},
                      -statement=>$href->{statement},
                     );
    }
    elsif($statement=~/^\s*IF\s*\(\s*LHOOK\s*\)\s*CALL\s+DR_HOOK\s*\(/){
      ReportViolation(-name=>"PRESENTATION:DR_HOOK:STRING_ARG_NAME",
                      -message=>"First argument to DR_HOOK should be \"$uc_un\"",
                      -file=>$full_fname1,
                      -line=>$href->{first_line},
                      -hash=>$href->{sha1},
                      -statement=>$href->{statement},
                     );
    }
  }
  else{
    ReportViolation(-name=>"PRESENTATION:DR_HOOK",
                    -message=>"The \"$text\" executable statement is not a proper call to DR_HOOK",
                    -file=>$full_fname1,
                    -line=>$href->{first_line},
                    -hash=>$href->{sha1},
                    -statement=>$href->{statement},
                   );
  }
}

sub GetWhitelistFile {
  my %args=@_;
  my ($line,$file,$hash,$norm,$string);
  die "No whitelist file specified.\n" if ($args{-file} eq "");
  die "Whitelist file \"$args{-file}\" does not exist.\n" unless (-f $args{-file});
  open(WL,"<$args{-file}") or die "Could not open whitelist file \"$args{-file}\".\n";
  while (defined ($line=<WL>)) {
    chomp($line);
    next if ($line=~/^\s*(#.*)?\s*$/);
    if ($line=~/^\s*(?:WHITELISTID\s+:\s+)?\s*?(STRING)\s+:/) {
      ($norm,$string)=($line=~/^\s*(?:WHITELISTID\s+:\s+)?\s*?STRING\s+:\s+(.*?)\s+:\s+(.*?)\s*$/);
      $args{whitelist}->{STRING}->{$string}->{$norm}=1;
#      warn "STRING :: $string :: $norm\n";
    } else {
#      ($file,$hash,$norm)=($line=~/^\s*(?:WHITELISTID\s+:\s+)?\s*?(?:FILE\s+:)?\s*+(.*?)\s+:\s+(.*?)\s+:\s+(\S+)/);
#       warn "line: \"$line\"\n";
      ($norm,$hash,$file)=($line=~/^\s*(?:WHITELISTID\s+:\s+)?\s*?(?:FILE\s+:)?\s*(\S+)\s+:\s+(.*?)\s+:\s+(.*?)\s*$/);
      $args{whitelist}->{FILE}->{$file}->{$hash}->{$norm}=1;
#      warn "FILE :: $file :: $hash :: $norm\n";
    }
  }
  close(WL);
}

#RJ: should be moved to CodingNorms.pm
sub ReportViolation {
  my %args=@_;

  my ($norm,$supress,$base_fname,$statement,$wlnorm,$wlfile,$wlhash,$wlstring);
  our (%{norms_config},@{norms_supress},%{norms_whitelist});

  if (! exists($NORMS_BY_NAME{$args{-name}})) {
    warn "Could not locate NORM \"$args{-name}\"\n";
    return;
  } else {
    $norm=$NORMS_BY_NAME{$args{-name}};
  }
  ${norms_stats}{reported}{$norm->{sectionId}}+=0;
  ${norms_stats}{unreported}{$norm->{sectionId}}++;

  $base_fname=basename($args{-file});
  if ($args{-statement}) {
    ($statement)=($args{-statement}=~/^(.*?)\n/);
  } else {
    $statement="";
  }

  return if ($norm->{type} eq "I" && ${norms_config}{icheck_off});
  return if ($norm->{type} eq "W" && ${norms_config}{wcheck_off});
  for $supress (@{norms_supress}) {
    next if ($supress eq "");
    return if ($norm->{sectionId}=~/^$supress/);
  }

  for $wlfile (keys(%{${norms_whitelist}{FILE}})) { # Check for whitelist FILE type match
    if ($wlfile eq "*" || $base_fname=~/^$wlfile$/) {
      for $wlhash ($args{-hash},"*") {
        if (exists(${norms_whitelist}{FILE}{$wlfile}{$wlhash})) {
          for $wlnorm (keys(%{${norms_whitelist}{FILE}{$wlfile}{$wlhash}})) {
            return if ($wlnorm eq $norm->{sectionId});
          }
        }
      }
    }
  }
  if ($args{-statement}) { # Check for whitelist STRING type match
    for $wlstring (keys(%{${norms_whitelist}{STRING}})) {
      if ($args{-statement}=~/$wlstring/) {
        for $wlnorm (keys(%{${norms_whitelist}{STRING}{$wlstring}})) {
          return if ($wlnorm eq $norm->{sectionId});
        }
      }
    }
  }

  return  if ((exists(${norms_whitelist}{$base_fname}->{$args{-hash}}) && (${norms_whitelist}{$base_fname}->{$args{-hash}} eq $norm->{sectionId})) || (exists(${norms_whitelist}{$base_fname}->{"*"}) && (${norms_whitelist}{$base_fname}->{"*"} eq $norm->{sectionId})));

  print "\n\n========== Working on file $args{-file} ==========\n" unless (${norms_reportFile} eq $args{-file});
  ${norms_reportFile}=$args{-file};
  ${norms_stats}{reported}{$norm->{sectionId}}++;
  ${norms_stats}{unreported}{$norm->{sectionId}}--;

  print "$base_fname";
  print "\[$args{-line}\]" if ($args{-line}=~/^\d+$/);
#RJ: should this been $args{-statement}   ?
#RJ   print " : $statement" if ($args{-statement});
#RJ-remark gives full continuated statement, thus more output, sometimes usefull, but could be chomp'ed
  print " : $args{-statement}" if ($args{-statement});
#RJ   print "\n";
  print "  WHITELISTID : FILE : $norm->{sectionId} : $args{-hash} : $base_fname\n" if (${norms_config}{gen_whitelist});
  print "  -- ($norm->{type}) $norm->{sectionId} : $norm->{description}\n";
  print "  -- $args{-message}\n" if (exists($args{-message}));
  print "\n";

}

#RJ: should be moved to CodingNorms.pm
sub PrintStats {
  my ($sectionId,%sections);

  return unless(${norms_config}{stats});
  return unless(keys(%{norms_stats}));
  print "\n\n";
  print "==================================\n";
  print "|                                |\n";
  print "|  --Norm Violation Statistics-- |\n";
  print "|                                |\n";
  print "==================================\n";
  print "| Norm     | Reported | Hidden   |\n";
  print "|----------|----------|----------|\n";

  for $sectionId (keys(%{${norms_stats}{reported}}),keys(%{${norms_stats}{unreported}})) {
    $sections{$sectionId}=1;
  }

  for $sectionId (sort({Id2Seq($a)<=>Id2Seq($b)} (keys(%sections)))) {
    print "| ".sprintf("%-8s",$sectionId)." | ".sprintf("%8i",${norms_stats}{reported}{$sectionId})." | ".sprintf("%8i",${norms_stats}{unreported}{$sectionId})." |\n";
  }
  print "==================================\n";
}

#RJ: extra subroutine to print label of current file
sub PrintReportFile{
  my($fname)=@_;
  our (${norms_config},${norms_reportFile});
  if (! ${norms_config}{quiet}) {
    ${norms_reportFile}=$$fname;
    print "\n\n========== Working on file ${norms_reportFile} ==========\n";
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
      &cpp_warn(\$href,'W','FPP(37) : Posible issue with cpp, '."'\\' symbol at end of line",$full_fname);
    }
  }
 }
 #RJ: check if all defines are undefined at the end
 while ($def_list=~/(\b[\w]++\b)/g){
  &cpp_warn(\$null,'S','FPP(31) : Missing CPP undef for define '."$1",$full_fname);
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
      &cpp_warn($href,'S','FPP(1) : Whitespaces before CPP directve',$full_fname);
    }
    if($statement=~/^[ ]*+[\#][ ]/){
      &cpp_warn($href,'S','FPP(2) : Whitespace after CPP directive start symbol \'#\'',$full_fname);
    }
    if($statement=~/^[ ]*+[\#][ ]*+[\w]++[ ][ ]++[\w]/){
      &cpp_warn($href,'S','FPP(3) : Extra whitespace after CPP directive type',$full_fname);
    }
#RJ: ech, lets look through fingers on this
#    if($statement=~/[ ][\r\n]*$/){
#      &cpp_warn($href,'W','FPP(4) : Trailing whitespace after CPP directive',$full_fname);
#    }
    if($statement=~/[\t\f]/){
      &cpp_warn($href,'S','FPP(5) : TAB detected in CPP directive',$full_fname);
    }
    if($statement=~/([^\!\#\w\ ()\&\|\:\;\,\.\'\"\<\>\*\/\+\-\^\=\r\n\@\%]++)/){
      &cpp_warn($href,'S','FPP(6) : Characters outside [A-Z][a-z][_][ ][&|^():;,.><"\'+-*/=][@][%] detected: '."\'$1\'",$full_fname);
    }
    if($statement=~/([\;])/){
      &cpp_warn($href,'I','FPP(7) : Possible multiline CPP macro detected',$full_fname);
    }
    
#RJ: check of formats, lets be very unforgiving in fortran ;-)
    if($statement=~/^[ ]*+[\#][ ]*+([\w]++)/){
      $type=$1;
      if($type eq 'include'){
        unless($statement=~/^[\#]include[ ]++"[\w\.]++"[ \r\n]*+$/){
          &cpp_warn($href,'S','FPP(11) : Unstrict format for CPP include directive',$full_fname);
        }
      }
      elsif($type eq 'define'){
        if($statement=~/^[\#]define[ ]++([\w]++)/){
          $$def_list.=','.$1
        }
        unless($statement=~/^[\#]define[ ]++[\w]++(?:[(][\w]++[)])?+/){
          &cpp_warn($href,'S','FPP(12) : Unstrict format for CPP define directive',$full_fname);
        }
      }
      elsif($type eq 'undef'){
        if($statement=~/^[\#]undef[ ]++([\w]++)/){
          $$def_list=~s/[,]$1\b//g;
        }
        unless($statement=~/^[\#]undef[ ]++[\w]++[ \r\n]*+$/){
          &cpp_warn($href,'S','FPP(13) : Unstrict format for CPP undef directive',$full_fname);
        }
      }
      elsif($type eq 'ifdef'){
        unless($statement=~/^[\#]ifdef[ ]++[\w]++[ \r\n]*+$/){
          &cpp_warn($href,'S','FPP(14) : Unstrict format for CPP ifdef directive',$full_fname);
        }
      }
      elsif($type eq 'ifndef'){
        unless($statement=~/^[\#]ifndef[ ]++[\w]++[ \r\n]*+$/){
          &cpp_warn($href,'S','FPP(15) : Unstrict format for CPP ifndef directive',$full_fname);
        }
      }
      elsif($type eq 'else'){
        unless($statement=~/^[\#]else[ \r\n]*+$/){
          &cpp_warn($href,'S','FPP(16) : Junk after CPP else directive',$full_fname);
        }
      }
      elsif($type eq 'endif'){
        unless($statement=~/^[\#]endif[ \r\n]*+$/){
          &cpp_warn($href,'S','FPP(17) : Junk after CPP endif directive',$full_fname);
        }
      }
      elsif($type=~/(?:el)?if\b/){
        if($statement=~/^[\#]if[ ]++[\!]defined[(][\w]++[)][ \r\n]*$/){
          &cpp_warn($href,'I','FPP(36) : Safer to use simple CPP ifndef directive',$full_fname);
        }
        unless($statement=~/^[\#](?:el)?if[ ](?:[\w]++(?:[ ]*+[<>=!]++[ ]*+[\w]++)?+|(?:[!])?defined[ ]?[(][\w]++[)])(?:[ ]*+(?:[\&][\&]|[\|][\|])[ ]*+(?:(?:[!])?defined[ ]?[(][\w]++[)]|[\w]++[ ]*+[<>=!]++[ ]*+[\w]++)*+)*+[ \r\n]*+$/){
          &cpp_warn($href,'S','FPP(18) : Unstrict format for CPP if directive',$full_fname);
        }
        if($statement=~/[&][&]/){
          if($statement=~/[|][|]/){
            &cpp_warn($href,'W','FPP(33) : Avoid mixed logicals in CPP logic within fortran sources',$full_fname);
          }
       }
     }
     elsif($type eq 'error'){
       #do not check logic here, it's error
     }
     else{
       &cpp_warn($href,'W','FPP(8) : Unknown CPP directive type',$full_fname);
     }
    }else{
      &cpp_warn($href,'S','FPP(9) : Failed to get CPP directive type',$full_fname);
    }
  }
}

#RJ: simple version of ReportViolation, these warnings are not official ones
sub cpp_warn {
  my($href,$sev,$mess,$full_fname)=@_;
  my $fname=$$full_fname;
  $fname=~s/^.*[\/]//;
  if(ref($$href) eq "HASH") {
    print "$fname\[$$href->{first_line}\] : $$href->{statement}";
  }
  else {
    print "$fname:\n";
  }
  print "  -- ($sev) $mess \n\n";
}
