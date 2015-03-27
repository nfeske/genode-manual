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


##
# Return string of the return type description as used in UML class diagrams
#
proc return_type_uml_style { func_token } {

	set return_type [function_return_type $func_token]
	if {$return_type == "void"} { set return_type "" }
	if {$return_type != ""} {
	set return_type ":\\ $return_type" }

	return $return_type
}


proc generate_list_of_arguments { arguments label_one label_multi } {

	if {[llength $arguments] != 0} {
		set arguments_label $label_one
		if {[llength $arguments] > 1} { set arguments_label $label_multi }
		puts "\\apisection{$arguments_label}{0.95,0.95,0.95}"

		puts "\\apiboxcontent{"
		puts "  \\begin{tabularx}{0.96\\textwidth}{lX}"
		set first 1
		foreach argument $arguments {
			set arg_name    [lindex $argument 0]
			set arg_type    [lindex $argument 1]
			set arg_default [lindex $argument 2]
			set arg_desc    [lindex $argument 3]
			if {!$first} { puts {\noalign{\medskip}} }
			set first 0
			puts "    \\texttt{[out_latex $arg_name]} & \\texttt{\\textbf{[out_latex "$arg_type"]}}"
			puts "    \\\\"
			if {$arg_desc != ""} {
				puts "    & [out_latex $arg_desc]\\\\"
			}
			if {$arg_default != ""} {
				puts "    & \\textit{Default is \\texttt{[out_latex $arg_default]}}\\\\"
			}
		}
		puts "  \\end{tabularx}"
		puts "} % apiboxcontent"
	}
}


proc generate_function_info_sections { func_token } {

	# brief description
	set brief_description [function_brief_description $func_token]
	if {$brief_description != ""} {
		puts "\\apiboxcontent{"
		puts "  \\begin{minipage}{10cm}"
		puts "    [out_latex $brief_description]"
		puts "  \\end{minipage}"
		puts "}"
	} else {
		puts "\\apiboxvspace{0.9ex}"
	}

	# arguments description
	set arguments [function_arguments $func_token]
	generate_list_of_arguments $arguments "Argument" "Arguments"

	# exceptions
	set exceptions [function_exceptions $func_token]
	if {[llength $exceptions] != 0} {
		set exceptions_label "Exception"
		if {[llength $exceptions] > 1} { append exceptions_label s }
		puts "\\apisection{$exceptions_label}{0.95,0.95,0.95}"
		puts "\\apiboxcontent{"
		puts "  \\begin{tabularx}{0.96\\textwidth}{lX}"
		foreach exception $exceptions {
			set exc_type [lindex $exception 0]
			set exc_desc [lindex $exception 1]
			puts "    \\texttt{\\textbf{[out_latex $exc_type]}} & [out_latex "$exc_desc"]\\\\"
		}
		puts "  \\end{tabularx}"
		puts "}"
	}

	# return value
	set return_type [function_return_type $func_token]
	if {$return_type != "void" && $return_type != ""} {
		puts "\\apisection{Return value}{0.95,0.95,0.95}"
		puts "\\apiboxcontent{"
		puts "  \\begin{tabularx}{0.96\\textwidth}{lX}"
		set return_desc [function_return_description $func_token]
		puts "   \\texttt{\\textbf{[out_latex $return_type]}} & [out_latex "$return_desc"]\\\\"
		puts "  \\end{tabularx}"
		puts "}"
	}

	# detailed description
	set detailed_description [function_detailed_description $func_token]
	if {[llength $detailed_description] > 0} {
		puts "\\apisection{Details}{0.95,0.95,0.95}"
		puts "\\apiboxcontent{"
		puts "  \\begin{minipage}{0.96\\textwidth}"
		puts "    [out_latex [join $detailed_description {\\}]]"
		puts "  \\end{minipage}"
		puts "}"
	}
}


proc generate_link_to_header { } {
	puts "\\apisection{Header}{0.95,0.95,0.95}"
	puts "\\apiboxcontent{"
	puts " \\href{[code_url][header_file]}{\\textit{[out_latex [header_file]]}}"
	puts "}"
}


