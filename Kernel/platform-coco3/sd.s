;;;
;;;  A Gary Becker FPGA SD 
;;;  implementation for Will's fuzix sd driver
;;;  This is almost so trivial it's stupid.
;;; 
	
	.globl _sd_spi_clock
	.globl _sd_spi_raise_cs
	.globl _sd_spi_lower_cs
	.globl _sd_spi_transmit_byte
	.globl _sd_spi_receive_byte
	.globl _sd_spi_transmit_sector
	.globl _sd_spi_receive_sector

	.area	.text

_sd_spi_clock
	rts
	
_sd_spi_raise_cs
	lda	#$80
	sta	$ff64
	rts
	
_sd_spi_lower_cs
	lda	#$81
	sta	$ff64
	rts
	
_sd_spi_transmit_byte
	stb	$ff65
	rts
	
_sd_spi_receive_byte
	ldb	$ff65
	rts

	.area	.common
	
_sd_spi_transmit_sector
	lda	#0		; loop counter
	ldx	_blk_op		; X = buffer address
	jsr	blkdev_rawflg	; flip mmu mapping to whatever rawflag says
a@	ldb	,x+
	stb	$ff65
	nop
	ldb	,x+
	stb	$ff65
	nop
	deca			; bump counter
	bne	a@		; loop
	jsr	blkdev_unrawflg	; revert mmu to normal
	rts
	
_sd_spi_receive_sector
	lda	#512/8
	ldx	_blk_op
	jsr	blkdev_rawflg
a@	ldb	$ff65
	stb	,x+
	ldb	$ff65
	stb	,x+
	ldb	$ff65
	stb	,x+
	ldb	$ff65
	stb	,x+
	ldb	$ff65
	stb	,x+
	ldb	$ff65
	stb	,x+
	ldb	$ff65
	stb	,x+
	ldb	$ff65
	stb	,x+
	deca
	bne	a@
	jsr	blkdev_unrawflg
	rts	
