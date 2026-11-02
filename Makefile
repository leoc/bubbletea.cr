GO ?= go
CRYSTAL ?= crystal
LIB := go/build/libbubbletea_go.so
GO_SOURCES := $(wildcard go/*.go) go/go.mod go/go.sum

.PHONY: lib spec examples clean

lib: $(LIB)

$(LIB): $(GO_SOURCES)
	@if command -v $(GO) >/dev/null 2>&1; then \
	  cd go && CGO_ENABLED=1 $(GO) build -buildmode=c-shared \
	    -ldflags "-s -w -extldflags -Wl,-soname,libbubbletea_go.so" \
	    -o build/libbubbletea_go.so . ; \
	else \
	  echo "bubbletea: Go not found, skipping libbubbletea_go build." >&2; \
	  echo "bubbletea: set BUBBLETEA_LIB_DIR to a directory with libbubbletea_go.so (e.g. from the Nix flake)." >&2; \
	fi

spec: lib
	$(CRYSTAL) spec

examples: lib
	@mkdir -p bin
	@for f in examples/*.cr; do \
	  echo "build $$f"; $(CRYSTAL) build $$f -o bin/$$(basename $$f .cr) || exit 1; \
	done

clean:
	rm -rf go/build bin
