package EPrints::Plugin::Export::SingleLineCSV;

use EPrints::Plugin::Export;
@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
    my( $class, %opts ) = @_;
    my $self = $class->SUPER::new( %opts );
    $self->{name}     = "Single Line CSV Export";
    $self->{accept}   = [ 'dataobj/eprint', 'list/eprint' ];
    $self->{visible}  = "all";
    $self->{suffix}   = ".csv";
    $self->{mimetype} = "text/csv; charset=utf-8";
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

    # Fixed column order (some are compound projections of 'creators')
    my @fields = qw(
        eprintid
		type
		divisions
		auposition
		authorcat
        title
		book_title
		creators
        creators_name
        creators_id
        creators_orcid
		editors
		editors_id
		editors_name	
		editors_orcid
		jgucreators
		jgucreators_id
		jgucreators_name
        affiliation
		contributors
		contributors_id
		contributors_name
		contributors_type
		corp_creators
        date
		edition
        publication
		indexdbase
		institution
		monograph_type
        volume
        number
		pages
		collabcountry
		collabtype
        issn
		isbn
        keywords
        abstract
        official_url
        subjects
        ispublished
        publisher
        full_text_status
		event_title
		event_type
		event_location
		event_dates
		
    );

    my $fh = $opts{fh};
    my @out;
    my $emit = $fh ? sub { print {$fh} $_[0] } : sub { push @out, $_[0] };

    # Header
    my @headers = map { my $h = $_; $h =~ s/"/""/g; qq{"$h"} } @fields;
    $emit->( join(",", @headers) . "\r\n" );

    # Rows
    $opts{list}->map( sub {
        my (undef, undef, $eprint) = @_;
        my @vals;
        for my $fname (@fields)
        {
            my $val = _extract_value($eprint, $fname);
            $val = "" unless defined $val;
            $val =~ s/\r?\n/ /g;
            $val =~ s/\t/ /g;
            $val =~ s/"/""/g;
            push @vals, qq{"$val"};
        }
        $emit->( join(",", @vals) . "\r\n" );
    });

    return join('', @out);
}

# Single record export delegates to list path
sub output_dataobj
{
    my( $plugin, $dataobj ) = @_;
    require EPrints::List;
    my $list = EPrints::List->new(
        dataset => $dataobj->{dataset},
        session => $plugin->{session},
        ids     => [ $dataobj->get_id ],
    );
    return $plugin->output_list( list => $list );
}

######################################################################
# Helpers
######################################################################

