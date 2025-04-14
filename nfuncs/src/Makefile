CC = gcc
STRIP = strip
CFLAGS = -std=c11 -O2 -fno-exceptions -fno-asynchronous-unwind-tables -fno-unwind-tables -mcmodel=large -Wl,--disable-dynamicbase,--disable-high-entropy-va
# We also need -Wl,--stack,1342177280 to avoid stack overrun
OUTPUT_DIR = output
RESOURCES_DIR = resources

# Detect OS
ifeq ($(OS),Windows_NT)
    # Native Windows build
    TARGET = nfuncs.exe
    RC = windres
    RC_FLAGS = -O coff
    RESOURCE_OBJ = resources.res
else
    # Linux build with cross-compilation support
    TARGET = nfuncs.exe
    CC = x86_64-w64-mingw32-gcc
    STRIP = x86_64-w64-mingw32-strip
    RC = x86_64-w64-mingw32-windres
    RC_FLAGS = -O coff
    RESOURCE_OBJ = resources.res
endif

# Get all python files
PYTHON_FILES := $(wildcard *.py)
ENC_TEMPLATES := $(wildcard templates/tmpl*.c)
OBF_TEMPLATES := $(wildcard templates/obf*.c)

.PHONY: all clean

all: $(TARGET)

pass1: main.c flag_2.mp4 $(PYTHON_FILES) $(ENC_TEMPLATES)
	# first iteration
	python gen.py --img1 flag_1.png --img2 flag_2.mp4 --img3 flag_3.png --output output --workers $(shell nproc) --pass-idx 1
	$(CC) $(CFLAGS) -o $(TARGET) main.c $$(ls output/*.o)
	cp $(TARGET) $(TARGET).pass1.backup
	python parse_pe.py
	python update_source.py
	touch pass1

pass2: pass1 $(PYTHON_FILES) $(OBF_TEMPLATES)
	# second iteration
	python gen.py --img1 flag_1.png --img2 flag_2.mp4 --img3 flag_3.png --output output --workers $(shell nproc) --pass-idx 2
	

$(TARGET): pass2 $(RESOURCE_OBJ)
	$(CC) $(CFLAGS) -o $(TARGET) main.c $$(ls output/*.o) $(RESOURCE_OBJ)
	cp $(TARGET) $(TARGET).pass2.backup
	touch pass2
	python update_pe.py --workers $(shell nproc)
	$(STRIP) --strip-all $@

test_input:
	dd if=/dev/urandom of=flag_1.png bs=48 count=1
	dd if=/dev/urandom of=flag_2.mp4 bs=128 count=1
	# TODO: Generate flag_3.png

$(RESOURCE_OBJ): $(RESOURCES_DIR)/resources.rc $(RESOURCES_DIR)/icon.ico
	@mkdir -p $(OUTPUT_DIR)
	$(RC) $(RC_FLAGS) $< -o $@

clean:
	rm -f pass1 pass2
	rm -f output/*.o
	rm -f $(TARGET) $(RESOURCE_OBJ)
