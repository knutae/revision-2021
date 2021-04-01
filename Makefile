
CC = clang
CFLAGS = -fno-plt -fno-unwind-tables -Wall -Werror -Oz
CFLAGS += $(shell pkg-config --cflags gtk+-3.0)

LIBS = -lGL -lgtk-3 -lgdk-3 -lgobject-2.0
DEBUG_LIBS = -lGL $(shell pkg-config --libs gtk+-3.0)

XZ = xz -c -9e --format=lzma --lzma1=preset=9,lc=0,lp=0,pb=0
SSTRIP = ./ELFkickers/bin/sstrip
SHADER_MINIFIER = ./Shader_Minifier/shader_minifier.exe

EXE = bin/main-4k
DEBUG_EXE = bin/main-debug

all: $(EXE)

run: $(EXE)
	./$(EXE)

debug: $(DEBUG_EXE)
	./$(DEBUG_EXE)

clean:
	rm -rf bin/ obj/ gen/

$(SSTRIP):
	cd ELFkickers; make

$(SHADER_MINIFIER):
	cd Shader_Minifier; TERM=xterm ./compile.bash

gen/%.glsl: %.glsl
	@mkdir -p gen
	unifdef -x2 -DNDEBUG -o $@ $<

gen/shaders.h: gen/fshader.glsl $(SHADER_MINIFIER)
	@mkdir -p gen
	TERM=xterm mono $(SHADER_MINIFIER) --preserve-externals $< -o $@

obj/%.o: %.c gen/shaders.h
	@mkdir -p obj
	$(CC) -c $(CFLAGS) -o $@ $<

obj/%-debug.o: %.c
	@mkdir -p obj
	$(CC) -c $(CFLAGS) -DDEBUG -o $@ $<

bin/%: obj/%.o $(SSTRIP)
	@mkdir -p bin
	#$(CC) -o $@ $^ $(LIBS)
	ld \
		-z norelro \
		-z nodelete \
		-z noseparate-code \
		-O1 \
		--orphan-handling=discard \
		--as-needed \
		--no-demangle \
		--gc-sections \
		--hash-style=gnu \
		--no-eh-frame-hdr \
		--no-ld-generated-unwind-info \
		-m elf_x86_64 \
		-dynamic-linker \
		/lib64/ld-linux-x86-64.so.2 \
		-o $@ \
		$< \
		$(LIBS)
	$(SSTRIP) $@

bin/%-debug: obj/%-debug.o
	@mkdir -p bin
	$(CC) -o $@ $^ $(DEBUG_LIBS)

%.xz: %
	cat $^ | $(XZ) > $@

%-4k: uncompress-header %.xz
	cat $^ > $@
	chmod a+x $@
	@stat --printf="$@: %s bytes\n" $@
