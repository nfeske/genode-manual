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
# Rules for generating HTML files sectionwise
#
.PHONY: splitted

presuf = $(addprefix $(2),$(addsuffix $(3),$(1)))
html_files = $(call presuf,$(1),splitted_html/,.html)
txt_files = $(call presuf,$(1),splitted_txt/,.txt)

chapters := $(basename $(HTML))
chapter_txt_dirs := $(addprefix splitted_txt/,$(chapters))
chapter_html_dirs := $(addprefix splitted_html/,$(chapters))

sectionlists := $(call presuf,$(chapters),splitted_txt/,.txt)
all_sections := $(foreach x,$(chapters), \
	$(addprefix $(x)/,$(file <splitted_txt/$(x).txt)))
sections_txt := $(call txt_files,$(all_sections))
sections_html := $(call html_files,$(all_sections))

chapter_indizes := $(addsuffix /index,$(chapters))
chapter_indizes_txt := $(call txt_files,$(chapter_indizes))
chapter_indizes_html := $(call html_files,$(chapter_indizes))

content_sorted := $(foreach x,$(chapters), \
	$(addprefix $(x)/,index $(file <splitted_txt/$(x).txt)))
splitted_all := $(sections_html) $(chapter_indizes_html) \
	splitted_html/index.html

define multi_gen_xrefs_splitted =
docs='$(1)'; \
for doc in $$docs; do \
	gosh --style html_xrefs --html-path splitted_html/$$doc.html \
		splitted_txt/$$doc.txt | grep -v FAKE-CHAPTER >> splitted_xrefs ; \
done;
endef
#$1: gosh doc, $2: html doc, $3: basepath, $4 extra args
#Note that some sections have special characters in their names. So add single
#quotes to $1 and $2 when necessary.
gen_html = gosh --style epub_html --html-xrefs splitted_xrefs --web-build \
	--stylesheet style.css $(4) --basepath $(3) $(1) > $(2)

splitted: $(splitted_all)

splitted_html/index.html: splitted_xrefs | splitted_html
	$(call gen_html,<(echo ''),$@,..,--main-index)

skip_chapter := --style splitter/skip-chapter.gosh
$(sections_html): splitted_xrefs | $(chapter_html_dirs)
	$(call gen_html, \
		'$(patsubst splitted_html/%.html,splitted_txt/%.txt,$@)', \
		'$@', \
		../.., \
		$(skip_chapter) --unique-name '$(notdir $(basename $@))')

splitted_html/%/index.html: splitted_txt/%/index.txt splitted_xrefs | splitted_html
	@#here we make use of the original chapter file naming, see epub_html.gosh
	$(call gen_html,'$<','$@',../..,--unique-name '$*')

#We do not put this xrefs file into the 'splitted_txt' directory because gosh
#does not allow '--html-xrefs' argument values with slashes.
splitted_xrefs: splitted_txt/sectionlists_update $(sections_txt) \
		$(chapter_indizes_txt) | $(chapter_txt_dirs)
	-rm splitted_xrefs
	@#The correct order of the xrefs entries is important for the generation of
	@#the navigation elements.
	$(call multi_gen_xrefs_splitted,$(content_sorted))
	@#Remove anchors from links to the first headline of a document. So the first
	@#visible element is the navigation bar instead of the headline. This should
	@#make navigating through the doc's more comfortable.
	sed -E -i 's/ (chapter|section) ([^ #]+)#[^ ]*$$/ \1 \2/' $@

splitted_txt/%.txt: ../%.txt | splitted_txt
	splitter/filter-sec.sh list < $< > $@

$(sections_txt): splitted_txt/sectionlists_update | $(chapter_txt_dirs)
	splitter/filter-sec.sh get '$(notdir $(basename $@))' \
		< ../$(patsubst splitted_txt/%/,%,$(dir $@)).txt \
		> '$@'

splitted_txt/%/index.txt: ../%.txt | $(chapter_txt_dirs)
	splitter/filter-sec.sh chapter < $< > $@

$(chapter_txt_dirs): | splitted_txt
$(chapter_html_dirs): | splitted_html
splitted_html splitted_txt $(chapter_txt_dirs) $(chapter_html_dirs):
	mkdir $@


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

concrete_cleaning_targets := clean_generated_imgs clean_splitted

clean_generated_imgs:
	rm -f $(foreach suffix,.png .log .tikz .aux,$(addsuffix $(suffix),$(GENERATED_IMGS)))

clean_splitted:
	rm -f -r splitted_html splitted_txt
	rm -f splitted_xrefs

clean: $(concrete_cleaning_targets)
	rm -f $(HTML)
	rm -f $(TARGET_EPUB)
	rm -f toc.ncx

#
# Reload Makefile if necessary
#

#The elements of the generated section lists are used as prerequisites.
splitted_txt/sectionlists_update: $(sectionlists)
	touch splitted_txt/sectionlists_update

#avoid generation of Makefiles caused by includes if user just wants to clean
#TODO: this does not prevent the generation under the following conditions:
# * User supplies both cleaning and building goals. I do not know the correct
#   behaviour for such a situation.
# * User supplies one of the "normal" epub goals.
cleaning_goals := $(filter $(concrete_cleaning_targets) clean,$(MAKECMDGOALS))
ifeq ($(cleaning_goals),)
include splitted_txt/sectionlists_update
endif
