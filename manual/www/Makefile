SHELL := bash

PWD := $(shell pwd)

CHAPTERS := introduction \
            getting_started \
            architecture \
            components \
            development \
            system_configuration \
            under_the_hood \
            functional_specification

REPO_URL := https://github.com/genodelabs/genode/blob/19.05

# return list of sections for given basename of chapter
sections = $(shell ./splitter/filter-sec.sh list < ../$1.txt)

#
# Disarm the section-list parsing whenever the Makefile is invoked by
# epub_html.gosh for creating a png image.
#
ifneq ($(filter %.png,$(MAKECMDGOALS)),)
sections =
endif

# return Nth path element
second_elem = $(word 2,$(subst /, ,$1))
third_elem  = $(word 3,$(subst /, ,$1))

# populate 'SECTIONS(i)' variables, using the chapter as index
$(foreach C,$(CHAPTERS),$(eval SECTIONS($C) := $(call sections,$C)))

ALL_SECTIONS := $(foreach C,$(CHAPTERS),\
                   $(foreach S,${SECTIONS($C)},\
                      $C/$S))

ALL_SECTIONS_TXT  := $(addprefix sections/,$(addsuffix .txt,$(ALL_SECTIONS)))
ALL_CHAPTERS_TXT  := $(addprefix chapters/,$(addsuffix .txt,$(CHAPTERS)))
ALL_SECTIONS_HTML := $(addprefix html/,$(addsuffix .html,$(ALL_SECTIONS)))
ALL_CHAPTERS_INDEX_HTML := $(addprefix html/,$(addsuffix /index.html,$(CHAPTERS)))
ALL_HTML := $(ALL_SECTIONS_HTML) $(ALL_CHAPTERS_INDEX_HTML) html/index.html

# gosh arguments used for all html documents
GOSH_DOC_ARGS :=  --style ../epub/epub_html \
                  --web-build \
                  --html-xrefs xrefs \
                  --code-refs class_index \
                  --repo-url $(REPO_URL) \
                  --stylesheet style.css

default: html/style.css html/bg_pattern.png $(ALL_HTML)

#
# Create img directory before generating html documents to allow epub_html.gosh
# to create the individual images as side effects of creating the html
# documents.
#
IMG_DIR_CONTENT := Makefile \
                   tikz-common.tex tikz-preamble.tex tikz-standalone.tex \
                   qt_avplay_screen.png

$(ALL_HTML): $(addprefix img/,$(IMG_DIR_CONTENT))
$(addprefix img/,$(IMG_DIR_CONTENT)):
	mkdir -p img
	ln -sf ../../img/$(notdir $@) $@

# generate cross-reference index
xrefs: $(ALL_SECTIONS_TXT) $(ALL_CHAPTERS_TXT)
	( $(foreach C,$(CHAPTERS),\
	    gosh --style html_xrefs --html-path '$C/index.html' \
	         'chapters/$C.txt'; \
	    $(foreach S,${SECTIONS($C)},\
	      gosh --style html_xrefs --html-path '$C/$S.html' \
	           'sections/$C/$S.txt' | grep -v FAKE-CHAPTER; )) \
	) | sed -E 's/ (chapter|section) ([^ #]+)#[^ ]*$$/ \1 \2/' > $@

# generate class index based on the existing ../spec/class_index.mk
ifeq ($(wildcard ../spec/class_index.mk),)
$(error please create class index via 'make class_index.mk' in the spec/ directory)
endif

include ../spec/class_index.mk

class_index: ../spec/class_index.mk
	@( $(foreach class,$(CLASSES),\
		echo '$(class) $(CLASS_HEADER($(class))) $(CLASS_NAME($(class)))';) \
	) > $@

# install images generated during the creation of the html documents
default: html/img
html/img: $(ALL_HTML)
.PHONY: html/img
html/img:
	mkdir -p $@
	cp img/*.png $@

# install CSS file
html/style.css: style.css
	mkdir -p $(dir $@)
	cp $< $@

# install background image
html/bg_pattern.png: bg_pattern.png
	mkdir -p $(dir $@)
	cp $< $@

#
# Main index.html file
#

html/index.html : xrefs
	mkdir -p $(dir $@)
	gosh $(GOSH_DOC_ARGS) --main-index <(echo '') > $@

#
# Chapter index.html files
#

# rule to extract only the intro of a chapter
chapters/%.txt:
	mkdir -p $(dir $@)
	./splitter/filter-sec.sh chapter < ../$*.txt > $@

# let each chapter index.html file depend from its corresponding chapter text
$(foreach C,$(CHAPTERS),$(eval html/$C/index.html : ../$C.txt))

# rule to generate index.html for a chapter
$(ALL_CHAPTERS_INDEX_HTML) : xrefs
	mkdir -p $(dir $@)
	gosh $(GOSH_DOC_ARGS) \
	     --basepath "../" --unique-name '$(call second_elem,$@)' \
	     'chapters/$(call second_elem,$@).txt' > '$@'

#
# Sections
#

# let each section text depend on its original chapter text
$(foreach C,$(CHAPTERS),\
   $(eval $(addprefix sections/$C/,$(addsuffix .txt,${SECTIONS($C)})) : ../$C.txt))

# rule to extract a section txt from a chapter,
# called with the pattern '<chapter>/<section>'
sections/%.txt:
	mkdir -p $(dir $@)
	./splitter/filter-sec.sh get '$(notdir $*)' \
	                          < ../$(firstword $(subst /, ,$*)).txt \
	                          > '$@'

# let each section HTML file depend from its corresponding section text
$(foreach S,$(ALL_SECTIONS),$(eval html/$S.html : sections/$S.txt))

# rule to generate HTML from a section txt
$(ALL_SECTIONS_HTML) : xrefs
	mkdir -p $(dir $@)
	chapter='$(call second_elem,$@)'; \
	section='$(call third_elem,$(basename $@))'; \
	gosh $(GOSH_DOC_ARGS) \
	     --basepath "../" --unique-name "$$section" \
	     --style ./splitter/skip-chapter.gosh \
	     "sections/$$chapter/$$section.txt" > '$@'

include ../epub/img.mk

clean:
	rm -rf sections chapters html xrefs img
