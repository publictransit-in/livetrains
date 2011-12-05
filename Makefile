COFFEE = coffee
SASS = sass
PROCESSOR = ./src/processor.py

GENERATED_JS = public/js/livetrains.js
GENERATED_CSS = public/css/style.css
GENERATED_GEOJSON = data/mrts.geojson
GTFS_PATH = data/gtfs/

all: $(GENERATED_JS) $(GENERATED_CSS) $(GENERATED_GEOJSON)

public/js/%.js: src/%.coffee
	$(COFFEE) -o public/js/ -c $<

public/css/%.css: src/%.scss
	$(SASS) $< $@

data/%.geojson: data/%.gpx
	$(PROCESSOR) $< $(GTFS_PATH) $@

clean:
	rm -f $(GENERATED_CSS) $(GENERATED_JS) $(GENERATED_GEOJSON)

.PHONY: all clean
