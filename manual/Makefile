all: manual.pdf

TEXFILE := misc.tmp
SHELL = bash

#
# Definition of the order of chapters
#
# Lines can be commented-out by prefixing them with '#'.
#
define CHAPTERS
#title
#introduction
#getting_started
#architecture
#components
#development
#system_configuration
functional_specification
#spectest
#under_the_hood
endef

default: manual.pdf

# concatenate chapters except for those that are commented out
manual.txt: $(addsuffix .txt,$(patsubst #%,,$(strip $(CHAPTERS))))
	cat $^ > $@

%.pdf: %.txt manual.gosh Makefile $(wildcard img/*.pdf) $(wildcard img/*.tikz)
	gosh --style manual.gosh $< > $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	cp $(TEXFILE).pdf $@
	rm -f $(TEXFILE) $(TEXFILE).*

clean:
	rm -f $(TEXFILE) $(TEXFILE).* manual.txt manual.pdf
