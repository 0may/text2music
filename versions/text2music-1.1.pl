#!/usr/bin/perl -w

#****************************************************************************
# Software License Agreement (BSD License)
#
# Copyright (c) 2017 Oliver Mayer, Akademie der Bildenden Kuenste Nuernberg. 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# - Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#*****************************************************************************

use strict;
use POSIX qw(locale_h);
use locale;
use utf8;
#setlocale(LC_ALL, "UTF-8");


my $version = "1.1";

# ---- check arguments ----
my $num_args = $#ARGV + 1;
if ($num_args != 3) {
    print "text2music Perl script to convert text to music in MusicXML format according to given rules.\n";
    print "Version:\t$version\n";
    print "Usage:\t\tperl text2music.pl regeldatei.txt(Eingabe) textdatei.txt(Eingabe) musicxmldatei.xml(Ausgabe)\n";
    exit;
}

my $rulesfile = shift;
my $textfile = shift;
my $outfile = shift;

my $BLOCKSIZE = 2;
my $BEATS = 4;
my $BEATTYPE = 4;

my $octavemin = -1;
my $octavemax = 7;


# ---- parse rules ----

my %rulesPitch;
my %rulesPitchSequence;
my %rulesDurations;

parseRules($rulesfile);

my $debug = 1;

print "octavemin = $octavemin\n";
print "octavemax = $octavemax\n";

if ($debug == 1) {
	print "---- RULES ----\n";
	foreach my $char (sort(keys %rulesDurations)) {
		my @d = @{ $rulesDurations{$char}};
		my $p = $rulesPitch{$char};
		print "key: $char | pitch: $p | durations: @d\n";
	}
}

# ---- parse text ----

my @symbols = parseText($textfile);

if ($debug == 1) {
	print "\n---- SYMBOLS ----\n";

	foreach my $symbol (@symbols) {

		print "$symbol ";
	}
	print "\n";
}

# ---- generate MusicXML and write to file ----

if ($debug == 1) {
	print "\n---- MUSIC ----\n";
}

musicXML($outfile);






# ------ subroutines -------

