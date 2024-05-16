TARGET = sculpt.pdf
SHELL  = bash

CHAPTERS_TXT := sculpt.txt

default: $(TARGET)

show: $(TARGET)
	xdg-open $(TARGET)

$(CHAPTERS_TXT:.txt=.tex): misc.gosh

%.tex: %.txt
	gosh --style misc.gosh $< > $@

%.pdf: %.tex
	pdflatex $<
	pdflatex $<
	pdflatex $<

clean cleanall:
	rm -f *.tex *~ *.aux *.log *.toc *.out *.brf *.blg *.bbl $(TARGET)
