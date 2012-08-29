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
	$DEBUG=shift // 0;
	
	dprint "\$ENV{TM_SELECTION}: '$ENV{TM_SELECTION}'\n";
	
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
	my $idx=1;
	while(<>)
	{
		if($idx==$lineNo)
		{
			$preSel=substr($_,0,$cursorPos-1);
		}
		if($idx==$lineNoEnd)
		{
			$postSel=substr($_,$cursorPosEnd-1);
			last;
		}
		$idx++;
	}
	
	dprint "preSel '$preSel'\n";
	dprint "postSel '$postSel'\n";
	
	my $line="$preSel\0\0$postSel";
	
	# Remove leading whitespace
	$line=~s/^\s*//;
	
	# Remove escaped characters
	$line=~s/\\.//g;
	
	# Remove strings
	foreach my $pair (@$stringPairs)
	{
		$line=eliminateMatching($line,$pair,1);
	}
	
	dprint "after removing strings: '$line'\n";
	
	# Remove comments
	# TM_COMMENT_START=// 
	# TM_COMMENT_START_2=/*
	# TM_COMMENT_END_2=*/
	my $startTemplate='TM_COMMENT_START_';
	my $endTemplate='TM_COMMENT_END_';
	my $start='TM_COMMENT_START';
	my $end='TM_COMMENT_END';
	my @commentPairs=();
	my @lineComments=();
	$idx=1;
	
	while(exists($ENV{$start}))
	{
		if(exists($ENV{$end}))
		{
			my @a=($ENV{$start},$ENV{$end});
			push(@commentPairs,\@a);
		}
		else
		{
			push(@lineComments,$ENV{$start});
		}
		
		$idx++;
		$start="$startTemplate$idx";
		$end="$endTemplate$idx";
	}
	
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
		print "\n\t\$0\n$closers";
	}
	else
	{
		print "\n";
	}
}
sub eliminateMatching {
	
	my $line=shift;
	my $pair=shift;
	my $deleteInside=shift // 0;
	
	my $left=$pair->[0];
	my $right=$pair->[1];
	
	dprint "l: $left  r: $right\n";
	
	my $indexLeft;
	
	while(($indexLeft=index($line,$left))>=0)
	{
		my $pos=$indexLeft+length($left);
		my $indexRight=index($line,$right,$pos);
		
		dprint "il: $indexLeft  ir: $indexRight\n";
		
		last if($indexRight<0);
		
		if($deleteInside)
		{
			my $idx=index($line,"\0",$indexLeft);
			my $replacement='';
			$replacement="\0\0" if($idx>0 && $idx<$indexRight);
			
			substr($line,$indexLeft,$indexRight+length($right)-$indexLeft)=$replacement;
		}
		else
		{
			substr($line,$indexRight,length($right))='';
			substr($line,$indexLeft,length($left))='';
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
		my $indexRight=index($line,$right);
		
		last if($indexRight<0);
		
		my $indexLeft=index($line,$left);
		
		if($indexLeft<0 || $indexLeft>$indexRight)
		{
			substr($line,$indexRight,length($right))='';
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
			if(index($line,$pair->[0],$i)==$i)
			{
				dprint "Adding closer: '$pair->[1]'\n";
				unshift(@matches,$pair->[1]);
				$i+=length($pair->[0]);
				last;
			}
		}
		
		$i++ if($i==$iBegin);
	}
	
	@matches;
}

1;
############################################################################EOF