sub musicXML{


	my $octave = 4;

	my $pitch = $octave*7;
	
	my $lastcomma = -1;

	my @args = @_;
	
	my $xml = "";
	
	my $repeat = 0;
	my $measureCnt = 0;
	my $beatSum = 0.0;
	
	
	open(MXML, ">$args[0]") or die "Couldn't open file $args[0], $!";

	$xml .= "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n";
	$xml .= "<!DOCTYPE score-partwise PUBLIC \"-//Recordare//DTD MusicXML 3.0 Partwise//EN\" \"http://www.musicxml.org/dtds/partwise.dtd\">\n";
	$xml .= "<score-partwise version=\"3.0\">\n";
	$xml .= "  <part-list>\n";
	$xml .= "    <score-part id=\"P1\">\n";
	$xml .= "      <part-name>Music</part-name>\n";
	$xml .= "    </score-part>\n";
	$xml .= "  </part-list>\n";
	$xml .= "  <part id=\"P1\">\n";
	

	$measureCnt++;
	$xml .= beginMeasure($measureCnt);
	
	print MXML "$xml";
	$xml = "";
	
	
	for (my $i = 1; $i <= $#symbols; $i++) {
	
		if ($symbols[$i] =~ /([a-zA-ZäÄüÜöÖß\x{e4}\x{f6}\x{fc}\x{df}])([a-zA-ZäÄüÜöÖß\x{e4}\x{f6}\x{fc}\x{df}])/) {
			
			$pitch += $rulesPitch{$2};
		
			my @durarray = @{ $rulesDurations{$1} };
			
			if ($debug == 1) {
				print "$symbols[$i]> durations [orig] [adjusted]: [@durarray] ";
			}
			
			my @ties;
			(my $durref, my $tiesref) = adjustDurations($beatSum, @durarray);
				
			@durarray = @{ $durref };
			@ties = @{ $tiesref };
				
			if ($debug == 1) {
				print "[@durarray],\tpitch change: $rulesPitch{$2}\n";
			}
			
			for (my $j = 0; $j <= $#durarray; $j++) {
			
				$xml .= "      <note>\n";	

				if ($durarray[$j] > 0.0) {					
					$xml .= pitch2xml($pitch);
				}
				else {
					$xml .= "        <rest/>\n";
				}

				$xml .= duration2xml($durarray[$j]);
				
				if ($ties[$j] == 1) {
					$xml .= "        <tie type=\"start\"/>\n";
					$xml .= "        <notations>\n";
					$xml .= "          <tied type=\"start\"/>\n";
					$xml .= "        </notations>\n";
				}
				elsif ($ties[$j] == 2) {
					$xml .= "        <tie type=\"stop\"/>\n";
					$xml .= "        <tie type=\"start\"/>\n";
					$xml .= "        <notations>\n";
					$xml .= "          <tied type=\"stop\"/>\n";
					$xml .= "          <tied type=\"start\"/>\n";
					$xml .= "        </notations>\n";
				}
				elsif ($ties[$j] == 3) {
					$xml .= "        <tie type=\"stop\"/>\n";
					$xml .= "        <notations>\n";
					$xml .= "          <tied type=\"stop\"/>\n";
					$xml .= "        </notations>\n";
				}
				
				$xml .= "      </note>\n";
			
				$beatSum += abs($durarray[$j]);
			
				if ($beatSum - int($beatSum/$BEATS)*$BEATS == 0.0) {
					
					$xml .= "    </measure>\n";
					
					$measureCnt++;
					$xml .= beginMeasure($measureCnt);
				}
			}
		}
		elsif ($symbols[$i] =~ /,/) {
			
			if ($repeat == 0) {
				
				print MXML "$xml";
				$xml = "";	
				
				$repeat = 1; 
			}
			else {
				
				print MXML "      <barline location=\"left\">\n";
				print MXML "        <bar-style>heavy-light</bar-style>\n";
				print MXML "        <repeat direction=\"forward\" winged=\"none\"/>\n";
				print MXML "      </barline>\n";
				
				print MXML "$xml";
				
				print MXML "      <barline location=\"right\">\n";
				print MXML "        <bar-style>light-heavy</bar-style>\n";
				print MXML "        <repeat direction=\"backward\" winged=\"none\"/>\n";
				print MXML "      </barline>\n";			
				
				$xml = "";
			}
		}
		elsif ($symbols[$i] =~ /\.[a-zA-ZäÄüÜöÖß\x{e4}\x{f6}\x{fc}\x{df}]]/) {
		
			if ($repeat == 1) {
			
				print MXML "$xml";
				$xml = "";
				
				$repeat = 0;
			}
		}
	}
	
	
	
	
	$xml .= "    </measure>\n";
	$xml .= "  </part>\n";
	$xml .= "</score-partwise>\n";
	
	
	print MXML "$xml";
	
	close(MXML);
}

sub adjustDurations {

	my @args = @_;
	
	my @adjustedDurs;
	my @ties;
	
	my $dur;
	my $sign;
	
	my @validDurs;
	
	my $rem = $args[0] - int($args[0] / $BEATS)*$BEATS;
	
	
	for (my $i = 1; $i <= $#args; $i++) {
	
		my $dur = $args[$i];
		if ($dur <= 0.0) {
			$sign = -1.0;
		}
		else {
			$sign = 1.0;
		}
		
		$dur = abs($dur);
	
		if ($rem + $dur <= $BEATS) {
			$rem += $dur;
			
			if ($rem == 4.0) {
				$rem = 0.0;
			}
			
			push(@adjustedDurs, $sign*$dur);
			push(@ties, 0);
		}
		else {
			
			my $d = $BEATS - $rem;
			my $dd = nearestValidDuration($d);
			
			if ($d == $dd) {
				push(@adjustedDurs, $sign*$d);
				if ($sign == 1.0) {
					push(@ties, 1);
				}
				else {
					push(@ties, 0);
				}
			}
			else {
				push(@adjustedDurs, $sign*$dd);
				push(@adjustedDurs, $sign*($d - $dd));
				
				if ($sign == 1.0) {
					push(@ties, 1);
					push(@ties, 2);
				}
				else {
					push(@ties, 0);
					push(@ties, 0);
				}
			}
			
			$d = $dur - $BEATS + $rem;
			$dd = nearestValidDuration($d);
			
			if ($d == $dd) {
				push(@adjustedDurs, $sign*$d);
				if ($sign == 1.0) {
					push(@ties, 3);
				}
				else {
					push(@ties, 0);
				}
			}
			else {
				push(@adjustedDurs, $sign*$dd);
				push(@adjustedDurs, $sign*($d - $dd));
				
				if ($sign == 1.0) {
					push(@ties, 2);
					push(@ties, 3);
				}
				else {
					push(@ties, 0);
					push(@ties, 0);
				}
			}
			
			$rem = $d;
		}
	}
	
	return (\@adjustedDurs, \@ties);
}

