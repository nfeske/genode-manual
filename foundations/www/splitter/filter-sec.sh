#!/bin/dash

#section filter for gosh docs
#It reads gosh doc from stdin. Results are written on stdout.
#The following modes are provided:
# * Generate gosh doc with all sections removed (mode: chapter)
# * Generate gosh doc with all but the requested section removed (mode: get)
#   * The second argument specifies the section to be extracted.
#   * Note: A dummy chapter headline is included because gosh can't read the
#     result otherwise.
# * List all sections (mode: list)
#
#Since GNU make doesn't like filenames with spaces, spaces in section names are
#replaced with _. The content of the generated gosh doc's, however, is not
#treated this way.
#
#Alternatively, we may implement these tasks within a gosh backend so that we
#don't have to re-implement the parsing code. However, gosh removes tables and
#footnotes before calling the backend's functions. So until gosh provides an
#appropriate switch option, we use this probably buggy shell filter.
#
# Additional requirements: GNU sed

err() {
	echo "$1" >&2
	exit 1
}

#return an ordered line number list of all section headlines
section_lines() {
	lister=$(cat << 'DELI'
N
#zero length lines would break the fancy length comparison, and they can't be
#headlines anyway
/^[^\n]+/ {
	#replace characters of the first line with #
	{
		#save both lines
		h
		#get first line
		s/\n.*//
		#replace it with #s for the length check
		s/./=/g
		#append both unmodified lines
		G
		#remove first, unmodified line
		s/\n.*\n/\n/
	}

	#print line number if we have a headline
	/(^[^\n]+)\n\1/ =
}
D
DELI
)
	lines=$(sed -r -n "$lister")
	for line in $lines; do
		#decr by 1, probably because of the double line reading in our sed code
		echo $(($line - 1))
	done
}

#print all lines before the $1nth line
#if $1 is an empty string, print all lines
keep_until_line() {
	if [ -n "$1" ]; then
		set -- $(($1 - 1))
	fi
	sed -n "1,${1:-\$} p"
}

get_doc() {
	printf '%s\n' "$doc"
}

do_list() {
	lister=$(get_doc | section_lines | sed 's/$/p/')
	get_doc | sed -n "$lister" | sed 's/ /_/g'
}

do_get() {
	target_line=-1
	#using a loop instead of sed magic, we avoid escaping for sed syntax
	for sec_line in $(get_doc | section_lines); do
		sec=$(get_doc | sed -n "${sec_line}p" | sed 's/ /_/g')
		if [ -1 -ne "$target_line" ]; then
			#In order to keep correct line numbers, we cut out the subsequent
			#sections first. The preceding part, however, is not cutted out within
			#this loop because the requested section may be the last one.
			doc=$(get_doc | keep_until_line "$sec_line")
			break
		elif [ "$1" = "$sec" ]; then
			target_line="$sec_line"
		fi
	done
	if [ -1 -eq "$target_line" ]; then
		err "section not found: $1"
	fi
	doc=$(get_doc | sed -n "$target_line,\$ p")

	printf '%s\n%s\n%s\n' 'FAKE-CHAPTER' \
	                      '############' \
	                      "$doc"
}

do_chapter() {
	first_sec_line=$(get_doc | section_lines | sed -n '1p')
	get_doc | keep_until_line "$first_sec_line"
}

doc=$(cat) #used only by the do_ functions and get_doc

if [ 0 -eq $# ]; then
	err "please specify one of the modes: list,get,chapter"
fi
if [ $1 = 'list' ]; then
	do_list
elif [ $1 = 'get' ]; then
	if [ 2 -ne $# ]; then
		err "please specify the section"
	fi
	do_get "$2"
elif [ $1 = 'chapter' ]; then
	do_chapter
else
	err "Invalid mode"
	exit 1
fi
