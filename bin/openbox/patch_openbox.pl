#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Copy;
use File::Path qw(make_path);

my $exec_name  = File::Spec->rel2abs($0);
my $work_dir   = '/usr/src/openbox';
my $target_bin = "/usr/local/bin/openbox";
my $git_url    = 'git://git.openbox.org/mikachu/openbox.git';
( my $patch_file = $exec_name )
    =~ s|^(.+)(\/[^\/]+){3}|$1/conf/openbox.fullscreen_fix.patch|;

print "\n:\n: patching openbox ( fixing legacy fullscreen issue )\n:\n";

die "[!] must run as root [!]\n\n" if $<;
chomp( my $git_bin = qx(which git) );
die "[!] git binary not found [!]\n\n" if !length($git_bin) or !-x $git_bin;
chomp( my $make_bin = qx(which make) );
die "[!] make binary not found [!]\n\n" if !length($make_bin) or !-x $make_bin;
unless ( -d $work_dir ) {
    print ": creating work dir '$work_dir'..\n";
    make_path($work_dir);
}

chdir($work_dir) or die "$work_dir: $!";

my $branch_name = 'master';
my $branch_dir  = "$work_dir/$branch_name";
my $openbox_bin = "$branch_dir/openbox/openbox";

if ( !-d $branch_dir ) {

    print ": cloning openbox source...\n\n";

    die "[!] git clone failed [$@]\n\n"
        if system( $git_bin, 'clone', $git_url, $branch_name );
    chdir($branch_dir) or die "chdir($branch_dir): $!\n\n";
} else {

    print ": updating openbox source...\n\n";

    chdir($branch_dir) or die "chdir($branch_dir): $!\n\n";
    die "[!] 'git reset --hard' failed [$@]\n\n"
        if system( $git_bin, 'reset', '--hard' );

    chomp( my $pull_result = qx($git_bin pull) // '' );
    die "\n[!] 'git pull' failed! [$!]\n\n" if $!;

    if ( $pull_result eq 'Already up-to-date.' and -x $target_bin ) {
        print "\n:\n: patched openbox version is up to date :)\n: done.\n\n";
        exit(0);
    }
}
print "\n: patching openbox source...\n";

my $check_output = qx($git_bin apply --check $patch_file);
die "\n[!] patch failed [$check_output]\n\n" if length($check_output);
print ": : successfully patched! :)\n"
    if !system( $git_bin, 'apply', $patch_file );

print ": compiling....\n\n";
die "\n[!] bootstrap failed [$@]\n\n"    if system("$branch_dir/bootstrap");
die "\n[!] configure failed [$@]\n\n"    if system("$branch_dir/configure");
die "\n[!] 'make clean' failed [$@]\n\n" if system( $make_bin, 'clean' );
die "\n[!] 'make' failed [$@]\n\n"       if system($make_bin);

die "\n[!] compilation failed [openbox binary not found] :(\n\n"
    if !-x $openbox_bin;

print "\n: installing patched openbox version ..\n\n";
die "\n[!] 'make install' failed [$@]\n\n" if system( $make_bin, 'install' );
die "\n[!] installation failed (target binary not found) [!]\n\n"
    if !-x $target_bin;

print "\n:\n: (openbox) INSTALLATION SUCCESSFUL! :)\n.\n\n";

