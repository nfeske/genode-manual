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
# Return base URL for browsing the source code
#
# XXX evaluate command-line argument
#
proc code_url { } { return "https://github.com/genodelabs/genode/blob/22.05/" }


##
# Turn the first letter of a given string to upper case
#
# In contrast to Tcl's built-in 'string totitle' function, this function
# leaves the remaining characters untouched.
#
proc to_title {str} {
	return [string replace $str 0 0 [string toupper [string index $str 0]]]
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
		set result [unfold_token $name_token]

		#
		# Strip template arguments from class name. This is needed for
		# classed defined within the scope of a class template, i.e.,
		# the 'Rpc_object::Capability_guard'.
		#
		regsub -all {<[^>]*>} $result "" result
		return $result
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
# Return true if token is a class template
#
proc is_class_template { token } {

	if {[tok_type $token] == "tplstruct" || [tok_type $token] == "tplclass"} {
		return 1 }

	return 0
}


##
# Return true if token is a function template
#
proc is_function_template { token } {

	if {[tok_type $token] == "tplfunc" || [tok_type $token] == "tplfuncdecl"} {
		return 1 }

	return 0
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
# Find function with specified name
#
proc find_func_by_name { token func_name } {

	set result ""
	foreach_sub_token [tok_text $token] plain { } token {

		if {[function_name $token] == "$func_name"} {
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
# Return brief comment in file header
#
proc header_brief_comment { } {

	foreach part [header_comment] {
		if {[regexp {^\\brief\s} $part]} {
			regsub {^\\brief\s+} $part "" part
			return $part
		}
	}
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
		return [header_brief_comment]
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
# Return function token that is embedded in a template function token
#
proc tplfunc_function { tplfunc_token } {

	foreach token_type { funcdecl funcimpl constdecl constimpl destdecl destimpl } {
		set func_token [sub_token $tplfunc_token $token_type]
		if {$func_token != ""} {
			return $func_token }
	}
	return ""
}


proc function_is_operator { func_token } {

	set operatorfunction_token [sub_token $func_token operatorfunction]
	if {$operatorfunction_token != ""} { return 1 }
	return 0
}


##
# Return function name
#
proc function_name { func_token } {

	if {[is_function_template $func_token]} {
		set func_token [tplfunc_function $func_token] }

	if {[is_function $func_token]} {

		if {[function_is_operator $func_token]} {

			set operatorfunction_token [sub_token $func_token operatorfunction]
			set operator_name_token [sub_token $operatorfunction_token operator]
			set operator_name [concat [unfold_token $operator_name_token]]
			regsub {\s+} $operator_name " " operator_name
			return $operator_name

		} else {
			set funcsignature_token [sub_token $func_token          funcsignature]
			set name_token          [sub_token $funcsignature_token identifier]
			set tilde ""
			if {[sub_token $func_token tilde] != ""} { set tilde "~" }
			return "$tilde[unfold_token $name_token]"
		}
	}

	return ""
}


##
# Return the return type of a function
#
proc function_return_type { func_token } {

	if {[is_function_template $func_token]} {
		set func_token [tplfunc_function $func_token] }

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

	foreach token_type { funcdecl funcimpl constdecl constimpl destdecl destimpl tplfunc tplfuncdecl } {
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
		if {[regexp {\\((noapi)|(deprecated))} $part]} { return 1 }
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
# Return true if method should be described in detail
#
proc method_is_interesting { func_token } {

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
	# A destructor or constructor without comments and arguments is not interesting
	#
	foreach func_type { constdecl constimpl destdecl destimpl } {
		if {[tok_type $func_token] == "$func_type"} {

			if {[llength [function_arguments $func_token]] > 0} { return 1 }

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
				return [to_title $desc]
			}
		}
	}
	return ""
}


proc argparenblk_arguments { compound_token argparenblk_token } {

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
				set arg_name [concat [unfold_token [sub_token $token argname]]]

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
			set arg_desc [function_argument_description $compound_token $arg_name]

			lappend args [list $arg_name $arg_type $arg_default $arg_desc]
		}

		if {[tok_type $token] == "varargs"} {

			lappend args [list "..." "..." "" ""]
		}
	}
	return $args
}


##
# Return list of function arguments
#
# Each list item is a list of name, type, default, and description.
#
proc function_arguments { func_token } {

	set orig_func_token $func_token

	if {[is_function_template $func_token]} {
		set func_token [tplfunc_function $func_token] }

	if {[function_is_operator $func_token]} {
		set operatorfunction_token [sub_token $func_token operatorfunction]
		set argparenblk_token [sub_token $operatorfunction_token argparenblk]
	} else {
		set funcsignature_token [sub_token $func_token funcsignature]
		set argparenblk_token [sub_token $funcsignature_token argparenblk]
	}

	return [argparenblk_arguments $orig_func_token $argparenblk_token]
}


##
# Return list of function template arguments
#
# Each list item is a list of name, type, default, and description.
#
proc function_template_arguments { func_template_token } {

	set tplargs_token [sub_token $func_template_token tplargs]

	return [argparenblk_arguments $func_template_token $tplargs_token]
}


##
# Return list of class template arguments
#
# Each list item is a list of name, type, default, and description.
#
proc class_template_arguments { class_template_token } {

	set tplargs_token [sub_token $class_template_token tplargs]

	return [argparenblk_arguments $class_template_token $tplargs_token]
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
			set ret_desc [to_title $desc] } }

	#
	# If not \return annotation was found, look if the brief description
	# starts with "Return" or "Returns"
	#
	if {$ret_desc == ""} {
		set mlcomment_parts [mlcomment_parts $func_token]
		if {[llength $mlcomment_parts]} {

			set first_mlcomment_part [concat [lindex $mlcomment_parts 0]]

			if {[regexp {^Returns?\s+(.*)} $first_mlcomment_part dummy brief]} {
				set ret_desc [to_title $brief]
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
# Extract sequence of public and protected members from class or struct tokens
#
proc public_and_protected_class_members { class_token } {

	if {[tok_type $class_token] == "tplclass"} {
		set class_token [sub_token $class_token class] }

	if {[tok_type $class_token] == "tplstruct"} {
		set class_token [sub_token $class_token struct] }

	set classblock_token [sub_token $class_token classblock]

	set members_sequence {}

	foreach_sub_token [tok_text $classblock_token] plain { } prot_token {

		#
		# Capture members that appear directly in the 'struct' scope
		# where the default visibility is public
		#
		if {[tok_type $class_token] == "struct"} {
			if {[tok_type $prot_token]  == "declseq"} {
				append members_sequence [tok_text $prot_token] } }

		#
		# Capture members that appear in public and protected blocks
		#
		if {[tok_type $prot_token] == "public" ||
		    [tok_type $prot_token] == "protected"} {
			foreach_sub_token [tok_text $prot_token] plain { } token {
				if {[tok_type $token] == "declseq"} {
					append members_sequence [tok_text $token]
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
	set members_sequence [public_and_protected_class_members $class_token]
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

	set members_sequence [public_and_protected_class_members $class_token]
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


##
# Return name of namespace
#
proc namespace_name { namespace_token } {

	set namespace_name_token [sub_token $namespace_token identifier]
	set namespace_name       [tok_text $namespace_name_token]

	return $namespace_name
}


##
# Return true if token is a namespace
#
proc is_namespace { token } {

	if {[tok_type $token] == "namespace"} {
		return 1 }

	return 0
}


##
# Return list of namespace present in the header
#
proc namespaces_in_header { } {

	set result {}

	foreach_sub_token [tok_text content0] plain { } token {
		if {[is_namespace $token]} {
			lappend result [namespace_name $token]
		}
	}

	return [lsort -unique $result]
}


##
# Return sequence of namespace content for the specified namespace name
#
proc namespace_sequence { name } {

	set sequence ""
	foreach_sub_token [tok_text content0] plain { } token {
		if {[is_namespace $token] && [namespace_name $token] == $name} {
			append sequence [tok_text [sub_token $token namespaceblock]]
		}
	}

	return $sequence
}


##
# Return true if token is a type definition
#
proc is_typedef { token } {

	if {[tok_type $token] == "typedef"} { return 1 }
	return 0
}


##
# Return true if token is a typed enum
#
proc is_enum_typedef { token } {

	if {[tok_type $token] == "enum"} {

		set enum_type [sub_token $token identifier]
		if {$enum_type != ""} { return 1 }
	}
	return 0
}


##
# Return type name of typed enumeration
#
proc enum_type_name { enum_token } {

	return [unfold_token [sub_token $enum_token identifier]]
}


##
# Return true if struct or class is a mere subtype
#
# A subtype is a class definition that interits from a base class and has
# nothing else than constructors.
#
proc class_is_subtype { class_token } {

	# a subtype class must have exactly one public base class
	set base_classes [public_base_classes $class_token]
	if {[llength $base_classes] != 1} { return 0 }

	# a subtype class can have constructors but no other members
	set has_more_members_than_constructor 0
	set members_sequence [public_and_protected_class_members $class_token]
	foreach_sub_token $members_sequence plain { } token {
		if {[tok_type $token] != "constimpl"} {
			set has_more_members_than_constructor 1 }
	}
	if {$has_more_members_than_constructor} {
		return 0 }

	return 1;
}


##
# Return token of sub-type definition if token is a sub type
#
proc sub_typedef { namespace_name token } {

	#
	# Handle case where the subtype is declared in the namespace but defined in
	# the global scope (as usual).
	#
	if {[tok_type $token] == "classdecl" || [tok_type $token] == "structdecl"} {

		set class_name [unfold_token [sub_token $token "identifier"]]
		set full_name "$namespace_name\::$class_name"

		# find class definition in the global scope
		set class_token [find_class_by_name content0 $full_name]
		if {$class_token == ""} { return "" }

		if {[class_is_subtype $class_token]} {
			return $class_token }
	}

	#
	# Handle the case where the subtype is directly defined within the
	# namespace.
	#
	if {[tok_type $token] == "class" || [tok_type $token] == "struct"} {

		if {[class_is_subtype $token]} {
			return $token }
	}

	return ""
}


##
# Return list of type definitions defined in the specified token sequence
#
# Each list element has is a list of type (typedef, subtype, or enum), type
# name, type definition, and a description.
#
proc collect_types_from_sequence { namespace_name sequence } {

	set result { }
	foreach_sub_token $sequence plain { } token {

		if {[is_typedef $token]} {
			set name [unfold_token [sub_token $token typename]]
			set def  [unfold_token [sub_token $token identifier]]
			set desc [mlcomment_parts $token]
			lappend result [list "typedef" $name $def $desc]
		} elseif {[is_enum_typedef $token]} {
			set name [enum_type_name $token]
			set desc [mlcomment_parts $token]
			lappend result [list "enum" $name "" $desc]
		} else {
			set sub_typedef_token [sub_typedef $namespace_name $token]
			if {$sub_typedef_token != ""} {
				set name [class_name $sub_typedef_token]

				if {$namespace_name != "" || ![regexp {::} $name]} {
					regsub "^$namespace_name\::" $name "" name
					set def  [lindex [public_base_classes $sub_typedef_token] 0]
					set desc [mlcomment_parts $sub_typedef_token]
					lappend result [list "subtype" $name $def $desc]
				}
			}
		}
	}
	return $result
}


##
# Return token of function declaration or implementation where it is
# commented
#
proc function_specification { namespace_name token } {

	#
	# Handle case where the function template is declared in the namespace
	# but defined in the global scope (as usual).
	#
	if {[tok_type $token] == "tplfuncdecl"} {

		set func_name [function_name $token]
		set full_name "$namespace_name\::$func_name"

		# find implementation in the global scope
		set funcimpl_token [find_func_by_name content0 $full_name]

		if {$funcimpl_token != ""} {
			return $funcimpl_token }
	}

	return $token
}


##
# Return list of function tokens referred to by the specified token sequence
#
proc collect_functions_from_sequence { namespace_name sequence } {

	set result { }
	foreach_sub_token $sequence plain { } token {

		if {[is_function $token]} {
			lappend result [function_specification $namespace_name $token]
		}
	}
	return $result
}


proc namespace_types { namespace_name } {

	return [collect_types_from_sequence $namespace_name [namespace_sequence $namespace_name]]
}


proc namespace_functions { namespace_name } {

	return [collect_functions_from_sequence $namespace_name [namespace_sequence $namespace_name]]
}


proc global_types { } {

	return [collect_types_from_sequence "" [tok_text content0]]
}