sub nearestValidDuration {
	my $dur = $_[0];
	
	if ($dur >= 4.0) {
		return 4.0;
	}
	elsif ($dur >= 3.0) {
		return 3.0;
	}
	elsif ($dur >= 2.0) {
		return 2.0;
	}
	elsif ($dur >= 1.5) {
		return 1.5;
	}
	elsif ($dur >= 1.0) {
		return 1.0;
	}
	elsif ($dur >= 0.75) {
		return 0.75;
	}
	elsif ($dur >= 0.5) {
		return 0.5;
	}
	elsif ($dur >= 0.25) {
		return 0.25;
	}
	else {
		die "Tiny durations not supported: $dur\n";
	}
}



sub beginMeasure {
	my $measure = "";
	$measure .= "    <measure number=\"$_[0]\">\n";
	$measure .= "      <attributes>\n";
	if ($_[0] == 1) {
		$measure .= "        <divisions>1</divisions>\n";
		$measure .= "        <key>\n";
		$measure .= "          <fifths>0</fifths>\n";
		$measure .= "        </key>\n";
		$measure .= "        <time>\n";
		$measure .= "          <beats>$BEATS</beats>\n";
		$measure .= "          <beat-type>$BEATTYPE</beat-type>\n";
		$measure .= "        </time>\n";
		$measure .= "        <clef>\n";
		$measure .= "          <sign>G</sign>\n";
		$measure .= "          <line>2</line>\n";
		$measure .= "        </clef>\n";
	}
	$measure .= "      </attributes>\n";
	return $measure;
}



sub pitch2xml{

	my $pitch = $_[0];
	
	my $step = $pitch % 7;

	my $octave = int($pitch/7);

	my $xml = "";
	$xml .= "        <pitch>\n";
	$xml .= "          <step>".stepNum2String($step)."</step>\n";
	$xml .= "          <octave>$octave</octave>\n";
	$xml .= "        </pitch>\n";
	
	return $xml;
}


sub stepNum2String{

	my $step = $_[0];
	
	if ($step == 0) {
		return "C";
	}
	elsif ($step == 1) {
		return "D";
	}
	elsif ($step == 2) {
		return "E";
	}
	elsif ($step == 3) {
		return "F";
	}
	elsif ($step == 4) {
		return "G";
	}
	elsif ($step == 5) {
		return "A";
	}
	elsif ($step == 6) {
		return "B";
	}
	else {
		die "Unknown step number: $step";
	}
}

sub duration2xml{ 

	my $dur = abs($_[0]);
	my $dot = 0;
	if ($dur == 3 || $dur == 1.5 || $dur == 0.75) {
		$dot = 1;
	}
				
	my $xml = "";
	$xml .= "        <duration>$dur</duration>\n";
	$xml .= "        <type>".durationNum2String($dur)."</type>\n";	
	if ($dot == 1) {
		$xml .= "        <dot/>\n";	
	}

	return $xml;
}

sub durationNum2String{
	my $dur = $_[0];
	
	$dur = abs($dur);
	
	if ($dur == 4) {
		return "whole";
	}
	elsif ($dur == 2 || $dur == 3) {
		return "half";
	}
	elsif ($dur == 1 || $dur == 1.5) {
		return "quarter";
	}
	elsif ($dur == 0.5 || $dur == 0.75) {
		return "eighth";
	}
	elsif ($dur == 0.25) {
		return "16th";
	}
	else {
		die "Unknown duration: $dur";
	}
}


