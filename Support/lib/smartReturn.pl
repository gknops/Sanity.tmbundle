#!/usr/bin/perl -w
###############################################################################
#	Copyright 2012 BITart Gerd Knops,  All rights reserved.
#
#	Project	: Sanity.tmbundle
#	File	: smartReturn
#	Author	: Gerd Knops gerti@BITart.com
#
###############################################################################
#
#	History:
#	120829 Creation of file
#
###############################################################################
#
#	Description:
#	Smart Return support for TextMate2
#
###############################################################################
#
# DISCLAIMER
#
# BITart and Gerd Knops make no warranties, representations or commitments
# with regard to the contents of this software. BITart and Gerd Knops
# specifically disclaim any and all warranties, whether express, implied or
# statutory, including, but not limited to, any warranty of merchantability
# or fitness for a particular purpose, and non-infringement. Under no
# circumstances will BITart or Gerd Knops be liable for loss of data,
# special, incidental or consequential damages out of the use of this
# software, even if those damages were foreseeable, or BITart or Gerd Knops
# was informed of their potential.
#
###############################################################################
# Configuration
###############################################################################
	
	use strict;
	
	our $DEBUG=0;
	our $pairs;
	our $stringPairs;
	
###############################################################################
# Main
###############################################################################
sub ::dprint {
	
	if($DEBUG)
	{
		my $str=join(' ',@_);
		
		$str=~s/\0/\\0/g;
		
		print $str;
	}
}
sub process {
	
	my $pairs=shift;
	my $stringPairs=shift;
	my $extendSingleLineComments=shift;
	
	$DEBUG=shift // 0;
	
	dprint "\$ENV{TM_SELECTION}: '$ENV{TM_SELECTION}'\n";
	
	# Preprocess comment definitions, examples:
	# 	TM_COMMENT_START=// 
	# 	TM_COMMENT_START_2=/*
	# 	TM_COMMENT_END_2=*/
	my $startTemplate='TM_COMMENT_START_';
	my $endTemplate='TM_COMMENT_END_';
	my $start='TM_COMMENT_START';
	my $end='TM_COMMENT_END';
	my @commentPairs=();
	my @lineComments=();
	my $idx=1;
	
	while(exists($ENV{$start}))
	{
		my $cStart=$ENV{$start};
		
		$cStart=~s/^\s+//;
		$cStart=~s/\s+$//;
		
		if(exists($ENV{$end}))
		{
			my $cEnd=$ENV{$end};
			$end=~s/^\s+//;
			$end=~s/\s+$//;
			
			my @a=(quotemeta($cStart),quotemeta($cEnd));
			push(@commentPairs,\@a);
		}
		else
		{
			push(@lineComments,$cStart);
		}
		
		$idx++;
		$start="$startTemplate$idx";
		$end="$endTemplate$idx";
	}
	
	# We need beginning of the selected line up to the cursor
	$ENV{TM_SELECTION}=~/(\d+):(\d+)/;
	my $lineNo=$1;
	my $cursorPos=$2;
	my $lineNoEnd=$lineNo;
	my $cursorPosEnd=$cursorPos;
	
	if($ENV{TM_SELECTION}=~/\-(\d+):(\d+)/)
	{
		$lineNoEnd=$1;
		$cursorPosEnd=$2;
	}
	
	my $preSel=undef;
	my $postSel=undef;
	my $nextLine=undef;
	$idx=1;
	while(<>)
	{
		if(defined($postSel))
		{
			$nextLine=$_;
			last;
		}
		if($idx==$lineNo)
		{
			$preSel=substr($_,0,$cursorPos-1);
		}
		if($idx==$lineNoEnd)
		{
			$postSel=substr($_,$cursorPosEnd-1);
			next;
		}
		$idx++;
	}
	
	dprint "preSel '$preSel'\n";
	dprint "postSel '$postSel'\n";
	
	my $line="$preSel\0\0$postSel";
	
	# Remove leading whitespace
	$line=~s/^(\s*)//;
	my $ws1=$1;
	
	# Does the next line have more whitespace?
	# If yes we do not add closing items, assuming
	# we are in an existing block.
	$nextLine=~/^(\s*)/;
	my $ws2=$1;
	my $addClosers=1;
	
	$addClosers=0 if($ws2 && length($ws2)>length($ws1));
	
	# Process single line comment extension
	if($extendSingleLineComments)
	{
		foreach my $lineComment (@lineComments)
		{
			if(index($line,$lineComment)==0)
			{
				print "\n$lineComment \$0";
				
				return;
			}
		}
	}
	
	# Remove escaped characters
	$line=~s/\\.//g;
	
	# Remove strings
	foreach my $pair (@$stringPairs)
	{
		$line=eliminateMatching($line,$pair,1);
	}
	
	dprint "after removing strings: '$line'\n";
	
	# Remove comments
	foreach my $lineComment (@lineComments)
	{
		my $idx=index($line,$lineComment);
		
		$line=substr($line,0,$idx) if($idx>=0);
	}
	
	foreach my $pair (@commentPairs)
	{
		$line=eliminateMatching($line,$pair,1);
	}
	
	dprint "after removing comments: '$line'\n";
	
	# Split pre and post selection up again
	$line=~/^([^\0]*)\0+(.*)$/;
	$preSel=$1 // '';
	$postSel=$2 // '';
	
	# Eliminate matching pairs on each side
	foreach my $pair (@$pairs)
	{
		$preSel=eliminateMatching($preSel,$pair);
	}
	foreach my $pair (@$pairs)
	{
		$postSel=eliminateMatching($postSel,$pair);
	}
	
	dprint "after eliminateMatching (individual): '$preSel' '$postSel'\n";
	
	# Now eliminate matching across pre and post
	$line="$preSel\0\0$postSel";
	foreach my $pair (@$pairs)
	{
		$line=eliminateMatching($line,$pair);
	}
	
	dprint "after eliminateMatching (joint): '$line'\n";
	
	# Remove post selection
	$line=~s/\0+.*$//;
	
	my $insideMatch=($line eq $preSel)?0:1;
	
	dprint "line: '$line'\n";
	dprint "preSel: '$preSel'\n";
	dprint "insideMatch: $insideMatch\n";
	
	# Eliminate leading right-side items
	foreach my $pair (@$pairs)
	{
		$line=eliminateLeadingRights($line,$pair);
	}
	dprint "after eliminateLeadingRights:'$line'\n";
	
	# Now find all left matches, and return matching rights in reverse order
	# We also add the comment pairs here!
	my @cPairs=@$pairs;
	push(@cPairs,@commentPairs);
	my @closers=inverseLeftMatches($line,\@cPairs);
	
	my $closers=join('',@closers);
	
	dprint "closers: '$closers'\n";
	
	if($insideMatch || $closers ne '')
	{
		if($addClosers)
		{
			print "\n\t\$0\n$closers";
		}
		else
		{
			print "\n\t\$0";
		}
	}
	else
	{
		print "\n";
	}
}
sub reIndex {
	
	my $str=shift;
	my $substr=shift;
	my $pos=shift // 0;
	
	if(length($substr)==1)
	{
		my $idx=index($str,$substr,$pos);
		
		return ($idx,1);
	}
	
	if($pos>0)
	{
		$substr="^.{$pos,}?($substr)";
	}
	else
	{
		$substr="($substr)";
	}
	
	dprint "Check for '$substr' in '$str'\n";
	
	if($str=~m/$substr/)
	{
		# print "'$substr' matched '$str' at $-[1] to $+[1]  2:'$2' 3:'$3'\n";
		return ($-[1],$+[1]-$-[1],$2,$3,$4,$5,$6);
	}
	dprint "Not found!\n";
	
	return (-1,0);
}
sub eliminateMatching {
	
	my $line=shift;
	my $pair=shift;
	my $deleteInside=shift // 0;
	
	my $left=$pair->[0];
	my $right=$pair->[1];
	
	dprint "l: $left  r: $right\n";
	
	my $indexLeft;
	
	my $linePos=0;
	
	while($linePos<length($line))
	{
		my($indexLeft,$lenLeft,$m1,$m2,$m3,$m4,$m5)=reIndex($line,$left,$linePos);
		
		last if($indexLeft<0);
		dprint "'$left' matched '$line' at $indexLeft  len $lenLeft ($m1)\n";
		
		my $lRight=$right;
		$lRight=~s/\$1/$m1/g;
		$lRight=quotemeta($lRight);
		
		my $pos=$indexLeft+$lenLeft;
		my($indexRight,$lenRight)=reIndex($line,$lRight,$pos);
		
		dprint "il: $indexLeft  ir: $indexRight  '$lRight'\n";
		
		if($indexRight<0)
		{
			$linePos++;
			next;
		}
		
		if($deleteInside)
		{
			my($idx,$len)=reIndex($line,"\0",$indexLeft);
			my $replacement='';
			$replacement="\0\0" if($idx>0 && $idx<$indexRight);
			
			substr($line,$indexLeft,$indexRight+$lenRight-$indexLeft)=$replacement;
		}
		else
		{
			substr($line,$indexRight,$lenRight)='';
			substr($line,$indexLeft,$lenLeft)='';
		}
	}
	
	$line;
}
sub eliminateLeadingRights {
	
	my $line=shift;
	my $pair=shift;
	
	my $left=$pair->[0];
	my $right=$pair->[1];
	
	while(1)
	{
		my($indexRight,$lenRight)=reIndex($line,$right);
		
		last if($indexRight<0);
		
		my($indexLeft,$lenLeft)=reIndex($line,$left);
		
		if($indexLeft<0 || $indexLeft>$indexRight)
		{
			substr($line,$indexRight,$lenRight)='';
		}
	}
	
	$line;
}
sub inverseLeftMatches {
	
	my $line=shift;
	my $pairs=shift;
	
	my @matches=();
	my $ll=length($line);
	my $i=0;
	
	while($i<$ll)
	{
		my $iBegin=$i;
		
		foreach my $pair (@$pairs)
		{
			dprint "Checking '$pair->[0]' at $i in '$line'\n";
			
			my($idxLeft,$lenLeft,$m1,$m2,$m3,$m4,$m5)=reIndex($line,$pair->[0],$i);
			
			if($idxLeft==$i)
			{
				my $lRight=$pair->[2] // $pair->[1];
				$lRight=~s/\$1/$m1/g;
				
				dprint "Adding closer: '$lRight'\n";
				unshift(@matches,$lRight);
				$i+=$lenLeft;
				last;
			}
		}
		
		$i++ if($i==$iBegin);
	}
	
	@matches;
}

1;
############################################################################EOF
