/**********************************************************************************
* Copyright (c) 2015, Valentin DEBON                                              *
* All rights reserved.                                                            *
*                                                                                 *
* Redistribution and use in source and binary forms, with or without              *
* modification, are permitted provided that the following conditions are met:     *
*     * Redistributions of source code must retain the above copyright            *
*       notice, this list of conditions and the following disclaimer.             *
*     * Redistributions in binary form must reproduce the above copyright         *
*       notice, this list of conditions and the following disclaimer in the       *
*       documentation and/or other materials provided with the distribution.      *
*     * Neither the name of the copyright holder nor the                          *
*       names of its contributors may be used to endorse or promote products      *
*       derived from this software without specific prior written permission.     *
*                                                                                 *
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND *
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED   *
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE          *
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY            *
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES      *
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;    *
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND     *
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT      *
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS   *
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.                    *
**********************************************************************************/

.org	0x0000	# adress 0x0000 at segment 0x07C0
/*
	calling convention: every register must be saved for draw_char and is_colliding,
	freedom for other functions
*/

.code16		# real mode
start:
	mov	%cs, %ax		# %cs should be 0x07C0
	mov	%ax, %ds		# Set data segment according to the executable position
	mov	%ax, %es		# Set extra segment
	mov	%ax, %ss		# Set stack segment
	mov	$0x400,%bp		# Arbitrary value, 16 bytes aligned, >512
	mov	%bp,%sp			# Can finally use a proper stack
	push	$0x0000			# Score Right<<8 | Score Left
	push	$0x0C28			# y<<8 | x
	push	$0x0A0A			# leftPlayerY<<8 | rightPlayerY
	push	$0xFFFF			# dy<<8 | dx
	call	init_scr
	mov	-6(%bp),%ax
	call	draw_players
	call	reset_stage		# Note: Scores ain't redrawn at each frames, so they may disappear
					# before next score if the ball gets on
.L_1:
# Handle Keyboard Input
	in	$0x60,%al		# Read directly the port, non-blocking and
					# clearer than multiple BIOS calls
	mov	%bp,%si			# %si will hold which y position for drawing
#.TEST_LEFT_UP:
	sub	$5,%si
	cmpb	$0x00,-5(%bp)		# Check for up collision
	je	.TEST_LEFT_DOWN
	cmp	$0x11,%al		# 0x11 : 'w' in US keyboard
	jne	.TEST_LEFT_DOWN
	mov	$0x0A,%al
	jmp	.DRAW_UP		# Left player Up
.TEST_LEFT_DOWN:
	cmpb	$0x15,-5(%bp)		# Check for down collision
	je	.TEST_RIGHT_UP
	cmp	$0x1F,%al		# 0x1F : 's' in US keyboard
	jne	.TEST_RIGHT_UP
	mov	$0x0A,%al
	jmp	.DRAW_DOWN		# Left player Down
.TEST_RIGHT_UP:
	dec	%si
	cmpb	$0x00,-6(%bp)		# Check for up collision
	je	.TEST_RIGHT_DOWN
	cmp	$0x19,%al		# 0x19 : 'p' in US keyboard
	jne	.TEST_RIGHT_DOWN
	mov	$0x45,%al
	jmp	.DRAW_UP		# Right player Up
.TEST_RIGHT_DOWN:
	cmpb	$0x15,-6(%bp)		# Check for down collision
	je	.END_TESTS
	cmp	$0x27,%al		# 0x27 : ';' in US keyboard
	jne	.END_TESTS
	mov	$0x45,%al
.DRAW_DOWN:
	mov	(%si),%ah
        mov     $0x0020,%bx		# 0x20 = ' '
	call	draw_char
        mov     $0x007C,%bx		# 0x7C = '|'
	add	$4,%ah
	call	draw_char
	incb	(%si)
	jmp	.END_TESTS
.DRAW_UP:
	decb	(%si)
	mov	(%si),%ah
        mov     $0x007C,%bx		# 0x7C = '|'
	call	draw_char
        mov     $0x0020,%bx		# 0x20 = ' '
	add	$4,%ah
	call	draw_char
.END_TESTS:
# Now, we handle the ball
	mov	-4(%bp),%ax
	mov	$0x0020,%bx		# 0x20 : ' '
	call	draw_char
	addb	-7(%bp),%ah
	addb	-8(%bp),%al
	mov	%ax,-4(%bp)
	mov	$0x0040,%bx		# 0x40 : '@'
	call	draw_char

	cmpb	$0x00,-3(%bp)
	je	.NEGY_BALL
	cmpb	$0x18,-3(%bp)
	jne	.END_NEGY_BALL
