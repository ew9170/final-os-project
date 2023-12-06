#
# SCCS ID: @(#)Makefile	2.3	3/16/23
#
# Makefile to control the compiling, assembling and linking of standalone
# programs in the DSL.  Used for both individual interrupt handling
# assignments and the SP baseline OS (with appropriate tweaking).
#

#
# Application files
#

APP_C_SRC = main.c
APP_C_OBJ = main.o

APP_S_SRC =
APP_S_OBJ =

APP_LIBS =

APP_SRCS = $(APP_C_SRC) $(APP_S_SRC)
APP_OBJS = $(APP_C_OBJ) $(APP_S_OBJ)

#
# Framework files
#

FMK_S_SRC = startup.S isr_stubs.S libs.S
FMK_S_OBJ = startup.o isr_stubs.o libs.o

FMK_C_SRC = cio.c libc.c support.c
FMK_C_OBJ = cio.o libc.o support.o

BOOT_SRC = bootstrap.S
BOOT_OBJ = bootstrap.o

FMK_SRCS = $(FMK_S_SRC) $(FMK_C_SRC)
FMK_OBJS = $(FMK_S_OBJ) $(FMK_C_OBJ)

# Collections of files

OBJECTS = $(FMK_OBJS) $(APP_OBJS)

SOURCES = $(BOOT_SRC) $(FMK_SRCS) $(APP_SRCS)

#
# Compilation/assembly definable options
#
# General options:
#	CLEAR_BSS		include code to clear all BSS space
#	GET_MMAP		get BIOS memory map via int 0x15 0xE820
#	SP_CONFIG		enable SP OS-specific startup variations
#
# Debugging options:
#	RPT_INT_UNEXP		report any 'unexpected' interrupts
#	RPT_INT_MYSTERY		report interrupt 0x27 specifically
#	TRACE_CX		include context restore trace code
#	TRACE=n			enable general internal tracing options
#

GEN_OPTIONS = -DCLEAR_BSS
DBG_OPTIONS = -DTRACE_CX

USER_OPTIONS = $(GEN_OPTIONS) $(DBG_OPTIONS)

#
# YOU SHOULD NOT NEED TO CHANGE ANYTHING BELOW THIS POINT!!!
#
# Compilation/assembly control
#

#
# We only want to include from the current directory and ~wrc/include
#
INCLUDES = -I. -I/home/fac/wrc/include

#
# Compilation/assembly/linking commands and options
#
CPP = cpp
CPPFLAGS = $(USER_OPTIONS) -nostdinc $(INCLUDES)

#
# Compiler/assembler/etc. settings for 32-bit binaries
#
CC = gcc
CFLAGS = -m32 -fno-pie -std=c99 -fno-stack-protector -fno-builtin -Wall -Wstrict-prototypes $(CPPFLAGS)

AS = as
ASFLAGS = --32

LD = ld
LDFLAGS = -melf_i386 -no-pie

#
# QEMU definitions and options
#

# the basic command
QEMU = /home/course/csci352/bin/qemu-system-i386

# standard options
# QEMUOPTS = -drive file=disk.img,index=0,media=disk,format=raw -m 512
QEMUOPTS = -drive file=disk.img,index=0,media=disk,format=raw

# generate a unique GDB port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)

# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)

#		
# Transformation rules - these ensure that all compilation
# flags that are necessary are specified
#
# Note use of 'cpp' to convert .S files to temporary .s files: this allows
# use of #include/#define/#ifdef statements. However, the line numbers of
# error messages reflect the .s file rather than the original .S file. 
# (If the .s file already exists before a .S file is assembled, then
# the temporary .s file is not deleted.  This is useful for figuring
# out the line numbers of error messages, but take care not to accidentally
# start fixing things by editing the .s file.)
#
# The .c.X rule produces a .X file which contains the original C source
# code from the file being compiled mixed in with the generated
# assembly language code.  Very helpful when you need to figure out
# exactly what C statement generated which assembly statements!
#

.SUFFIXES:	.S .b .X

.c.X:
	$(CC) $(CFLAGS) -g -c -Wa,-adhln $*.c > $*.X

.c.s:
	$(CC) $(CFLAGS) -S $*.c

.S.s:
	$(CPP) $(CPPFLAGS) -o $*.s $*.S

.S.o:
	$(CPP) $(CPPFLAGS) -o $*.s $*.S
	$(AS) $(ASFLAGS) -o $*.o $*.s -a=$*.lst
	$(RM) -f $*.s

.s.b:
	$(AS) $(ASFLAGS) -o $*.o $*.s -a=$*.lst
	$(LD) $(LDFLAGS) -Ttext 0x0 -s --oformat binary -e begtext -o $*.b $*.o

.c.o:
	$(CC) $(CFLAGS) -c $*.c

#
# Targets for remaking bootable image of the program
#
# Default target:  disk.img
#

disk.img: bootstrap.b prog.b prog.nl BuildImage prog.dis 
	./BuildImage -d usb -o disk.img -b bootstrap.b prog.b 0x10000

floppy.img: bootstrap.b prog.b prog.nl BuildImage prog.dis 
	./BuildImage -d floppy -o floppy.img -b bootstrap.b prog.b 0x10000

prog.out: $(OBJECTS)
	$(LD) $(LDFLAGS) -o prog.out $(OBJECTS)

prog.o:	$(OBJECTS)
	$(LD) $(LDFLAGS) -o prog.o -Ttext 0x10000 $(OBJECTS) $(A_LIBS)

prog.b:	prog.o
	$(LD) $(LDFLAGS) -o prog.b -s --oformat binary -Ttext 0x10000 prog.o

#
# Targets for copying bootable image onto boot devices
#

floppy:	floppy.img
	dd if=floppy.img of=/dev/fd0

usb:	disk.img
	/usr/local/dcs/bin/dcopy disk.img

#
# Special rule for creating the modification and offset programs
#
# These are required because we don't want to use the same options
# as for the standalone binaries.
#

BuildImage:	BuildImage.c
	$(CC) -o BuildImage BuildImage.c

Offsets:	Offsets.c
	$(CC) -mx32 -std=c99 $(INCLUDES) -o Offsets Offsets.c

#
# Targets for running with QEMU
#

qemu:	disk.img
	$(QEMU) -serial mon:stdio $(QEMUOPTS)

qemu-nox:	disk.img
	$(QEMU) -nographic $(QEMUOPTS)

.gdbinit:	gdbinit.tmpl
	sed "s/localhost:1234/localhost:$(GDBPORT)/" < $^ > $@

qemu-gdb:	disk.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -serial mon:stdio $(QEMUOPTS) -S $(QEMUGDB)

qemu-nox-gdb:	disk.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -nographic $(QEMUOPTS) -S $(QEMUGDB)
#
# Clean out this directory
#

clean:
	rm -f *.nl *.nll *.lst *.b *.o *.X *.dis

realclean:	clean
	rm -f *.img BuildImage Offsets

#
# Create a printable namelist from the prog.o file
#

prog.nl: prog.o
	nm -Bng prog.o | pr -w80 -3 > prog.nl

prog.nll: prog.o
	nm -Bn prog.o | pr -w80 -3 > prog.nll

#
# Generate a disassembly
#

prog.dis: prog.o
	objdump -d prog.o > prog.dis

#
# 'makedepend' is a program which creates dependency lists by looking
# at the #include lines in the source files.
#

depend:
	makedepend $(INCLUDES) $(SOURCES)

# DO NOT DELETE THIS LINE -- make depend depends on it.

