SHELL := bash

default:
	@echo Create PDF from individual Tikz image
	@echo -e "\nusage: make <name.pdf>\n"

%.pdf: %.tikz
	for i in 1 2 3; do \
	    pdflatex -jobname $* \
	             "\input{tikz-standalone.tex} \input{$<} \end{document}"; \
	done;
