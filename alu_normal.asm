.include "./proj_macro.asm"
.text
.globl au_normal
# Argument:
# 	$a0: First number
#	$a1: Second number
#	$a2: operation code ('+':add, '-':sub, '*':mul, '/':div)
# Return:
#	$v0: ($a0+$a1) | ($a0-$a1) | ($a0*$a1):LO | ($a0 / $a1)
# 	$v1: ($a0 * $a1):HI | ($a0 % $a1)

au_normal:
	addi $sp, $sp, -24
	sw $fp, 24($sp)
	sw $ra, 20($sp)
	sw $a0, 16($sp)
	sw $a1, 12($sp)
	sw $a2, 8($sp)
	addi $fp, $sp, 24
	
	beq $a2, 0x2A, MULTIPLICATION
	beq $a2, 0x2F, DIVISION
	beq $a2, 0x2B, ADDITION
	beq $a2, 0x2D, SUBTRACTION
	
MULTIPLICATION: mult $a0, $a1
		mfhi $v1 
		mflo $v0 #MOST IMPORTANT IN $V0
		j au_normal_end	
		
DIVISION: div $a0, $a1
	  mflo $v0 #MOST IMPORTANT IN $V0
	  mfhi $v1
	  j au_normal_end
	  	
ADDITION: add $v0,$a0, $a1
	  j au_normal_end
	  
SUBTRACTION: sub $v0, $a0, $a1
	     j au_normal_end
	     
au_normal_end:	
	lw $fp, 24($sp)
	lw $ra, 20($sp)
	lw $a0, 16($sp)
	lw $a1, 12($sp)
	lw $a2, 8($sp)	
	addi $sp, $sp, 24
	
	jr	$ra
