SHELL := bash

default:
	@echo Create PDF from individual Tikz image
	@echo -e "\nusage: make <name.pdf>\n"


invoke_pdflatex = lualatex -jobname $* \
                    "\input{tikz-standalone.tex} \input{$<} \end{document}"

%.pdf: %.tikz
	$(invoke_pdflatex)
	$(invoke_pdflatex)
	$(invoke_pdflatex)

flyer.pdf: flyer.tex
	lualatex $<
	lualatex $<
	lualatex $<

flyer.pdf: app_specific_tcb.pdf


#
# Make each target depend on common included files and the Makefile
#
TIKZ_FILES := $(wildcard *.tikz)
PDF_FILES  := $(TIKZ_FILES:.tikz=.pdf)

$(PDF_FILES): tikz-common.tex tikz-preamble.tex tikz-standalone.tex Makefile
