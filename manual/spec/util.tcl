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
proc tok_type { token } {
	regexp {[a-z]+} $token type
	return $type
}


##
# Return text of specified token
#
proc tok_text { token } {
	global token_text
	return $token_text($token)
}


proc tok_valid { token } {
	return [string length $token]
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
proc foreach_sub_token { sequence plain_var plain_fn sub_token_var sub_token_fn } {

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

	if {![tok_valid $token]} { return "" }

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

	if {$token == ""} { return "" }
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


##
# Return true if multi-line comment starts with "/**"
#
proc mlcomment_is_public { mlcomment } {

	return [regexp {^\s*/\*\*\n} $mlcomment]
}


##
# Parse multi-line comment
#
# The function returns a list of comment parts. A part may be a paragraph or a
# item that starts with "/".
#
proc parse_mlcomment { mlcomment } {

	# eliminate leading and trailing comment characters (/** and */)
	regsub {^/\*+\n} $mlcomment {} mlcomment
	regsub {\s*\*/$} $mlcomment {} mlcomment

	# list of parts
	set result {}

	# content of current part
	set part ""

	foreach line [split $mlcomment "\n"] {

		#
		# Remove leading whitespace and the '*' character. The '*' is normally
		# followed by a space, except when it is in front of an empty line.
		#
		regsub {^\s*\*} $line "" line
		regsub {^ }    $line "" line
		regsub {^\s+$} $line "" line

		# detect beginning of a new part
		if {$line == "" || [regexp {^\\} $line dummy]} {

			# append non-empty part to list
			if {$part != ""} {
				lappend result $part }

			# begin new part
			set part ""
		}

		#
		# Append current line to current part. Remove leading whitespace
		# that may be present if parameter descriptions span multiple lines.
		#
		regsub {^\s+} $line " " line

		if {$line != ""} {
			set part [concat $part " " $line] }
	}

	lappend result $part

	return $result
}


##
# Return the number of top-level classes in the header file
#
proc number_of_top_level_classes { } {

	set count 0
	foreach token_type { class struct classtpl structtpl } {
		incr count [regsub -all "§$token_type\\d+°" [tok_text content0] {} dummy]
	}
	return $count
}


##
# Return token for the multi-line comment in the file header
#
proc header_comment { } {

	set header_token [sub_token content0 mlcomment]

	if {[tok_valid $header_token]} {
		return [parse_mlcomment [tok_text $header_token]] }

	return ""
}


##
# Return parsed multi-line comment for a function
#
proc function_comment { func_token } {

	set mlcomment_token [sub_token $func_token mlcomment]
	if {[tok_valid $mlcomment_token]} {
		return [parse_mlcomment [tok_text $mlcomment_token]] }

	return ""
}


##
# Return the brief description of a class
#
proc brief_class_description { class_token } {

	#
	# If the class is prepended with a multi-line comment, take the
	# brief description from there
	#
	set comment_token [sub_token $class_token mlcomment]
	if {[tok_valid $comment_token]} {

		set mlcomment [tok_text $comment_token]
		if {[mlcomment_is_public $mlcomment]} {

			set mlcomment_parts [parse_mlcomment $mlcomment]
			if {[llength $mlcomment_parts]} {
				return [lindex $mlcomment_parts 0]
			}
		}
	}

	#
	# Class lacks a valid multi-line comment. If the class is the only
	# class contained in the header, we use the header's brief description
	#
	if {[number_of_top_level_classes] == 1} {

		# search the mlcomment of the file header for a brief description
		foreach part [header_comment] {

			if {[regexp {^\\brief\s} $part]} {
				regsub {^\\brief\s+} $part "" part
				return $part
			}
		}
	}
	return ""
}


##
# Return true if class contains RPC annotations
#
proc class_is_rpc_interface { class_token } {

	set classblock_token [sub_token $class_token classblock]
	if {$classblock_token == ""} { return 0 }
	if {[sub_token $classblock_token genoderpc] != ""} { return 1 }
	return 0
}


##
# Return function name
#
proc function_name { func_token } {

	if {[is_function $func_token]} {
		set funcsignature_token [sub_token $func_token          funcsignature]
		set name_token          [sub_token $funcsignature_token identifier]
		set tilde ""
		if {[sub_token $func_token tilde] != ""} { set tilde "~" }
		return "$tilde[unfold_token $name_token]"
	}
}


##
# Return the return type of a function
#
proc function_return_type { func_token } {

	if {[is_function $func_token]} {
		set retval_token [sub_token $func_token retval]
		if {$retval_token != ""} {
			return [concat [unfold_token $retval_token]] }
	}

	return ""
}


##
# Return the multi-line comment of a compound token
#
proc mlcomment_parts { token } {

	set comment_token [sub_token $token mlcomment]
	if {[tok_valid $comment_token]} {

		set mlcomment [tok_text $comment_token]
		if {[mlcomment_is_public $mlcomment]} {

			return [parse_mlcomment $mlcomment]
		}
	}

	return {}
}


##
# Return the brief description of a function
#
proc function_brief_description { function_token } {

	set mlcomment_parts [mlcomment_parts $function_token]
	if {[llength $mlcomment_parts]} {

		set brief [concat [lindex $mlcomment_parts 0]]

		if {$brief == "Constructor" || $brief == "Destructor"} {
			return "" }

		#
		# Filter out brief descriptions starting with "Return" or "Returns".
		# This information is captured by 'function_return_value' instead.
		#
		if {[regexp {^Returns?\s+} $brief]} { return "" }

		return $brief
	}
	return ""
}


##
# Return list of paragraphs of the detailed description of a function
#
proc function_detailed_description { function_token } {

	set result {}
	set first 1
	foreach part [mlcomment_parts $function_token] {

		if {!$first && ![regexp {^\\} $part]} {
			lappend result $part }

		set first 0
	}
	return $result
}


##
# Return true if token is a function
#
proc is_function { token } {

	foreach token_type { funcdecl funcimpl constdecl constimpl destdecl destimpl } {
		if {[tok_type $token] == "$token_type"} {
			if {![function_is_blacklisted $token]} {
				return 1 }
		}
	}

	return 0
}


##
# Return true if function is specified modifier
#
proc function_has_modifier { func_token modifier } {

	set modifier_token [sub_token $func_token modifier]
	if {$modifier_token != ""} {
		set modifiers [unfold_token $modifier_token]
		return [regexp $modifier $modifiers]
	}

	return 0
}


##
# Return true if is tagged with "\noapi" in its comment
#
proc function_is_blacklisted { func_token } {

	foreach part [mlcomment_parts $func_token] {
		if {[regexp {\\noapi} $part]} { return 1 }
	}
	return 0;
}


proc function_is_static { func_token } {
	return [function_has_modifier $func_token static] }


proc function_is_virtual { func_token } {
	return [function_has_modifier $func_token virtual] }


proc function_is_pure_virtual { func_token } {
	return [expr {[sub_token $func_token virtassign] != ""}] }


proc function_is_const { func_token } {
	return [expr {[sub_token $func_token keyconst] != ""}] }


##
# Return true if the method is an accessor (getter)
#
# An accessor is an argument-less const function with a return value.
#
proc function_is_accessor { func_token } {

	if {[function_is_static $func_token]}                { return 0; }
	if {![function_is_const $func_token]}                { return 0; }
	if {[llength [function_arguments $func_token]] != 0} { return 0; }
	if {[function_return_type $func_token] == "void"}    { return 0; }
	if {[function_return_type $func_token] == ""}        { return 0; }
	if {[llength [mlcomment_parts $func_token]] != 0}    { return 0; }

	return 1
}


##
# Return true if function should be described in detail
#
proc function_is_interesting { func_token } {

	#
	# Skip overrides with no prepending comment. Those are mere implementation
	# of an abstract interface defined somewhere else.
	#
	if {[sub_token $func_token keyoverride] != "" &&
		[sub_token $func_token mlcomment] == ""} {
		return 0
	}

	#
	# Accessors are listed only at the class description
	#
	if {[function_is_accessor $func_token]} { return 0; }

	#
	# A destructor or constructor without comments is not interesting
	#
	foreach func_type { constdecl constimpl destdecl destimpl } {
		if {[tok_type $func_token] == "$func_type"} {
			set num_mlcomment_parts [llength [mlcomment_parts $func_token]]
			if {$num_mlcomment_parts == 0} { return 0 }

			# trivial comments do not make a constructor or destructor interesting
			if {$num_mlcomment_parts == 1 &&
			    [function_brief_description $func_token] == ""} { return 0 }
		}
	}

	return 1
}


##
# Return description of function argument as present in the mlcomment
#
proc function_argument_description { function_token arg_name } {

	foreach part [function_comment $function_token] {
		if {[regexp {^\\param\s+([^ ]+)\s+(.*)$} $part dummy name desc]} {
			if {$name == $arg_name} {
				return [string totitle $desc]
			}
		}
	}
	return ""
}


##
# Return list of function arguments
#
# Each list item is a list of name, type, default, and description.
#
proc function_arguments { func_token } {

	set funcsignature_token [sub_token $func_token          funcsignature]
	set argparenblk_token   [sub_token $funcsignature_token argparenblk]

	if {$argparenblk_token == ""} { return {} }

	set args {}
	foreach_sub_token [tok_text $argparenblk_token] plain { } token {

		if {[tok_type $token] == "argdecl"} {

			set arg_type [unfold_token [sub_token $token argtype]]

			#
			# Determine argument name
			#
			set arg_name ""
			if {[tok_type $token] == "argdecl"} {
				set arg_name [unfold_token [sub_token $token argname]]

				# try to infer the argument name from commented-out name
				if {$arg_name == ""} {
					set arg_lcomment [unfold_token [sub_token $token lcomment]]
					regexp {/\*\s*(.+)\s*\*/} $arg_lcomment dummy arg_name
				}
			}
			if {$arg_name == ""} { set arg_name "-" }

			#
			# Determine default value
			#
			set arg_default ""
			set arg_default [unfold_token [sub_token $token argdefault]]
			regsub {=\s*} $arg_default "" arg_default

			#
			# Determine argument description from the function's mlcomment
			#
			set arg_desc [function_argument_description $func_token $arg_name]

			lappend args [list $arg_name $arg_type $arg_default $arg_desc]
		}
	}
	return $args
}


##
# Return information about the function's return value
#
proc function_return_description { func_token } {

	set retval_token [sub_token $func_token retval]

	set ret_desc ""

	# look for \return annotation in the multi-line comment
	foreach part [function_comment $func_token] {
		if {[regexp {^\\return\s+(.*)$} $part dummy desc]} {
			set ret_desc [string totitle $desc] } }

	#
	# If not \return annotation was found, look if the brief description
	# starts with "Return" or "Returns"
	#
	if {$ret_desc == ""} {
		set mlcomment_parts [mlcomment_parts $func_token]
		if {[llength $mlcomment_parts]} {

			set first_mlcomment_part [concat [lindex $mlcomment_parts 0]]

			if {[regexp {^Returns?\s+(.*)} $first_mlcomment_part dummy brief]} {
				set ret_desc [string totitle $brief]
			}
		}
	}

	return [concat $ret_desc]
}


##
# Return list of function-exception infos
#
# Each list item is a list of the exception type and description.
#
proc function_exceptions { func_token } {

	set exc_list {}
	foreach part [mlcomment_parts $func_token] {

		if {[regexp {^\\throw\s+([^ ]+)\s*(.*)} $part dummy exc_type exc_desc]} {
			lappend exc_list [list $exc_type $exc_desc]
		}
	}
	return $exc_list
}


##
# Extract sequence of public members from class or struct tokens
#
proc public_class_members { class_token } {

	if {[tok_type $class_token] == "tplclass"} {
		set class_token [sub_token $class_token class] }

	if {[tok_type $class_token] == "tplstruct"} {
		set class_token [sub_token $class_token struct] }

	set classblock_token [sub_token $class_token classblock]

	set members_sequence {}
	if {[tok_type $class_token] == "struct"} {

		foreach_sub_token [tok_text $classblock_token] plain { } token {
			if {[tok_type $token] == "declseq"} {
				append members_sequence [tok_text $token]
			}
		}
	}

	if {[tok_type $class_token] == "class"} {

		foreach_sub_token [tok_text $classblock_token] plain { } prot_token {
			if {[tok_type $prot_token] == "public"} {
				foreach_sub_token [tok_text $prot_token] plain { } token {
					if {[tok_type $token] == "declseq"} {
						append members_sequence [tok_text $token]
					}
				}
			}
		}
	}
	return $members_sequence
}


##
# Return list of accessors for given class
#
proc accessor_functions { class_token } {

	set accessors {}
	set members_sequence [public_class_members $class_token]
	foreach_sub_token $members_sequence plain { } token {
		if {[is_function $token] && [function_is_accessor $token]} {
			lappend accessors $token
		}
	}

	return $accessors
}


##
# Return true if class has members
#
proc class_has_members { class_token } {

	set members_sequence [public_class_members $class_token]
	set has_members 0
	foreach_sub_token $members_sequence plain { } token {
		if {[is_function $token]} {
			set has_members 1 } }

	return $has_members
}


##
# Return list of paragraphs of the detailed description of a class
#
proc class_detailed_description { class_token } {

	# the implementation happens to be identical for classes and functions
	return [function_detailed_description $class_token]
}
