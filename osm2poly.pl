#!/usr/bin/perl

#
# Copyright (c) 2013 Dmitry Marakasov <amdmi3@amdmi3.ru>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright notice, this list
#       of conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

use warnings;
use strict;
use XML::Parser;
use Data::Dumper;

# Parser state
my $current_name;
my $current_id;
my $current_nds = [];
my $current_inners = [];
my $current_outers = [];

# Gathered elements
my $nodes = {};
my $ways = {};
my $rels = {};

my $ways_by_name = {};
my $rels_by_name = {};

# Parse the file
my $infile = $ARGV[0];
unless (defined $infile) {
	$infile = $0;
	$infile =~ s/\/.*?$/\/contours.osm/;
}

my $parser = XML::Parser->new(Handlers => { Start => \&start, End => \&end });
$parser->parsefile($infile);

# Handlers
sub start {
	my ($parser, $element, %attrs) = @_;

	if ($element eq 'node') {
		# node - we just save their lat/lon's into hash for later use
		die "bad node" unless defined $attrs{id} && defined $attrs{lat} && defined $attrs{lon};

		undef $current_name;
		$nodes->{$attrs{id}} = [ $attrs{lon}, $attrs{lat} ];
	} elsif ($element eq 'way') {
		# way - actually processed in end(); here we just reset parser state for it
		die "bad way" unless defined $attrs{id};

		undef $current_name;
		$current_nds = [];
		$current_id = $attrs{id};
	} elsif ($element eq 'relation') {
		# relation - actually processed in end(); here we just reset parser state for it
		die 'bad relation' unless defined $attrs{id};

		undef $current_name;
		$current_inners = [];
		$current_outers = [];
		$current_id = $attrs{id};
	} elsif ($element eq 'nd') {
		# way members - append to current parser state
		die 'bad nd' unless defined $attrs{ref};

		push @$current_nds, $attrs{ref}
	} elsif ($element eq 'member') {
		# relation members - append to current parser state
		die 'bad member' unless defined $attrs{type} && defined $attrs{ref} && defined $attrs{role};

		return if ($attrs{type} ne 'way');

		if ($attrs{role} eq 'inner') {
			push @$current_inners, $ways->{$attrs{ref}} || die "required way $attrs{ref} not found";
		} elsif ($attrs{role} eq 'outer') {
			push @$current_outers, $ways->{$attrs{ref}} || die "required way $attrs{ref} not found";
		} else {
			print STDERR "Warning: unknown role for relation member: $attrs{role}\n";
		}
	} elsif ($element eq 'tag') {
		# tags - add name to current parser state
		die 'bad tag' unless defined $attrs{k} && $attrs{v};

		$current_name = $attrs{v} if ($attrs{k} eq 'name')
	}
}

sub end {
	my ($parser, $element) = @_;

	if ($element eq 'way') {
		# way - we both save them into hash to be referenced by relations...
		$ways->{$current_id} = $current_nds;

		# and output named ones as a single contour
		output_poly($current_name, [ $current_nds ], []) if (defined $current_name);
	} elsif ($element eq 'relation' && defined $current_name) {
		# for relation, we collect complete inner/outer rings
		output_poly($current_name, create_rings($current_outers), create_rings($current_inners));
	}
}

sub create_rings {
	my $lines = $_[0]; # modifies input arref!
	my $output = [];

	# need to process all lines
	while ($#$lines >= 0) {
		my $current_line = [ @{splice @$lines, 0, 1} ];

		# until the contour is closed, find next part of it and append it
		while ($current_line->[0] != $current_line->[$#$current_line]) {
			my $foundsome = 0;
			for (my $i = 0; $i <= $#$lines; ++$i) {
				my $candidate_line = $lines->[$i];
				if ($current_line->[$#$current_line] == $candidate_line->[0]) {
					$foundsome = 1;
					pop @$current_line;
					push @$current_line, @$candidate_line;
				} elsif ($current_line->[$#$current_line] == $candidate_line->[$#$candidate_line]) {
					$foundsome = 1;
					pop @$current_line;
					push @$current_line, reverse @$candidate_line;
				} else {
					next;
				}
				splice @$lines, $i, 1;
			}
			# could not find next part, while the polygon is still not closed
			die 'incomplete multipolygon detected' unless $foundsome;
		}

		push @$output, $current_line;
	}

	return $output;
}

sub output_poly {
	my ($name, $outers, $inners) = @_;

	open(POLY, '>'. $name.'.poly');
	print POLY "$name\n";

	my $num = 1;
	foreach my $outer (@$outers) {
		print POLY "$num\n";
		foreach my $nd (@$outer) {
			my $node = $nodes->{$nd} || die "required node $nd not found";
			print POLY "\t$node->[0]\t$node->[1]\n";
		}
		print POLY "END\n";
		$num++;
	}
	foreach my $inner (@$inners) {
		print POLY "!$num\n";
		foreach my $nd (@$inner) {
			my $node = $nodes->{$nd} || die "required node $nd not found";
			print POLY "\t$node->[0]\t$node->[1]\n";
		}
		print POLY "END\n";
		$num++;
	}

	print POLY "END\n";
	close(POLY);
}