sub parseText{

	my $block = "";
	my @blocklist;
	my $cnt = -1;
	
	my @args = @_;
	
	#open(TEXT,"<$args[0]") or die "Couldn't open file $args[0], $!";
	open(TEXT, '<:encoding(UTF-8)', $args[0]) or die "Couldn't open file $args[0], $!";
	
	while(<TEXT>) {
		my $line = $_;
		chomp($line);
		$line = lc($line);
		$line =~ s/\s+//g;
		my @linesplit = split(//, $line);
		
		for (my $i = 0; $i < $#linesplit + 1; $i++) {
			
			if ($linesplit[$i] =~ /[a-zA-ZäÄüÜöÖß\x{e4}\x{f6}\x{fc}\x{df}]/) {
				if ($cnt < 0) {
					push(@blocklist, $linesplit[$i]);
					$cnt = 0;
				}
				elsif ($cnt < $BLOCKSIZE) {
					$block .= $linesplit[$i];
					$cnt++;
					
					if ($cnt == $BLOCKSIZE) {
						push(@blocklist, $block);
						$block = "";
						$cnt = 0;
					}
				}
			}	
			elsif ($linesplit[$i] =~ /\./) {
				$block = ".";
				$cnt = 1;
			}
			elsif ($linesplit[$i] =~ /,/) {
				push(@blocklist, ",");
				$cnt = 0;
			}
		}
	}
	
	
	return @blocklist;
}


sub parseRules{
	
	
	my $char;
	my $durations;
	my $duration;
	my $pitchsequence;
	
	my @args = @_;
	
	#open(RULES, "<$args[0]") or die "Couldn't open file $args[0], $!";
	open(RULES, '<:encoding(UTF-8)', $args[0]) or die "Couldn't open file $args[0], $!";


	while (<RULES>) {
		my $line = $_;
		chomp($line);
		#$line = lc($line);
		#utf8::decode($line);
		#print "$line\n";
		
		if ( $line =~ /([a-zA-ZäÄüÜöÖß\x{e4}\x{f6}\x{fc}\x{df}])\s*:\s*\[\s*([+-]{0,1}\s*(\d(,\d+)*)(\s*;\s*[+-]{0,1}\s*\d(,\d+)*)*)\s*\/\s*([+-]{0,1}\s*\d+(\s*;\s*[+-]{0,1}\s*\d+)*)\s*\].*/) {
			$char = $1;
			$durations = $2;
			$pitchsequence = $7;
			
			print "$char : $durations : $pitchsequence\n";
			
			if ( $line =~ /.*\[\s*([+-]{0,1}\s*\d+)\s*\]\s*$/ ) {
			
			
				$rulesPitch{ $char } = $1 + 0;
				
				
				chomp($durations);
				$durations =~ s/,/./g;

				my @dursplit = split(/;/, $durations);
				
				
				for (my $i = 0; $i < $#dursplit+1; $i++) {
					chomp($dursplit[$i]);
					$rulesDurations{ $char }[$i] = $dursplit[$i] + 0.0;
				}
				
				chomp($pitchsequence);
				#$pitchsequence =~ s/,/./g;

				my @pitchseqsplit = split(/;/, $pitchsequence);
				
				if ($#dursplit+1 != $#pitchseqsplit+1) {
					die "ERROR: Invalid rule for '$char': Number pitch changes (". ($#pitchseqsplit+1) .") must match number of note durations (". ($#dursplit+1) .") !\n" ;
				}
				
				for (my $i = 0; $i < $#pitchseqsplit+1; $i++) {
					chomp($pitchseqsplit[$i]);
					$rulesPitchSequence{ $char }[$i] = $pitchseqsplit[$i] + 0.0;
				}
				
			}
			
		}
		elsif ($line =~ /\s*octavemin\s*:\s*([+-]{0,1}\s*\d+)\s*/) {
			my $str = $1;
			chomp($str);
			$str =~ s/\s//g;
			
			
			$octavemin = $str + 0;
		}
		elsif ($line =~ /\s*octavemax\s*:\s*([+-]{0,1}\s*\d+)\s*/) {
			my $str = $1;
			chomp($str);
			$str =~ s/\s//g;
			
			
			$octavemax = $str + 0;
		}
		
	}

	close(RULES);
	
}