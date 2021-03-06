#!/usr/bin/perl

package Git::AddRepo;
use Moose;
use Carp;
use IPC::System::Simple qw(capturex);

=head1 NAME

AddRepo - A simple class for adding new bare git repos on a local server.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

 use Git::AddRepo;

 my $added_repo = Git::AddRepo->new({
                                     name => "Test Repo",
                                     dir  => "/tmp",
                                    })
   or die "Cannot create object: Error -> $!\n";


=head1 TODO

Factor out any specific stuff into a configuration file
(Do this before release.)

=cut

has name => (is => 'ro', isa => 'Str', required => 1 );
has dir  => (is => 'ro', isa => 'Str', required => 1 );
has type => (is => 'ro', isa => 'Str', required => 1, default => "git" );
has desc => (is => 'rw', isa => 'Str'                );

sub repo_details {
  my ($self) = @_;
  push my @details, $self->name, $self->dir, $self->type;
  if ($self->desc) {
    push @details, $self->desc;
  }
  return @details;
}

# --- Check to see that the repo does not already exist
sub check {
  my ($self) = @_;
  my $full_path = $self->dir . $self->name;
  if (-d "$full_path") {
    die "Warning: $full_path already exists.\nCowardly refusing to overwrite git repo.\n";
  }
  else {
    return "$full_path  doesn't currently exist, creating it . . .";
    create_repo($self->name, $self->type);
    # test_repo($url, $self->name, $self->type);
  }
}

sub create {
  use Perl6::Say;
  my ($self) = @_;
  my $full_path = $self->dir . $self->name;
  my $desc = $self->desc;
  my @git_creation = capturex('git', 'clone', '--bare', "/home/jeremiah/code/perl/TEMPLATE.git", "$full_path");
  map { say $_ } @git_creation;
  my @file_creation = capturex('touch', "$full_path/git-daemon-export-ok");
  map { say $_ } @file_creation;
  my @chown_all = capturex('chown', '-R', 'www-data:www-data', "$full_path");
  print map { $_ . "\n" } @chown_all;
  if ($desc) {
    open my $description, ">", "$full_path/description"
      or die "Cannot open $full_path/description. $!\n";
    printf $description "$desc";
  }
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
