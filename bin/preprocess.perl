#!/usr/bin/env perl


# Monolithic AFRLMT preprocessing script as an attempt to
# speed things up for QCR (phase 1)

use utf8;
use strict;

# no buffering
$|++;

# tags + regexes
my @protected_labels = (
    "XML1",
    "XML2",
    "XML3",
    "EMAIL",
    "URL1",
    "TWITTER",
    "URL2",
    "HASHTAG",
    "HASHTAG",
    "URL3",
#    "URL4",
#    "URL5",
    "HASH",
    "RETWEET"
);

my @protected_patterns = (
    qr{<\/?\S+\/?>},                             #XML1
    qr{<\S+( [a-zA-Z0-9]+\=\"?[^\"]\")+ ?\/?>},  #XML2
    qr{<\S+( [a-zA-Z0-9]+\=\'?[^\']\')+ ?\/?>},  #XML3
    qr{[\w\-\_\.]+\@([\w\-\_]+\.)+[a-zA-Z]{2,}}, #EMAIL
    qr{([\(]*http[s]?|ftp):\/\/[^:\/\s]+(\/\w+)*[\w\-\.\/#]+}, #URL1
    qr{@[a-zA-Z0-9_]{2,}},                       #TWITTER
    qr{(http[s]?|ftp):\/\/},                     #URL2
    qr{#[\s]*[\p{Letter}\p{Number}_]{2,}},       #HASHTAG (1)
    qr{#[\s]*[\p{L}\p{N}\p{M}_]{2,}},            #HASHTAG (2)
    qr{([\(]*http[s]?|ftp):\/[^:\/\s]+(\/\w+)*[\w\-\.\/#\)]+},   #URL3
    #qr{[\(]*http[s]?|ftp:\/[^:\/\s]+\/\w+[\w\-\.\/#\)]+},   #URL3
    qr{#}, #HASH
    qr{^[Rr][Tt][:]*} #RETWEET
);

# UTF-8 everywhere
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# remove-non-printing-characters.perl
sub removeNonPrintingCharacters {

    my ($line) = @_;
    $line =~ s/\p{C}/ /g;
    return $line;
}

# remove-diacritics.perl
sub removeDiacritics {
    
    my ($line) = @_;
    $line =~ s/\p{NonspacingMark}//g;
    return $line;
}

# normalize-punctuation.perl
sub normalizePunctuation {

    my ($line) = @_;

    $line =~ s/\r//g;
    # remove extra spaces
    #$line =~ s/\(/ \(/g;
    #$line =~ s/\)/\) /g; s/ +/ /g;
    $line =~ s/\) ([\.\!\:\?\;\,])/\)$1/g;
    #$line =~ s/\( /\(/g;
    #$line =~ s/ \)/\)/g;
    $line =~ s/(\d) \%/$1\%/g;
    $line =~ s/ :/:/g;
    $line =~ s/ ;/;/g;
    # normalize unicode punctuation
    $line =~ s/\`/\'/g;
    $line =~ s/\'\'/ \" /g;
    $line =~ s/„/\"/g;
    $line =~ s/“/\"/g;
    $line =~ s/”/\"/g;
    $line =~ s/–/-/g;
    $line =~ s/—/ - /g; s/ +/ /g;
    $line =~ s/´/\'/g;
    $line =~ s/([a-z])‘([a-z])/$1\'$2/gi;
    $line =~ s/([a-z])’([a-z])/$1\'$2/gi;
    $line =~ s/‘/\"/g;
    $line =~ s/‚/\"/g;
    $line =~ s/’/\"/g;
    $line =~ s/''/\"/g;
    $line =~ s/´´/\"/g;
    $line =~ s/…/.../g;
    # French quotes
    $line =~ s/ « / \"/g;
    $line =~ s/« /\"/g;
    $line =~ s/«/\"/g;
    $line =~ s/ » /\" /g;
    $line =~ s/ »/\"/g;
    $line =~ s/»/\"/g;
    # handle pseudo-spaces
    $line =~ s/ \%/\%/g;
    $line =~ s/nº /nº /g;
    $line =~ s/ :/:/g;
    $line =~ s/ ºC/ ºC/g;
    $line =~ s/ cm/ cm/g;
    $line =~ s/ \?/\?/g;
    $line =~ s/ \!/\!/g;
    $line =~ s/ ;/;/g;
    $line =~    s/, /, /g; s/ +/ /g;
    #English Quote
    $line =~ s/\"([,\.]+)/$1\"/g;
    #final one
    $line =~ s/(\d) (\d)/$1.$2/g;

    return $line;
}

sub pretagTwitterZone {

    my ($text) = @_;

    my @protected = ();
    my @protlabel = ();

    for my $i ( 0 .. $#protected_patterns ) {

	#shorthand plz
	my $protected_pattern = $protected_patterns[$i];
	my $protected_label = $protected_labels[$i];
	my $t = $text;
	
	while ($t =~ /($protected_pattern)/) {
	    push @protected, $1;
	    push @protlabel, $protected_label;
	    $t =~ s/$1//;
	    #$t =~ s/\Q$1\E//;
	}
	
    }
    
    #we do this to avoid patterns stomping on each other...
    for (my $i = 0; $i < scalar(@protected); ++$i) {
      my $subst = sprintf("THISISPROTECTED%.3d", $i);
      $text =~ s,\Q$protected[$i], $subst ,g;
    }
    $text =~ s/ +/ /g;
    $text =~ s/^ //g;
    $text =~ s/ $//g;

    # restore patterns finally
    for (my $i = 0; $i < scalar(@protected); ++$i) {
	my $label = $protlabel[$i];
	my $prot  = $protected[$i];
	my $trans = $prot;
	#gloss_lookup($prot, $label);
	my $subst = sprintf("THISISPROTECTED%.3d", $i);
	my $tagged = "";
	if($label eq "HASHTAG") {
	    
	    #remove hash
	    $prot =~ s/^#//;
	    my @pieces = split /_/, $prot ;
	    #gotta do it this way otherwise we get reordered like crazy
	    $tagged = "<zone> <ht translation=\"#BEGIN\">#BEGIN</ht> <wall /> " . join(" ", @pieces) . " <wall /> <ht translation=\"#END\">#END</ht></zone>";
	    #original variant - hash mark+end don't stay put
	    #$tagged = "<zone> <ht translation=\"#\">#</ht> " . join(" ", @pieces) . " <ht translation=\"#END\">#END</ht></zone>";
	    #Variant B
	    #$tagged = "<ht translation=\"#\">#</ht> <zone> " . join(" ", @pieces) . "</zone> <ht translation=\"#END\">#END</ht>";
	}
	else {
	    $tagged = sprintf("<%s translation=\"%s\">%s</%s>", $label, $trans, $prot, $label);
	}
	$text =~ s/$subst/$tagged/g;
    }
    $text =~ s/ +/ /g;
    $text =~ s/^ //g;
    $text =~ s/ $//g;

    return $text;
}

sub mosesProcZone {

    my ($line) = @_;

    #output sentence
    my @out = ();
    my @fragments = split /\s+/, $line;

    my $inTag = 0;
    my @outfrag = ();
    foreach my $f (@fragments) {
	#check to see if we're starting a tag
	if($f =~ /^</ && $f ne "<wall") {
	    
	    #if outfrag is not empty flush it to out -
	    #we're done with that stretch
	    if(scalar(@outfrag) > 0 ) {

		push @out, join(" ", @outfrag);

		#empty, move on
		@outfrag = ();
	    }
	    
	    #add fragment
	    push @outfrag, $f;
	}
	#closing tag
	elsif($f =~ /<\/[a-zA-Z0-9]+>$/ || $f eq "/>") {
	    
	    push @outfrag, $f;
	    push @out, join(" ", @outfrag);
	    
	    @outfrag = ();
	}
	#default
	else {
	    push @outfrag, $f;
	}
    }

    #check for leftovers
    if(scalar(@outfrag) > 0 ) {
	push @out, join(" ", @outfrag);
    }

    my @procout = ();
    foreach my $o (@out) {
	
	#XML
	if($o =~ /^</ ) {
	    push @procout, $o;
	}
	#ending of wall tag
	elsif($o =~ /\/>$/){
	    push @procout, $o;
	}
	#tokenize,
	else {

	    my $input = tokenize($o);
	    #add to output
	    push @procout, $input;
	}

    }

    #write processed fragments
    return join(" ", @procout);
}

#selected guts of the moses tokenizer
# doesn't do non-breaking yet, but should
sub tokenize
{
    my($text) = @_;

    chomp($text);
    $text = " $text ";

    # remove ASCII junk
    $text =~ s/\s+/ /g;
    $text =~ s/[\000-\037]//g;

    #fix spacing
    $text =~ s/ +/ /g;
    $text =~ s/^ //g;
    $text =~ s/ $//g;

    # separate out all "other" special characters
    $text =~ s/([^\p{IsAlnum}\s\.\'\`\,\-])/ $1 /g;

    # separate out "," except if within numbers (5,300)
    # previous "global" application skips some:  A,B,C,D,E > A , B,C , D,E
    # first application uses up B so rule can't see B,C
    # two-step version here may create extra spaces but these are removed later
    # will also space digit,letter or letter,digit forms (redundant with next section)
    $text =~ s/([^\p{IsN}])[,]/$1 , /g;
    $text =~ s/[,]([^\p{IsN}])/ , $1/g;

    #contraction hack - add the moses guts
    #back if you're 
    $text =~ s/\'/ \' /g;

    # clean up extraneous spaces
    $text =~ s/ +/ /g;
    $text =~ s/^ //g;
    $text =~ s/ $//g;

    return $text;
}

# hmm
# print STDERR "Patterns: " . scalar(@protected_patterns) . "\n";

while (my $line = <STDIN>) {
    
    chomp($line);
    
    # remove-non-printing-characters.perl
    $line = removeNonPrintingCharacters($line);

    #remove illegal chars like pipe '|'
    $line =~ s/\|/ /g;    

    # Head off problematic parens around URLS...
    $line =~ s/\(/ \( /g;
    $line =~ s/\)/ \) /g;

    # remove-diacritics.perl
    $line = removeDiacritics($line);

    # normalize-punctuation.perl
    $line = normalizePunctuation($line);

    # pretag-twitter-zone.perl
    $line = pretagTwitterZone($line);

    # moses_proc_zone.perl
    $line = mosesProcZone($line);

    # finally, output
    print $line . "\n";
}
