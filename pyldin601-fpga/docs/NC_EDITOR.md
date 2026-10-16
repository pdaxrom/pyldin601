# NC text editor

F4 sends request 4 through the private `NCABI.INC` state. NCMAIN closes
its files, returns its RAMMAN lease, and terminates. The NC supervisor
restores the captured video mode and executes NCEDIT with the same state
pointer. When it returns, NC reloads NCMAIN and restores the edited file's
selection, including a new sorted window if the saved size/date moved it.

Install NC.PGM, NCMAIN.PGM and NCEDIT.PGM from the same build together.
No BIOS, UniDOS or FPGA change is required. The native INT interfaces are
the storage and memory APIs. Shift selection additionally reads the current
FPGA keyboard's ordinary-RAM E7 descriptor when its v2 raw interface, address
bounds and JMP gateway are valid. It never changes or calls the private
keyboard vector. F3 marking works with ordinary native BIOS navigation.

## Loading and memory

The delivered NCEDIT.PGM contains a small native PGM followed by an ordinary
relocatable editor PGM. The bootstrap opens its own absolute pathname,
allocates the editor with 256-byte alignment, reads the code, applies
relocations in 64-byte batches, closes the file, and jumps to the editor.
This avoids a transient low-RAM allocation for the entire relocation table
while graphics video RAM is allocated. Both allocations belong to the native
child and are released by DOS on its exit. UniLD `-b` joins the two standard
PGM files without changing either header or relocation table. This command
runs identically on the host and under native UniDOS.

After the loader jumps to the editor its first 768 bytes are reused for
the viewport character cache. The loader passes this address in A:B; its
arguments and state are consumed before any viewport write. The remaining
cache is allocated for the actual viewport: 160/200 bytes for 40-column
graphics/text, or 1120/1200 bytes for 80-column graphics/text. The bundle
validator rejects a loader smaller than the reusable area. This keeps the
editor within conventional RAM in the 601A colour graphics mode, where
video RAM reduces the available heap.

The editor uses about 25–26 KiB of ordinary RAM, including its loader, code,
viewport character cache, metadata and I/O buffers. NCEDIT.json reports the
base allocation, each viewport tail, the optional 512-byte cache slot and the
maximum total. Document length and edit count do not increase this allocation.
Three ordinary 512-byte cache slots work without RAMMAN; a fourth is allocated
when conventional memory permits. If its ABI check and allocation succeed, one leased
8 KiB bank adds sixteen slots. The lease never assumes a free physical bank
number and restores selectors around BIOS/DOS/font operations. Banked data
passes through an ordinary 512-byte bounce buffer for native DOS transfers.
The leaf-split buffer shares the Save/clipboard staging buffer: payload
staging completes before history application can split the directory. A split
can retain old/new/neighbor leaves in the three ordinary slots even without
RAMMAN.
The small three-slot fallback may perform extra I/O during far-offset edits;
the fourth ordinary slot is retained in modes with sufficient conventional RAM.

## Document and history

All logical and physical offsets, columns, lengths and history cursors are
big-endian unsigned 32-bit values. The original file is opened read-only.
Initially its sole index leaf is pinned in RAM, so merely opening a document
requires no writable workspace.

The first edit creates three unique 8.3 files in the configured work directory
(or the source directory by default):

| Extension | Contents |
|---|---|
| ADD | Appended inserted text and deleted text retained for Undo |
| IDX | Disk-backed unrolled doubly linked lists of pieces |
| UND | Fixed-size Undo/Redo records |

Each IDX leaf occupies 512 bytes. Its header contains next leaf at 0, total
logical bytes at 4, entry count at 8, and previous leaf at 12. Up to 31
sixteen-byte piece descriptors begin at 16. A descriptor contains source
offset at 0, length at 4, and source file ID at 8 (0 original, 2 ADD).
Leaf links, totals and descriptors are accessed through the shared block
cache. Splits prepare the new leaf before linking it. A retained finger
walks in either direction rather than restarting at the first leaf.

A 32-byte history record contains document position at 0; removed ADD offset
and length at 4/8; inserted ADD offset and length at 12/16; before/after
cursor offsets at 20/24; typing group and newline flags at 28/29. Consecutive
typing coalesces. A new edit after Undo replaces the redo tail. The saved
history position determines the modified marker. Pending multi-part edits
record their application phase and remaining delete length so retrying an
I/O failure does not apply completed parts twice.

## Rendering and navigation

The editor shares NC's native glyph renderer, box characters and modal input
windows. Visible logical line starts/ends and horizontal anchors are kept
in RAM. The text framebuffer cannot serve as a readable cache because ROM
is overlaid there, so characters are cached explicitly. Ordinary edits repaint
changed cells in their line and adjust subsequent cached offsets. Horizontal
movement uses known anchors; cold scans parse contiguous runs in blocks.
Tab stops are every eight columns. Vertical movement keeps a desired visual
column and chooses the position before a tab if the desired column is inside
its span. CRLF is one logical line break. Existing bytes, including NUL and
1A, remain part of the document. New lines use the first detected convention.

Native text uses the hardware caret. Graphics parks that caret and inverts
the actual native glyph at the editor position. Input dialogs own the focus
while open; restoration uses the cached viewport instead of rescanning a
long line. Forward search uses a small KMP prefix table and streams once
through the document with at most one wrap. Search and cold scans can be
cancelled between blocks. A distant jump can still require a sequential
scan; there is no permanent whole-document line index.

## Selection and session clipboard

