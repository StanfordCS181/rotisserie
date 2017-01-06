use strict;
use DBI;
use HTML::Entities;

sub print_header ($) {
  my ( $page_title ) = @_;

  open HEADER, q{web-header.html} or die;
  while (<HEADER>) {
    s{TITLE_GOES_HERE}{$page_title}g;
    print;
  }
  close HEADER or die;
}

sub finish {
  open FOOTER, q{web-footer.html} or die;
  while (<FOOTER>) {
    print;
  }
  close FOOTER or die;

  exit 0;
}

sub database {
  my $dbh = DBI->connect( q{dbi:Pg:dbname=cs181_winter2017} ) or die qq{$DBI::errstr};
  return $dbh;
}

sub login ($) {
  my ( $dbh ) = @_;

  # get sunetid
  my $sunetid = $ENV{ uid };

  if ( not defined $sunetid ) {
    print q{<h4>You must log in with a Stanford account to use this site.</h4>};
    finish;
  }

  if ( $sunetid =~ m{[^a-z0-9]} ) {
    print q{<h4>Invalid SUnet ID. Please contact the course staff.</h4>};
    finish;
  }

  sub safer_retrieve ($$) {
    my ( $env_name, $upcase ) = @_;
    my $env_val = $ENV{ $env_name };
    if ( not defined $env_val ) {
      print qq{<h4>Could not retrieve property "${env_name}". Please contact the course staff.</h4>};
      finish;
    }

    if ( defined $upcase and $upcase ) {
      $env_val = ucfirst $env_val;
    }

    return HTML::Entities::encode( $env_val );
  }

  # get display info
  my $display_name = safer_retrieve( q{displayName}, 0 );
  my $first_name = safer_retrieve( q{givenName}, 1 );

  my $isinclass = $dbh->prepare( 'SELECT class FROM users WHERE sunetid = ?' ) or die qq{$DBI::errstr};

  $isinclass->execute( $sunetid ) or die qq{$DBI::errstr};

  my $class = undef;
  while ( my $data = $isinclass->fetchrow_hashref ) {
    $class = $data->{ class };
  }

  my $hit = $dbh->prepare( q{INSERT INTO hits ( sunetid, what, name, givenname ) VALUES ( ?, ?, ?, ? )} ) or die qq{$DBI::errstr};

  $hit->execute( $sunetid, $ENV{'REQUEST_URI'}, $display_name, $first_name ) or die qq{$DBI::errstr};

  if ( not defined $class ) {
    print qq{<h4>Unfortunately, we do not have a record that $display_name is registered for CS181 or CS181W. Please contact the course staff if you believe this is in error.</h4>};
    finish;
  }

  return ( $sunetid, $display_name, $first_name, $class );
}

1;
