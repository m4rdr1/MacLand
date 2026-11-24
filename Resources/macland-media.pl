use strict;
use DynaLoader;

my $lib = DynaLoader::dl_load_file($ARGV[0], 0) or die "macland-media: " . DynaLoader::dl_error() . "\n";
my $sym = DynaLoader::dl_find_symbol($lib, "macland_media") or die "macland-media: symbol missing\n";
my $run = DynaLoader::dl_install_xsub("main::run", $sym);
&$run();
