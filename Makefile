MODULE_big = time_for_keys
EXTENSION = time_for_keys
EXTENSION_VERSION = 0.0.1
DATA = $(EXTENSION)--$(EXTENSION_VERSION).sql
REGRESS = init \
					completely_covers_test \
					create_temporal_foreign_key_test \
					delete_pk_test \
					update_pk_test \
					insert_fk_test \
					update_fk_test \
					ddl_test
OBJS = time_for_keys.o completely_covers.o $(WIN32RES)

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

README.html: README.md
	jq --slurp --raw-input '{"text": "\(.)", "mode": "markdown"}' < README.md | curl --data @- https://api.github.com/markdown > README.html

release:
	git archive --format zip --prefix=$(EXTENSION)-$(EXTENSION_VERSION)/ --output $(EXTENSION)-$(EXTENSION_VERSION).zip master

.PHONY: release

