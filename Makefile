MODULE_big = pgtemporal
EXTENSION = pgtemporal
EXTENSION_VERSION = 0.0.1
DATA = $(EXTENSION)--$(EXTENSION_VERSION).sql
# REGRESS = $(EXTENSION)_test
REGRESS = completely_covers_test
OBJS = pgtemporal.o completely_covers.o $(WIN32RES)

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

README.html: README.md
	jq --slurp --raw-input '{"text": "\(.)", "mode": "markdown"}' < README.md | curl --data @- https://api.github.com/markdown > README.html

release:
	git archive --format zip --prefix=$(EXTENSION)-$(EXTENSION_VERSION)/ --output $(EXTENSION)-$(EXTENSION_VERSION).zip master

.PHONY: release

