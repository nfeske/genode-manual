#
# \brief  Utilities for producing LaTeX output
# \author Norman Feske
# \date   2015-03-18
#
# Based on the code of GOSH
#

proc seal_repl {replace_string} {
	regsub -all {&} $replace_string {\\&} replace_string
	return $replace_string
}


proc out_latex {string} {
	global references
	
	set string " $string "
	
	# italic style
	while {[regexp {([ \"\(])_(.+?)_([ \)\.\",:!?\-])} $string dummy head_char emph_text tail_char]} {
		regsub {^_} $emph_text " " emph_text
		regsub {_$} $emph_text " " emph_text
		regsub {([ \"\(])_(.+?)_([ \)\.\",:!?\-])} $string [seal_repl "$head_char\\emph{$emph_text}$tail_char"] string
	}

	# bold style
	while {[regexp {([ \"\(])\*([^*]+?[^ ])\*([ \)\.\",:!?])} $string dummy head_char bf_text tail_char]} {
		regsub -all {\*} $bf_text " " bf_text
		regsub {([ \"\(])\*([^*]+?[^ ])\*([ \)\.\",:!?])} $string [seal_repl "$head_char\\textbf{$bf_text}$tail_char"] string
	}
	
	# monospace style
	while {[regexp {([ \"\(])\'(.+?)\'([ \-\)\.\"\',:!?])} $string dummy head_char code_text tail_char]} {
		regsub {([ \"\(])\'(.+?)\'([ \-\)\.\"\',:!?])} $string [seal_repl "$head_char\\texttt{$code_text}$tail_char"] string
	}
	
	regsub -all {_citation_gap_} $string "\[\\ldots\{\}\]" string
	regsub -all {"([\w\\])} $string "``\\1" string
	regsub -all {([\.\?\!\w\}])"} $string "\\1''" string
	regsub -all {\^} $string "\\^{ }" string
	regsub -all {_} $string "\\_" string
	regsub -all {#} $string "\\#" string
	regsub -all {%} $string "\\%" string
	regsub -all {\$} $string "\\$" string
	regsub -all {&} $string {\\&} string
	regsub -all {^ *} $string "" string
	regsub -all { *$} $string "" string
	regsub -all {~} $string {\\textasciitilde{}} string
	regsub -all {µ} $string "\$\\mu\$" string

	regsub -all {<->} $string "\$\\leftrightarrow\$" string
	regsub -all -- {->} $string "\$\\rightarrow\$" string
	regsub -all {<-} $string "\$\\leftarrow\$" string
	regsub -all {<=>} $string "\$\\Leftrightarrow\$" string
	regsub -all {=>} $string "\$\\Rightarrow\$" string
	regsub -all {<=} $string "\$\\Leftarrow\$" string
	
	regsub -all {<} $string "\\mbox{\$<\$}" string
	regsub -all {>} $string "\\mbox{\$>\$}" string

	regsub -all {e\.g\.} $string "e.\\,g." string
	regsub -all {i\.e\.} $string "i.\\,e." string

	return $string
}