# Return a string for a requested "field name". Handles compound projections.
sub _extract_value
{
    my ($eprint, $fname) = @_;

    # Helper: normalise an ORCID into "orcid.org/XXXX-XXXX-XXXX-XXXX"
    my $normalise_orcid = sub {
        my ($raw) = @_;
        return "" unless defined $raw && $raw ne "";
        my $v = $raw;
        $v =~ s/^\s+|\s+$//g;
        $v =~ s{^https?://orcid\.org/}{}i;
        $v =~ s{^orcid\.org/}{}i;
        # Keep digits and possible X check digit, then (re)hyphenate
        my $canon = $v; $canon =~ s/[^0-9Xx]//g;
        if (length($canon) == 16) {
            $v = substr($canon,0,4) . "-" . substr($canon,4,4) . "-" . substr($canon,8,4) . "-" . substr($canon,12,4);
        } else {
            # Fallback to original if length unexpected
            $v = $raw;
            $v =~ s{^https?://}{}i;
        }
        return "orcid.org/$v" if $v !~ m{^orcid\.org/}i;
        return $v;
    };

    # Helper: render "Family, Given" from a people row
    my $format_name = sub {
        my ($row) = @_;
        my $name = $row->{name};
        return "" unless ref($name) eq 'HASH';
        my $given  = $name->{given_names}  // $name->{given}  // "";
        my $family = $name->{family_names} // $name->{family} // "";
        return $family && $given ? "$family, $given" : ($family || $given || "");
    };

    ##################################################################
    # Generic handler for people-like compound list fields:
    # creators, editors, jgucreators, contributors (+ projections)
    ##################################################################
    if ( $fname =~ m/^(creators|editors|jgucreators|contributors)(?:_(name|id|orcid|type))?$/ )
    {
        my ($base, $proj) = ($1, $2);  # $proj is undef for the single formatted field
        my $list = $eprint->value($base) || [];
        return "" unless ref($list) eq 'ARRAY';

        my @parts;
        for my $row (@$list)
        {
            next unless ref($row) eq 'HASH';

            my $name = $format_name->($row);
            my $id   = defined $row->{id}    ? do { my $x = $row->{id};   $x =~ s/^\s+|\s+$//g; $x } : "";
            my $orc  = $normalise_orcid->($row->{orcid});
            my $type = defined $row->{type}  ? $row->{type} : "";

            if ( defined $proj )
            {
                my $token = "";
                if    ( $proj eq 'name'  ) { $token = $name }
                elsif ( $proj eq 'id'    ) { $token = $id }
                elsif ( $proj eq 'orcid' ) { $token = $orc }
                elsif ( $proj eq 'type'  ) { $token = $type }
                push @parts, (defined $token ? $token : "");
            }
            else
            {
                # Single formatted field like: Family, Given (email orcid.org/....)
                my @extras;
                push @extras, $id  if length $id;
                push @extras, $orc if length $orc;

                my $token = $name;
                if (@extras) {
                    $token = length($name)
                        ? "$name (" . join(" ", @extras) . ")"
                        : "(" . join(" ", @extras) . ")";
                }
                push @parts, $token;
            }
        }

        # IMPORTANT: keep blanks to preserve ordering across projections
        return join("; ", @parts);
    }

    # Subjects: render labels (not raw IDs)
    if ( $fname eq 'subjects' )
    {
        my $dom = $eprint->render_value('subjects');
        return EPrints::Utils::tree_to_utf8($dom);
    }

    # Keywords: array -> semicolon list
    if ( $fname eq 'keywords' )
    {
        my $val = $eprint->value('keywords');
        return "" unless defined $val;
        if (ref($val) eq 'ARRAY') { return join("; ", grep { defined && $_ ne "" } @$val) }
        return "$val";
    }

    # Most other fields—just pull the value and normalise
    if ( $eprint->exists_and_set($fname) )
    {
        my $v = $eprint->value($fname);

        # Arrays (of scalars) -> semicolon list
        if (ref($v) eq 'ARRAY') {
            # If it's an array of HASH (e.g. missed compound), render via render_value to be safe
            if (@$v && ref($v->[0]) eq 'HASH') {
                my $rendered = EPrints::Utils::tree_to_utf8( $eprint->render_value($fname) );
                return $rendered if defined $rendered && $rendered ne "";
                # Fallback: flatten keys for each hash
                return join("; ", map {
                    my $h = $_;
                    join(", ", map { "$_=$h->{$_}" } sort keys %$h)
                } @$v);
            }
            return join("; ", grep { defined && $_ ne "" } @$v);
        }

        # Hashes—try render_value for a friendly string; else flatten
        if (ref($v) eq 'HASH')
        {
            my $rendered = EPrints::Utils::tree_to_utf8( $eprint->render_value($fname) );
            return $rendered if defined $rendered && $rendered ne "";
            return join("; ", map { "$_=$v->{$_}" } sort keys %$v );
        }

        # Booleans or scalars
        return "$v";
    }

    return "";
}



1;

__END__

=head1 NAME

EPrints::Plugin::Export::SingleLineCSV

=head1 DESCRIPTION

Exports one CSV row per eprint. Flattens C<creators> to provide
C<creators_name>, C<creators_id>, and C<creators_orcid>. Also renders
subjects as human-readable labels and normalises arrays to
semicolon-separated lists.

=cut
