package EPrints::Plugin::Export::Report::SingleLineCSV;

use EPrints::Plugin::Export::Report;
@ISA = ( "EPrints::Plugin::Export::Report" );

use strict;

sub new
{
    my( $class, %params ) = @_;

    my $self = $class->SUPER::new( %params );

    $self->{name}      = "Single Line CSV";
    $self->{suffix}    = ".csv";
    $self->{mimetype}  = "text/csv; charset=utf-8";
    $self->{accept}    = [ 'report/generic' ];   # <-- makes it appear in Reports
    $self->{advertise} = 1;
    $self->{visible}   = "staff";                # or "all" if you like

    return $self;
}

sub initialise_fh
{
    my( $self, $fh ) = @_;
    binmode( $fh, ":utf8" );
}

sub output_list
{
    my( $plugin, %opts ) = @_;

    # Delegate to your working exporter
    require EPrints::Plugin::Export::SingleLineCSV;
    my $delegate = EPrints::Plugin::Export::SingleLineCSV->new(
        session => $plugin->repository
    );

    return $delegate->output_list( %opts );
}

1;
