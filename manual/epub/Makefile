TARGET_EPUB := genode-foundations-18.05.epub

SHELL := bash

HTML := introduction.html \
        getting_started.html \
        architecture.html \
        components.html \
        development.html \
        system_configuration.html \
        under_the_hood.html

default: $(TARGET_EPUB)

%.html: ../%.txt
	gosh --style epub_html.gosh --html-xrefs xrefs $< > $@

$(HTML): xrefs

#
# Rules for converting TikZ figures to PNG images, invoked by 'epub_html.gosh'
#

img/%.tikz: ../img/%.tikz
	cd img; ln -s ../../img/$*.tikz

img/%.pdf: img/%.tikz
	make -C img $*.pdf

GS_DPI := 200

img/%-unscaled.png: img/%.pdf
	gs -dNOPAUSE -dBATCH -sDEVICE=pngalpha -r$(GS_DPI) -sOutputFile=$@ $<

img/%.png: img/%-unscaled.png
	convert -filter lanczos -resize 80% $< $@

#
# Rules for generating the table of contents
#

gen_toc_for_chapter = gosh --style epub_toc --toc-html-file $2.html ../$2.txt

.PHONY: toc.ncx

toc.ncx:
	cat toc.ncx.head > $@
	echo " <navMap>" >> $@
	$(call gen_toc_for_chapter,100,introduction) >> $@
	$(call gen_toc_for_chapter,200,getting_started) >> $@
	$(call gen_toc_for_chapter,300,architecture) >> $@
	$(call gen_toc_for_chapter,400,components) >> $@
	$(call gen_toc_for_chapter,500,development) >> $@
	$(call gen_toc_for_chapter,600,system_configuration) >> $@
	$(call gen_toc_for_chapter,700,under_the_hood) >> $@
	echo " </navMap>" >> $@
	echo "</ncx>" >> $@
	./finalize_toc > toc.ncx.final
	mv toc.ncx.final $@

#
# Rules for generating cross-reference database
#

gen_xrefs_for_chapter = gosh --style html_xrefs --html-path $1.html ../$1.txt

.PHONY: xrefs

xrefs:
	rm -f $@
	$(call gen_xrefs_for_chapter,introduction) > $@
	$(call gen_xrefs_for_chapter,getting_started) >> $@
	$(call gen_xrefs_for_chapter,architecture) >> $@
	$(call gen_xrefs_for_chapter,components) >> $@
	$(call gen_xrefs_for_chapter,development) >> $@
	$(call gen_xrefs_for_chapter,system_configuration) >> $@
	$(call gen_xrefs_for_chapter,under_the_hood) >> $@

#
# Rules for generating the EPUB archive
#

EPUB_SRC := META-INF/container.xml content.opf mimetype toc.ncx

$(TARGET_EPUB): $(HTML) $(EPUB_SRC) Makefile
	rm -f $(TARGET_EPUB)
	zip -X0    $(TARGET_EPUB) mimetype
	zip -Xur9D $(TARGET_EPUB) $(HTML) $(EPUB_SRC) img/*.png

#
# Clean rules
#

GENERATED_IMGS_LOG := $(wildcard img/*.log)
GENERATED_IMGS     := $(GENERATED_IMGS_LOG:.log=)

clean_generated_imgs:
	rm -f $(foreach suffix,.png .log .tikz .aux,$(addsuffix $(suffix),$(GENERATED_IMGS)))

clean: clean_generated_imgs
	rm -f $(HTML)
	rm -f $(TARGET_EPUB)
	rm -f toc.ncx

