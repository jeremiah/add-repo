#!/usr/bin/perl

=head1 NAME

add-repo.pl       Add a version control repository to local file system.

=head1 VERSION

Version 0.11

=head1 SYNOPSIS

add-repo [options] [arguments to options]

Options:

   -d      (--desc)         Description of repo's contents
   -h      (--help)         This help
   -l      (--local)         Use the .git repo in the local directory
   -n      (--name)         Name of new repository [required]
   -r      (--repo)         Repository's location on local file system
   -s      (--test)         Just run test suite
   -t      (--type)         Type of repo (git or svn) [required]
   -u      (--url)          URL of repo (used in test suite) [required]
   -v      (--version)      Print version and usage


=head1 DESCRIPTION

Create a git or svn repo ready to serve.

=head1 TODO

- Test the URL and bail out if it doesn't exist.
- Create a web interface to this script
- Edit relevant stanza in /etc/apache2/sites-available
- Add pure perl git calls as opposed to capturex system calls
- Stop Test::More from complaining when you don't run tests, like with the -h flag
- Should bail out if you're running a test run without having an svn repo created first
- Allow for simply adding a remote and then populating the repo remotely.

=head1 EXAMPLES

# Create a git repo with a description file
addrepo -t git --url https://git.example.org/srv/git --repo /srv/git/ -n foo.git -d "A repository for foo"

# Create a svn repo
addrepo -t svn --url https://svn.genivi.org/ -n foo

# Create a git repo ready to serve from your local git repo
addrepo -t git --url https://git.example.org/srv/git --repo /srv/git/ -n foo.git -l 

=cut

our $VERSION = '0.10';

use strict;
use warnings;
use Carp;
use Getopt::Long;
use Pod::Usage;
use IPC::System::Simple qw(capturex);

# --- Command line options
my ($name, $type, $repo_path, $url, $test, $desc, $description, $version, $local);
GetOptions
  (
   "desc|d=s" => \$desc,
   "local|l=s" => \$local,
   "name|n=s" => \$name,
   "type|t=s" => \$type,
   "repo|r=s" => \$repo_path,   # file system path
   "url|u=s" => \$url,
   "test|s" => \$test,
   "version|v" => \$version,
  ) || pod2usage(1);


if ($version) {
  print "Version: $VERSION\n";
  exit 0;
};
if ($test) { # Just run test suite
  test_repo($url, $name, $type);
  exit 0;
}
unless ($type && $type =~ /git|svn/ && $url && $name || $test) { pod2usage(1) };

# --- Our repos
my $svn = $repo_path // "/srv/svn";
my $git = $repo_path // "/srv/git";

# --- Check to see that the repo does not already exist
if ($type eq 'svn') {
  if (-d "$svn/$name") {
    croak"$svn/$name already exists.\n";
  }
  else {
    print "$svn/$name doesn't exist, creating it . . .\n";
    create_repo($name, $type);
    test_repo($url, $name, $type);
  }
}
elsif ($type eq 'git') {
  if (-d "$git/$name") {
    croak "$git/$name already exists.\n";
  }
  else {
    print "$git/$name doesn't exist, creating it . . .\n";
    create_repo($name, $type);
    test_repo($url, $name, $type);
  }
}
else {
  print "Uknown type: $type.\n";
}

=head2 create_repo

Create our repo in the locations we've established, or that might
be passed as arguments.

=cut

sub create_repo {
  my ($repo, $kind) = @_;
  if ($kind eq 'git') {
    my $template = $local // "/home/jeremiah/code/perl/TEMPLATE.git";
    my @git_creation = capturex('git', 'clone', '--bare', "$template" , "$git/$repo");
    print map { $_ . "\n" } @git_creation;
    my @file_creation = capturex('touch', "$git/$repo/git-daemon-export-ok");
    print map { $_ . "\n" } @file_creation;
    my @chown_all = capturex('chown', '-R', 'www-data:www-data', "$git/$repo");
    print map { $_ . "\n" } @chown_all;
    if ($desc) {
      open $description, ">", "$git/$repo/description"
	or die "Cannot open $description. $!\n";
      printf $description "$desc";
    }
  }
  elsif ($kind eq "svn") {
    print map { $_ . "\n" } capturex('svnadmin', 'create', "$svn/$repo");
    print map { $_ . "\n" } capturex('chown', '-R', 'www-data:www-data', "$svn/$repo");
    my @import = capturex('svn', 'import', '/home/jeremiah/code/perl/TEMPLATE.svn/',
			  "file:///srv/svn/$name",
			  '-m', 'Initial import');
    print map { $_ . "\n" } @import;
    ## add /etc/apache/sites-available hacking here.

  }
}

=head2 test_repo

Test that the repo is functional.

=cut

sub test_repo {
  my $temp = "/tmp";
  use Test::More qw(no_plan);

  my ($url, $repo, $kind) = @_;
  # We need a type and a repo
  unless ($kind && $kind =~ /git|svn/ && $repo) {
    die "No arguments found for test suite."
  };
  if ($kind eq 'git') {
    # Make sure curl does not complain about our self-signed cert
    $ENV{GIT_SSL_NO_VERIFY} = "true";
    ok($ENV{GIT_SSL_NO_VERIFY} eq "true", 'Curl will not check certs.');
    like($kind, qr/git/, "Testing git repo: $repo");
    my @clone;
    ok($url, 'URL not empty.');
    $url .= "/$repo"; # should we do more URL testing?

    # one issue here is that we're actully checking the .netrc of the user
    # if that doesn't exist, we get a 401 error of course.
    #  $url =~ /https:\/\//https:\/\/jeremiah:avkcnff64@/;
    # print "Testing $url\n";
    eval { @clone = capturex('git', 'clone', $url, "$temp/$repo") };
    print map { $_ . "\n" } @clone if $@;
    #print "Checking $temp/$repo.\n";
   ok(-d "$temp/$repo", 'Created new repository dir.');
  }
  elsif ($kind eq 'svn') {
      like($kind, qr/svn/, "Testing a svn repo");
      print map { $_ . "\n" } capturex('svn', 'list', "file:///srv/svn/$repo");
    }
};

1;
