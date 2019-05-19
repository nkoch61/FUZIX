
	.include "../lib/z80fixedbank-banked.s"

	.globl _portff
	.globl switch_bank
	.globl map_kernel_restore
	.globl ksave_map
	.globl current_map

	.globl bankfork

bankfork:
;
;	A = parent bank
;	C = child
;
;	1 main memory
;	2 ext
;	3 dock
;
;	We have three cases
;
;	1. 	Dock/Ext -> Main
;	2.	Main -> Dock/Ext
;	3.	Dock/Ext -> Dock/Ext
;
	ld b,a

	; Set up so we can map_kernel_restore to undo
	; the mess we create
	ld a,(current_map)
	ld (ksave_map),a

	bit 1,b		; parent is ext/dock
	jr z, from_main
	; From ext or dock to where ?
	bit 1,c
	jr z, to_main
	; Ext to Dock or Dock to Ext
	; Use port 0xFF to do the work
	ld a,#0xF8
	out (0xF4),a		; Set up the MMU
	ld a,#0xFF
	ld (bankpatch1 + 1),a
	ld (bankpatch2 + 1),a
	ld a,(_portff)
	and #0x7F
	bit 0,c			; C = 3 (child in dock)
	jr z, ext2doc
	or #0x80		; C = 2 (parent in dock)
ext2doc:
	ld (cpatch0 + 1),a	; source
	xor #0x80
	ld (cpatch1 + 1), a	; dest
	jp do_copies

from_main:
	xor a
	jr viamain
to_main:
	ld a,#0xF8		; F4 port value to use
viamain:
	ld (cpatch0 + 1), a
	xor #0xF8
	ld (cpatch1 + 1), a
	ld a,#0xF4		; We will toggle 0xF4
	ld (bankpatch1 + 1) ,a
	ld (bankpatch2 + 1), a
	; We are going from a bank to main memory.
	ld a,#4
	call switch_bank	; we need page 4 visible
	jp do_copies

;
;	We patch this so it must be in writable memory
;
	.area _COMMONDATA

do_copies:
	;
	;	Set up ready for the copy
	;
	push ix
	ld (spcache),sp
	; Stack pointer at the target buffer
	ld sp,#PROGBASE	; Base of memory to fork
	; 10 outer loops - copy 40K
	ld a,#10
	ld (copyct),a
	xor a		; 256 inner loops of 16 (total 4K a loop)
copyloop:
	ex af,af'	; Save A as we need an A for ioports
cpatch0:
	ld a,#0		; parent bank (patched in for speed)
bankpatch1:
	out (0x00),a
	pop bc		; copy 16 bytes out of parent
	pop de
	pop hl
	exx
	pop bc
	pop de
	pop hl
	pop ix
	pop iy
	ld (sp_patch+1),sp
cpatch1:
	ld a,#0		; child bank (also patched in for speed)
bankpatch2:
	out (0x00),a
	push iy		; and put them back into the child
	push ix
	push hl
	push de
	push bc
	exx
	push hl
	push de
	push bc
	ex af,af'	; Get counter back
	dec a
	jp z, setdone	; 256 loops ?
copy_cont:
sp_patch:
	ld sp,#0
	jp copyloop

	.area _COMMONMEM
;
;	This outer loop only runs 8 times so isn't quite so performance
;	critical
;
setdone:
	ld hl,#copyct
	dec (hl)
	jr z, copy_over
	xor a
	jp copy_cont
copy_over:
	;
	;	Get the stack back
	;
	ld sp,(spcache)
	;
	;	And the correct kernel bank.
	;
	pop ix
	jp map_kernel_restore

	.area _COMMONDATA

spcache:
	.word 0
copyct:
	.byte 0