A selection retains a 32-bit anchor byte offset and visual column, plus
normalized start/end offsets and columns. Each visible row caches only two
bytes for its selected column interval; changing a selection repaints the
cells whose appearance changes without rereading document text. The same
intervals restore modal underlays and keep the graphics caret visible inside
highlighted text. Native monochrome text lacks cell attributes, so endpoint
brackets are output separately while the character cache retains file bytes.

F3 toggles extension with native navigation. On the current FPGA PS/2 driver,
Shift navigation uses the physical Set-2 arrow to undo the native layout's
Shift-to-Home/End/page translation. Ctrl+A selects the whole document. Esc
clears selection before exiting. Ctrl+C/X/V copies, cuts or pastes; typing,
Enter, Tab, Delete or Backspace replaces a nonempty selection.

With the FPGA mouse interface, clicking positions the caret using the same
tab-aware column walker; dragging selects bytes across lines. A new click
clears the previous selection, and clicking below EOF retains the caret.
The function strip and modal buttons are clickable. Input dialogs keep their
own caret; the next keyboard input restores the document caret after a text
mouse hover. Long scans and saves poll the mouse between blocks; right-click
or the progress Cancel button cancels the operation. There is no resident
IRQ hook, and mouse resources are released before NC reloads its child.

Copy streams exactly the selected range to a unique .CLP beside the work
files. The supervisor records its pathname only after the file is closed,
then removes the previous clipboard. It retains that pathname across editor
unloads and deletes the file on final NC exit. Thus the clipboard can cross
files and exceed ordinary RAM. Failed/cancelled copies preserve the previous
clipboard. Work files and CLP names are never assumed free.
Byte edits and bulk Paste share the same ADD-sector boundary handling:
the previous sector is flushed before extending the file. This keeps native
LSEEK inside EOF regardless of the cache size or replacement hand position.

Paste stages the clipboard into ADD before mutating the document. Removed
ranges are similarly snapshotted into ADD for Undo. An arbitrary-length
replacement reuses the normal history/application phases and is one Undo
record. Large staging operations share the Save byte progress window and
check cancellation between bounded transfers. Cancellation drains repeated
Esc/Ctrl+C events until key release, so a held cancel key cannot also exit
the editor. A pending close is retried before reusing the transfer handle;
clipboard readers are never treated as disposable output files.

UniAS has a fixed symbol table. Editor builds define NC_EDITOR to include
only the ABI constants they use. Some viewport scratch fields share named
BSS regions with documented offsets to leave symbol space for block commands.
Repeated 32-bit transfers use the shared accumulator helpers, keeping code
and relocation workspace small enough for native graphics modes.

## Save and failure handling

Save streams the logical document into a unique .NEW beside the target.
Only bytes accepted by DOS contribute to progress. Once the new file is
closed, the old target is renamed to a unique .BAK and the new file is
published. A failed publication attempts to restore the original target.
The original backing version remains readable so Undo can cross Save.
On normal exit the latest previous version is retained as .BAK; an older
backing version is removed if it has been superseded by a later backup.
Work files are removed on normal exit. They are not a crash recovery format.

A failed output write leaves the original and the editing state available
for another Save or Save As. A read-only source can use a writable scratch
directory and Save As to another drive. A full target can likewise be bypassed
with Save As if the work disk still has space. An I/O failure during a partially
applied edit offers retry, or an explicit discard-and-close action.

## Verification

`make test-nc` runs the panels regression and editor matrix;
`make test-nc-editor` runs the editor matrix separately. Both use private image
copies and the actual BIOS, UniDOS and assembled relocatable applications
under the project's MC6800/HD6303 reference harness. They do not access the
physical board, physical card or modify `images/sd.img`.

The editor matrix covers all supported model/video/CPU combinations, banked
cache and ordinary fallback, foreign leases, a file over 2 MiB, a line over
64 KiB, fragmented pieces, grouped Undo/Redo, byte-exact saves, mixed EOL and
control bytes, sector boundaries, Cyrillic input/search, tab columns,
horizontal scrolling, Save As path resolution, selection, cross-file clipboard
above 2 MiB, clipboard failures/cancellation, read-only/full
disks, injected read/write failures, missing/damaged editor, sorted panel
return, and memory/stack/bank cleanup. Editor input tests use an independent Set-2 FIFO/MMIO fixture and the real
ROM keyboard translator. The legacy latch is disconnected. Pixel checks
compare the caret with the actual ROM glyph. Rendered snapshots are digital video references, not PAL
or physical-board validation.

## Object build

NCMAIN and NCEDIT are assembled independently from the modules in
`firmware/nc`. NCMAIN owns the command loop; NCMCAT handles the catalogue,
NCMUI the panels and menus, and NCMFILE file operations and viewing.
NCEDIT owns editor startup; NCEFILE handles cached file pieces and saving,
NCEUI rendering, NCENAV navigation/search, and NCEBLOCK block operations.
NCMSTR/NCESTR contain initialized data; NCMV1–3/NCEV1–3 contain BSS.
NCCOM provides shared UI/video utilities through NCUI.LIB. NCEND owns the
last BSS byte. The entry objects own the first BSS bytes, so the existing
UniCROSS OBJ format can distinguish both boundaries without new flags.

Use `make -f firmware/Makefile nc` for the complete cross build. For a native
build copy all NC sources to one directory, run `HANDLES 16` before loading
the VM, and follow `NCBUILD.TXT`. UniAS, UniLD and UniAR use identical
limits and object formats on both hosts. No PGM BSS postprocessing occurs.
The build's `linked-labels` command only creates test/debug headers from
UniAS listings and a UniLD map; it never changes the program.