.NEGY_BALL:
	negb	-7(%bp)
.END_NEGY_BALL:
#.SCORE_RIGHT_BALL:
	cmpb	$0x00,-4(%bp)
	jne	.SCORE_LEFT_BALL
	incb	-1(%bp)
	jmp	.SCORE_BALL
.SCORE_LEFT_BALL:
	cmpb	$0x4F,-4(%bp)
	jne	.END_SCORE_BALL
	incb	-2(%bp)
.SCORE_BALL:
	call	reset_stage
.END_SCORE_BALL:

#.CHECK_COLLISION_LEFT
	cmpb	$0x0B,-4(%bp)
	jne	.CHECK_COLLISION_RIGHT
	movb	-5(%bp),%al
	call	is_colliding
	cmp	$0x00,%ax
	je	.COLLIDED
	jmp	.END_COLLISIONS
.CHECK_COLLISION_RIGHT:
	cmpb	$0x44,-4(%bp)
	jne	.END_COLLISIONS
	movb	-6(%bp),%al
	call	is_colliding
	cmp	$0x00,%ax
	jne	.END_COLLISIONS
.COLLIDED:
	negb	-8(%bp)
.END_COLLISIONS:

.END_BALL:
#	xor	%cx,%cx
	mov	$0x03,%cx
	mov	$0x7FFF,%dx		# We wait (%dx microseconds)*%cx, if %cx > 0
	mov	$0x86,%ah
	int	$0x15			# The delay
	jmp	.L_1

is_colliding:			# is_colliding(ypos: %al) : %ax=0 if(yball>=%al || yball<=%al+4)
	cmpb	%al,-3(%bp)
	jl	.COLLIDE_FALSE
	add	$3,%al
	cmpb	%al,-3(%bp)
	jle	.COLLIDE_TRUE
.COLLIDE_FALSE:
	mov	$0x01,%ax
	ret
.COLLIDE_TRUE:
	mov	$0x00,%ax
	ret

draw_char:			# draw_char(pos : %ax, char: %bl, page : %bh) : void
	push	%bp
	mov	%sp,%bp
	push	%ax
	push	%dx
        mov     -2(%bp),%dx
        mov     $0x02,%ah
        int     $0x10           # Set the cursor at index in %dx
        mov     $0x0E,%ah
	mov	%bl,%al
        int     $0x10
	pop	%dx
	pop	%ax
	pop	%bp
	ret

reset_stage:
# First, drawing the scores
	mov	$0x0126,%ax	# Position (y, x)
	mov	$0x0030,%bx
	add	-1(%bp),%bl
	call	draw_char
	add	$3,%al
	mov	$0x0030,%bx
	add	-2(%bp),%bl
	call	draw_char
# Second, rewriting the ball position
	mov	-4(%bp),%ax
	mov	$0x0020,%bx		# 0x20 : ' '
	call	draw_char
	mov	$0x0C28,%ax
	mov	%ax,-4(%bp)
	mov	$0x0040,%bx		# 0x40 : '@'
	call	draw_char
	ret

draw_players:			# draw_players() : void
        mov     $0x007C,%bx	# 0x7C = '|'
	mov	$0x0A,%al	# First, we draw left player
	movb	-5(%bp),%ah
	movb	%ah,%cl
	add	$4,%cl
.L_DRAWLEFT:
	cmp	%cl,%ah
	je	.ENT_DRAWRIGHT
	call	draw_char
	inc	%ah
	jmp	.L_DRAWLEFT
.ENT_DRAWRIGHT:
	mov	$0x45,%al	# Then, right player
	movb	-6(%bp),%ah
	movb	%ah,%cl
	add	$4,%cl
.R_DRAWLEFT:
	cmp	%cl,%ah
	je	.RET_DRAW
	call	draw_char
	inc	%ah
	jmp	.R_DRAWLEFT
.RET_DRAW:
	ret

init_scr:			# init_scr() : void
	mov	$0x0002,%ax	# Set text mode 80x25
	int	$0x10
	mov	$0x01,%ah
	mov	$0x02,%ch
	int	$0x10		# Hiding cursor
	ret

.org	0x01BE	# Partition Table
	.fill	0x40,0x1,0x0
.org	0x01FE	# Magic Number
	.word	0xAA55
