all: manual.pdf

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
getting_started
architecture
components
development
system_configuration
functional_specification
under_the_hood
endef

default: manual.pdf

# concatenate chapters except for those that are commented out
manual.txt: $(addsuffix .txt,$(patsubst #%,,$(strip $(CHAPTERS))))
	cat $^ > $@

manual.pdf: manual.txt manual.gosh Makefile \
       $(wildcard img/*.pdf) \
       $(wildcard img/*.tikz) \
       spec/repos spec/classes
	gosh --style manual.gosh manual.txt > $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	cp $(TEXFILE).pdf $@
	rm -f $(TEXFILE) $(TEXFILE).*

clean_manual:
	rm -f $(TEXFILE) $(TEXFILE).* manual.txt manual.pdf

spec/repos spec/classes:
	make -C spec all

clean_spec:
	make -C spec clean

clean: clean_manual clean_spec

