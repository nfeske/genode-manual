GENODE_VERSION = 25.05
PDF = genode-foundations-$(subst .,-,$(GENODE_VERSION)).pdf

all: $(PDF)

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
api
endef

default: $(PDF)

# concatenate chapters except for those that are commented out
$(PDF:.pdf=.txt): $(addsuffix .txt,$(patsubst #%,,$(strip $(CHAPTERS))))
	cat $^ > $@

$(PDF): $(PDF:.pdf=.txt) manual.gosh Makefile \
       $(wildcard img/*.pdf) \
       $(wildcard img/*.tikz) \
       spec/repos spec/classes
	gosh --style manual.gosh $(PDF:.pdf=.txt) > $(TEXFILE).tex
	lualatex $(TEXFILE).tex
	lualatex $(TEXFILE).tex
	lualatex $(TEXFILE).tex
	cp $(TEXFILE).pdf $@
	rm -f $(TEXFILE) $(TEXFILE).*

$(PDF): img

img:
	ln -sf ../img

clean_manual:
	rm -f $(TEXFILE) $(TEXFILE).* $(PDF:.pdf=.txt) $(PDF)
	rm -f img

spec/repos spec/classes:
	make -C spec all

clean_spec:
	make -C spec clean

clean: clean_manual clean_spec

