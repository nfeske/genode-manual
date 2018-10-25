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

GENERATED_IMGS_LOG := $(wildcard img/*.log)
GENERATED_IMGS     := $(GENERATED_IMGS_LOG:.log=)

clean_generated_imgs:
	rm -f $(foreach suffix,.png .log .tikz .aux,$(addsuffix $(suffix),$(GENERATED_IMGS)))

clean: clean_generated_imgs
