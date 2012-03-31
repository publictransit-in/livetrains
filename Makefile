COFFEE = coffee
PROCESSOR = ./src/processor.py

GENERATED_JS = public/js/livetrains.js
GENERATED_JSON = public/mrts.json
GENERATED_GEOJSON = data/mrts.geojson
CSS = public/css/style.css
GTFS_PATH = data/gtfs/

all: $(GENERATED_JS) $(GENERATED_JSON) $(CSS)

public/js/%.js: src/%.coffee
	$(COFFEE) -o public/js/ -c $<

data/%.geojson: data/%.gpx
	$(PROCESSOR) $< $(GTFS_PATH) $@

public/css/%.css: src/%.css
	mkdir -p $(basename $@)
	cp $< $@

public/%.json: data/%.geojson
	mkdir -p $(basename $@)
	cp $< $@

clean:
	rm -f $(GENERATED_JS) $(CSS) $(GENERATED_GEOJSON)

.PHONY: all clean
