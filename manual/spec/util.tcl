#
# \brief  Utilities for processing the output of Genode's 'parse_cxx'
# \author Norman Feske
# \date   2015-03-17
#

##
# Return last command-line argument, which is always the source token file
#
proc token_file {} {
	global argv
	return [lindex $argv end]
}


##
# Return path to source header file
#
proc header_file {} {
	regsub {.tokens$} [token_file] {} result
	return $result
}


##
# Return true if command-line switch was specified
#
proc get_cmd_switch { arg_name } {
	global argv
	return [expr [lsearch $argv $arg_name] >= 0]
}


##
# Return command-line argument value
#
# If a argument name is specified multiple times, return only the
# first match.
#
proc get_cmd_arg { arg_name default_value } {
	global argv

	set arg_idx [lsearch $argv $arg_name]

	if {$arg_idx == -1} { return $default_value }

	return [lindex $argv [expr $arg_idx + 1]]
}


##
# Read input file with token data
#
proc import_tokens {file_name} {
	global token_text

	# read token file
	set tokens [exec cat $file_name]

	# build dictionary of tokens
	foreach token $tokens {
		set name [lindex $token 0]
		set text [lindex $token 2]
		set token_text($name) "$text"
	}

	if {![info exists token_text(content0)]} {
		puts stderr "Error: input contains no root token 'content0'."
		exit -1
	}
}


##
# Return type of specified token
#
proc tok_type {token} {
	regexp {[a-z]+} $token type
	return $type
}


##
# Return text of specified token
#
proc tok_text {name} {
	global token_text
	return $token_text($name)
}


##
# Execute functors 'plain_fn' and 'sub_token_fn' over a sequence of tokens
#
# The 'plain_fn' functor takes a plain-text snippet as argument.
# The 'sub_token_fn' functor takes a token as argument.
#
# \param plain_var      variable name of the 'plain_fn' argument
# \param sub_token_var  variable name of the 'sub_token_fn' argument
#
proc foreach_sub_token {sequence plain_var plain_fn sub_token_var sub_token_fn} {

	upvar $plain_var     plain
	upvar $sub_token_var sub_token

	while {$sequence != ""} {

		# consume plain text
		if {[regexp {^[^§]+} $sequence plain]} {
			uplevel 1 $plain_fn
			regsub {^[^§]+} $sequence "" sequence
		}

		# consume token
		if {[regexp {§(.+?)°} $sequence dummy sub_token]} {
			uplevel 1 $sub_token_fn
			regsub {§(.+?)°} $sequence "" sequence
		}
	}
}


##
# Turn tree of tokens into plain text
#
proc unfold_token {{token content0}} {

	set output ""

	foreach_sub_token [tok_text $token] plain {

		# perform character substitutions for LaTeX compliance
		regsub -all {³} $plain "\\&" plain

		append output $plain
	} sub_token {
		append output [unfold_token $sub_token]
	}

	return $output
}


##
# Find and return a sub token of the specified type
#
proc sub_token {token token_type} {

	if {[regexp "§($token_type\\d+)°" [tok_text $token] dummy sub_token]} {
		return $sub_token
	} else {
		return ""
	}
}


##
# Return class name of specified token
#
# The token may be of the types 'struct', 'class', 'tplstruct', or 'tplclass'.
#
proc class_name { token } {

	if {[tok_type $token] == "struct" || [tok_type $token] == "class"} {
		set name_token [sub_token $token identifier]
		return [unfold_token $name_token]
	}

	if {[tok_type $token] == "tplstruct"} {
		set struct_token [sub_token $token struct]
		return [class_name $struct_token]
	}

	if {[tok_type $token] == "tplclass"} {
		set class_token [sub_token $token class]
		return [class_name $class_token]
	}

	return ""
}


##
# Find class with specified name
#
proc find_class_by_name { token class_name } {

	set result ""
	foreach_sub_token [tok_text $token] plain { } token {

		if {[class_name $token] == "$class_name"} {
			set result $token;
		}
	}
	return $result
}


##
# Return list of the names of the public base classes of a class
#
proc public_base_classes { class_token } {

	if {[tok_type $class_token] == "tplclass"} {
		return [public_base_classes [sub_token $class_token class]] }

	if {[tok_type $class_token] == "tplstruct"} {
		return [public_base_classes [sub_token $class_token struct]] }

	set inherit_token [sub_token $class_token inherit]
	if {"$inherit_token" == ""} return ""

	set sequence [tok_text $inherit_token]

	set base_classes {}

	if {[tok_type $class_token] == "struct"} {

		# filter out private base classes from sequence
		regsub -all {§keyprivate\d+°\s*§identifier\d+°} $sequence {} sequence

		# append remaining identifiers
		foreach_sub_token $sequence plain { } token {
			if {[tok_type $token] == "identifier"} {
				lappend base_classes [unfold_token $token]
			}
		}
	}

	if {[tok_type $class_token] == "class"} {

		# match public base classes in sequence
		set pattern {§keypublic\d+°\s*§(identifier\d+)°}
		while {[regexp $pattern $sequence dummy identifier_token]} {

			lappend base_classes [unfold_token $identifier_token]

			# consume matched part of the sequence
			regsub $pattern $sequence {} sequence
		}
	}

	return $base_classes
}


