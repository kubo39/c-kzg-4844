# Makefile for c-kzg-4844 D language bindings

.PHONY: all build-lib clean test example build help

# Paths
ROOT_DIR := ../..
BLST_DIR := $(ROOT_DIR)/blst
SRC_DIR := $(ROOT_DIR)/src
OUT_DIR := lib

# Compiler settings
CC ?= cc
CFLAGS = -O2 -fPIC -D__BLST_PORTABLE__
CFLAGS += -I$(BLST_DIR)/bindings -I$(SRC_DIR)

# Source files
BLST_ASM = $(BLST_DIR)/build/assembly.S
BLST_SRC = $(BLST_DIR)/src/server.c
CKZG_SRC = $(SRC_DIR)/ckzg.c

# Object files
OBJS = $(OUT_DIR)/assembly.o $(OUT_DIR)/server.o $(OUT_DIR)/ckzg.o

# Output
STATIC_LIB = $(OUT_DIR)/libckzg.a

all: build-lib

# Ensure output directory exists before building objects
$(OBJS): | $(OUT_DIR)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

# Build object files
$(OUT_DIR)/assembly.o: $(BLST_ASM)
	$(CC) $(CFLAGS) -c $< -o $@

$(OUT_DIR)/server.o: $(BLST_SRC)
	$(CC) $(CFLAGS) -c $< -o $@

$(OUT_DIR)/ckzg.o: $(CKZG_SRC)
	$(CC) $(CFLAGS) -c $< -o $@

# Build static library
build-lib: $(STATIC_LIB)

$(STATIC_LIB): $(OBJS)
	ar rcs $@ $^
	@echo "Built $(STATIC_LIB)"

# Build with DUB (requires library to be built first)
build: build-lib
	dub build

# Build example
example: build-lib
	cd example && dub build

# Run tests
test: build-lib
	dub test

clean:
	rm -rf $(OUT_DIR)
	rm -rf .dub
	cd example && rm -rf .dub example 2>/dev/null || true

help:
	@echo "Available targets:"
	@echo "  all       - Build the static library (default)"
	@echo "  build-lib - Build the static library"
	@echo "  build     - Build the D bindings with DUB"
	@echo "  example   - Build the example program"
	@echo "  test      - Run tests"
	@echo "  clean     - Remove build artifacts"
