COFFEE = coffee
PROCESSOR = ./src/processor.py

GENERATED_JS = public/js/livetrains.js
GENERATED_GEOJSON = data/mrts.geojson
CSS = public/css/style.css
GTFS_PATH = data/gtfs/

all: $(GENERATED_JS) $(GENERATED_GEOJSON) $(CSS)

public/js/%.js: src/%.coffee
	$(COFFEE) -o public/js/ -c $<

data/%.geojson: data/%.gpx
	$(PROCESSOR) $< $(GTFS_PATH) $@

public/css/%.css: src/%.css
	cp $< $@

clean:
	rm -f $(GENERATED_JS) $(CSS) $(GENERATED_GEOJSON)

.PHONY: all clean
