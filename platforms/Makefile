GENODE_VERSION = 21.05
PDF = genode-platforms-$(subst .,-,$(GENODE_VERSION)).pdf

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
intro
porting_guide
preparations
warmup
serial
kernel_skeleton
debugging
user_land
device_access
platform_driver
dts_pruning
dde_linux
endef

default: $(PDF)

$(PDF): manual.gosh
	ln -s ../foundations

# concatenate chapters except for those that are commented out
$(PDF:.pdf=.txt): $(addsuffix .txt,$(patsubst #%,,$(strip $(CHAPTERS))))
	cat $^ > $@

$(PDF): $(PDF:.pdf=.txt) manual.gosh Makefile \
       $(wildcard img/*.pdf) \
       $(wildcard img/*.tikz)
	gosh --style manual.gosh $(PDF:.pdf=.txt) > $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	pdflatex $(TEXFILE).tex
	cp $(TEXFILE).pdf $@
	rm -f $(TEXFILE) $(TEXFILE).*

$(PDF): img

img:
	ln -sf ../img

clean_manual:
	rm -f $(TEXFILE) $(TEXFILE).* $(PDF:.pdf=.txt) $(PDF)
	rm -f img

clean: clean_manual

