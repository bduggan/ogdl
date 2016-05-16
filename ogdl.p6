#!/usr/bin/env perl6

# Parse ogdl (http://ogdl.org/spec/)

grammar ogdl {
    rule TOP         {<graph>.*}
    token char_text  { <[\c[33]..\c[255]]> }  # integer > 32
    token char_space { ' ' | \t    }          # 32 | 9
    token char_break { "\r" | "\n" }
    token char_end   { <[\c[00] .. \c[31]] - [\c[09]] - [\c[10]] - [\c[13]]> }
    regex word       { <[\c[33] .. \c[255]] - [\"] - [\#] - [\'] >+ <[\c[33] .. \c[255]] - [\"] - [\'] > }
    regex string     { [ <.char_text> | <.char_space> ] + }
    token break      { "\r" | "\n" | "\r\n" }
    regex comment    { '#' <string>? <break> }
    regex quoted     { '\'' <string> '\'' | '"' <string> '"' }
    token space      { <.char_space>+ }
    regex block      { '\\' <break> [ <space> <string>? <break> ]+ }
    regex element    { <word> | <quoted> }  # | group
    regex line       { <.space>? [ <element>+ %% [ ',' | ' '+ ] ]? <.break> }
    regex graph      { <line>* <.char_end> }
    # also :
    #rule arc ::= "#=" relative_path space? break
    #rule relative_path ::= '.'* ogdl_path
}

use Test;

is ogdl.parse("n",         :rule<char_text>), 'n', 'char_text';
is ogdl.parse("network",   :rule<string>), 'network', 'string';
is ogdl.parse(' ',         :rule<char_space>), ' ', 'char_space';
is ogdl.parse('  ',        :rule<space>), '  ', 'space';
is ogdl.parse('abcd',      :rule<word>), 'abcd', 'word';
is ogdl.parse('"abcd"',    :rule<quoted>), '"abcd"', 'quoted';
is ogdl.parse("'abcd'",    :rule<quoted>), "'abcd'", 'quoted';
is ogdl.parse("\n",        :rule<break>), "\n", 'break';
my $block = Q:to/HERE/;
\
    block
HERE
is ogdl.parse($block,         :rule<block>), $block, 'block';
is ogdl.parse("\f",           :rule<char_end>), "\f", 'char_end';
nok ogdl.parse(" ",           :rule<char_end>), 'char_end';
is ogdl.parse("'abcd'",       :rule<element>), "'abcd'", 'element';
is ogdl.parse("ab",           :rule<element>), "ab", 'element';
is ogdl.parse("abcd\n",       :rule<line>), "abcd\n", 'line';
is ogdl.parse("  abcd\n",     :rule<line>), "  abcd\n", 'line';
is ogdl.parse("ab,cd\n",      :rule<line>), "ab,cd\n", 'line';
ok ogdl.parse("    ip    192.168.0.10\n", :rule<line>), 'line';
ok ogdl.parse("network\n\f\n"), 'graph';
ok ogdl.parse("network\n  eth0\n\f\n"), 'graph';
ok ogdl.parse("network\n  eth0\n    ip    192.168.0.10\n\f\n"), 'graph';
ok ogdl.parse("# a comment\n", :rule<comment>), 'graph';
ok ogdl.parse("\n",            :rule<line>), 'line';
my $graph = qq:to/DONE/;
network
  eth0
    ip   192.168.0.10
    mask 255.255.255.0
    gw   192.168.0.1

hostname crispin
\f
DONE
ok ogdl.parse($graph), 'graph';

my $match = ogdl.parse($graph);
is $match<graph><line>[0]<element>, 'network', 'network';
is $match<graph><line>[1]<element>[0], 'eth0', 'eth0';
is $match<graph><line>[2]<element>[0], 'ip', 'ip';
is $match<graph><line>[2]<element>[1], '192.168.0.10', '192.168.0.10';

#diag ogdl.parse($graph).gist;

done-testing;
