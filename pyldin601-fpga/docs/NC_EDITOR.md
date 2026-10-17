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
allocates the editor without page padding, reads the code, applies full
16-bit address relocations (including low-byte carry) in 64-byte batches,
closes the file, and jumps to the editor.
This avoids a transient low-RAM allocation for the entire relocation table
while graphics video RAM is allocated. Both allocations belong to the native
child and are released by DOS on its exit. UniLD `-b` joins the two standard
PGM files without changing either header or relocation table. This command
runs identically on the host and under native UniDOS.

The loader passes its address in A:B. Once its arguments and state have
been consumed, its first 512 bytes become an ordinary disk-cache block;
the next 80 hold the current display row. The complete character cache
uses private GPU scratch at 1FE000..1FF7FF: one 256-byte slot for each
of up to 24 rows. A row switch flushes/loads only 40 or 80 bytes through
flat DMA. Valid tags avoid reading uninitialized SRAM. Redraw invalidates
tags; modal restoration reads cached characters without rescanning text.
DMA errors invalidate the viewport and are reported before the next key
wait. The current FPGA DMA interface is required. The native framebuffer,
palette, and leased RAMMAN banks are not used for this cache.

The editor uses about 25–26 KiB of ordinary RAM, including its loader, code,
viewport character cache, metadata and I/O buffers. NCEDIT.json reports the
base allocation, GPU scratch, the optional 512-byte cache slot and the
maximum total. Document length and edit count do not increase this allocation.
One ordinary 512-byte cache slot and sixteen banked slots use one leased
8 KiB bank when its ABI check and allocation succeed. Without RAMMAN, the
unused BIOS bounce buffer becomes a second ordinary slot. Another ordinary
slot is allocated when conventional memory permits. The lease never assumes a free physical bank
number and restores selectors around BIOS/DOS/font operations. Banked data
passes through an ordinary 512-byte bounce buffer for native DOS transfers.
The leaf-split buffer shares the Save/clipboard staging buffer: payload
staging completes before history application can split the directory. The
256-byte buffer holds the largest half-leaf. Splits publish/flush the old
leaf before acquiring its neighbor, so two cache slots suffice. Ordinary
buffers transfer directly through DOS; only banked slots need the bounce.
The small fallback may perform extra I/O during far-offset edits.

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
Work files are removed on normal exit. Recovery uses separate committed
snapshots; a damaged piece directory is never trusted after a crash.

A failed output write leaves the original and the editing state available
for another Save or Save As. A read-only source can use a writable scratch
directory and Save As to another drive. A full target can likewise be bypassed
with Save As if the work disk still has space. An I/O failure during a partially
applied edit offers retry, or an explicit discard-and-close action.

## Recovery checkpoints

F9 streams a recovery copy; after a minute without text changes, the idle
loop starts the same operation automatically. It uses the configured work
directory, or the document directory by default. No document-sized RAM
buffer is allocated. The window shows progress and accepts cancellation.
Changes made after the last complete checkpoint are outside that copy.

Four names, `NCR0hhhh.RC0` through `.RC3`, derive from CRC16 of the full,
case-folded document pathname. The trailer verifies the complete pathname,
so a hash collision does not authorize overwriting somebody else's file.
Unknown/incomplete files are preserved. The newest committed copy and the
snapshot currently used as immutable backing are never overwritten.
The fourth slot permits rotation when an interrupted write occupies a slot.
If no safe slot or disk space remains, the original and edits survive and
automatic retries stop; a successful manual F9 enables them again.

Each file contains exact document bytes followed by a 128-byte `NCR1`
commit trailer: pathname at 4..83, BE32 generation at 84, length at 88,
byte cursor at 92, payload CRC16/XMODEM at 96, and trailer CRC16 at 126.
The trailer is written last, and the file is closed before publication to
the user. On F4, startup validates trailers, checks the newest payload CRC,
and tries an older copy after corruption or truncation. Restore requires
confirmation. No/Cancel opens the original and retains recovery copies.
The PS/2 mouse is initialized before verification and confirmation, so the
scan can be cancelled by mouse and the restore buttons can be clicked.

Restoration opens the verified snapshot read-only as the new backing,
restores the byte cursor, and marks the document modified. A new Undo history
starts there; old IDX/ADD/UND files are not replayed. Saving leaves Undo
available, removes obsolete checkpoint offers, and invalidates only the
trailer of a snapshot still needed for Undo. Normal Save/Discard and editor
exit remove owned recovery files after closing their handles. Work files
left by a crashed process can be removed after successful restoration.
These checks protect against interrupted application writes and resets;
they do not repair a damaged FAT volume or guarantee storage-controller
durability after loss of power.

## Find and replace

F7/Shift+F7 retain literal, case-sensitive forward search. F8 asks for the
pattern and replacement, then replaces one match from the cursor, wrapping
once if needed. Shift+F8 confirms replacement of all matches in the whole
document. Patterns and replacements use native bytes, up to 79 characters;
an empty replacement deletes matches. There are no regular expressions.

Replace All moves forward through original text, skipping inserted bytes
and stopping at EOF. Thus `a` to `aa` terminates. Each match uses the existing
staged block transaction and is a separate Undo record. Esc/Ctrl+C cancels
between bounded reads; completed replacements remain editable and undoable.
Failed staging does not apply that replacement. Large texts keep the same
RAM bound as ordinary editing.

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

`run_nc_recovery.py` starts fresh native CPU/DOS processes on disk-only
snapshots, independently parses FAT12 and verifies both CRCs. It covers
restore and far cursors, cancellation, write failure, a cut during a new
snapshot, bad payload/trailer, No/Cancel, disk full, missing RAMMAN, the real
idle interval and a checkpoint above 2 MiB. Viewport tests check each DMA
descriptor and its private bounds. A failed row DMA must restore the cache
after acknowledgement while preserving byte-exact text and Save.

## Object build

NCMAIN and NCEDIT are assembled independently from the modules in
`firmware/nc`. NCMAIN owns the command loop; NCMCAT handles the catalogue,
NCMUI the panels and menus, and NCMFILE file operations and viewing.
NCEDIT owns editor startup; NCEFILE handles cached file pieces and saving,
NCEUI rendering with the NCEROW.INC GPU row cache, NCENAV navigation/search
and replacement, NCEBLOCK block operations, and NCEAUTO recovery checkpoints.
NCMSTR/NCESTR contain initialized data; NCMV1–3/NCEV1–3 contain BSS.
NCCOM provides shared UI/video utilities through NCUI.LIB. NCEND owns the
last BSS byte. The entry objects own the first BSS bytes, so the existing
UniCROSS OBJ format can distinguish both boundaries without new flags.

Use `make -f firmware/Makefile nc` for the complete cross build. For a native
build copy all NC sources, `firmware/input/MOUSE.ASM` and
`firmware/memory/DMA.INC` to one directory, run `HANDLES 16` before loading
the VM, and follow `NCBUILD.TXT`. UniAS, UniLD and UniAR use identical
limits and object formats on both hosts. No PGM BSS postprocessing occurs.
The build's `linked-labels` command only creates test/debug headers from
UniAS listings and a UniLD map; it never changes the program.
