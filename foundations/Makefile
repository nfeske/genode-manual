GENODE_VERSION = 19.05
FOUNDATIONS_PDF = genode-foundations-$(subst .,-,$(GENODE_VERSION)).pdf

all: $(FOUNDATIONS_PDF)

TEXFILE := misc.tmp
SHELL = bash

#
# Definition of the order of chapters
#
# Lines can be commented-out by prefixing them with '#'.
#
define CHAPTERS
title
introduction
part_1
getting_started
architecture
components
development
system_configuration
under_the_hood
part_2
functional_specification
endef

default: $(FOUNDATIONS_PDF)

# concatenate chapters except for those that are commented out
$(FOUNDATIONS_PDF:.pdf=.txt): $(addsuffix .txt,$(patsubst #%,,$(strip $(CHAPTERS))))
	cat $^ > $@

$(FOUNDATIONS_PDF): $(FOUNDATIONS_PDF:.pdf=.txt) manual.gosh Makefile \
       $(wildcard img/*.pdf) \
       $(wildcard img/*.tikz) \
       spec/repos spec/classes
	gosh --style manual.gosh $(FOUNDATIONS_PDF:.pdf=.txt) > $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	cp $(TEXFILE).pdf $@
	rm -f $(TEXFILE) $(TEXFILE).*

$(FOUNDATIONS_PDF): img

img:
	ln -sf ../img

clean_manual:
	rm -f $(TEXFILE) $(TEXFILE).* $(FOUNDATIONS_PDF:.pdf=.txt) $(FOUNDATIONS_PDF)
	rm -f img

spec/repos spec/classes:
	make -C spec all

clean_spec:
	make -C spec clean

clean: clean_manual clean_spec

