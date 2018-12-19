.include "./proj_macro.asm"
.text
.globl au_logical
# Argument:
# 	$a0: First number
#	$a1: Second number
#	$a2: operation code ('+':add, '-':sub, '*':mul, '/':div)
# Return:
#	$v0: ($a0+$a1) | ($a0-$a1) | ($a0*$a1):LO | ($a0 / $a1)
# 	$v1: ($a0 * $a1):HI | ($a0 % $a1)

au_logical:

	beq $a2, 0x2B, add_logical
	beq $a2, 0x2D, sub_logical
	beq $a2, 0x2A, mult_signed
	beq $a2, 0x2F, div_signed
	
	j FINISH
	
add_logical:
	addi $sp, $sp, -20
	sw $fp, 20 ($sp)
	sw $ra, 16($sp)		#Have to save frame again because we will be changing $a2 based on operation
	sw $a2, 12($sp)
	sw $s1, 8($sp)
	addi $fp, $sp, 20
	
	lui $a2, 0x0000  #Set $a2 to 0x00000000 through lui and ori (MIPS Native Instructions)
	ori $a2, 0x0000	
	jal add_sub_logical
	
	lw $fp, 20 ($sp)
	lw $ra, 16($sp)		#Have to save frame again because we will be changing $a2 based on operation
	lw $a2, 12($sp)
	lw $s1, 8($sp)
	addi $sp, $sp, 20
	jr $ra
	
sub_logical:
	addi $sp, $sp, -20
	sw $fp, 20 ($sp)
	sw $ra, 16($sp)		#Have to save frame again because we will be changing $a2 based on operation
	sw $a2, 12($sp)
	sw $s1, 8($sp)
	addi $fp, $sp, 20
	
	lui $a2, 0xFFFF  #Set $a2 all to zeros which signals addition then we can check if $a1 is negative
	ori $a2 0xFFFF	# $a2 indicates to perform addition
	jal add_sub_logical
	
	lw $fp, 20 ($sp)
	lw $ra, 16($sp)		#Have to save frame again because we will be changing $a2 based on operation
	lw $a2, 12($sp)
	lw $s1, 8($sp)
	addi $sp, $sp, 20
	jr $ra
	
add_sub_logical: 
	addi	$sp, $sp, -32
	sw   	$fp, 32($sp)
	sw   	$ra, 28($sp)
	sw   	$a0, 24($sp)
	sw   	$a1, 20($sp)
	sw 	$a2, 16($sp)
	sw 	$s0, 12($sp)
	sw 	$s1, 8($sp)
	addi 	$fp, $sp, 32
	
	addi $t0, $zero, 0	# index
	addi $s1, $zero, 0	#setting our final answer to 0b00000000, if we do not, it will lead to errors because we don't know what $s1 is upon entering this function
	addi $t1, $zero, 0	#If addition the carry in will be 0 and will not change								
	beq $a2, 0x00000000, loop #Checking if it is addition, if not, will negate bit pattern in $a1 and make CI a 1 	S = A + (B-1)
	not $a1, $a1	#Negating the bit pattern
	addi $t1, $zero, 1	#Setting the CI to 1	
											
loop:
		extract_nth_bit($t2, $a0, $t0)	#Extracting first bit from $a0 at position $t0(A)
		extract_nth_bit($t3, $a1, $t0)	#Extracting first bit from $a1 at position $t0(B)		
		xor $t4, $t2, $t3	#A XOR B							
		xor $s0, $t1, $t4	#(A XOR B)XOR CI 									

		insert_to_nth_bit($s1, $t0, $s0, $t7)	#Inserting sum into $s0 at the position the loop is currently at										
		and $t6, $t4, $t1	#Doing calculations to find next Ci, thus (A XOR B).CI		
		and $t5, $t2, $t3    	#Doing calculations to find next CI, thus A.B								
		or $t1, $t5, $t6 	#CI =  CI.(A XOR B) + A.B  
		addi $t0, $t0, 1	#Incrementing index of loop										
		blt $t0, 32, loop	#Until $t0 does not equal 32, continue on with the loop. 
						#If it does, then it will fall through to restore which restores the frame
RESTORE_ADD:	
		move $v0, $s1 #Move the final answer to $v0
		move $v1, $t1 #Move carry in bit to $v1 *** Will be necessary for inverting product of 64 bit
		lw   	$fp, 32($sp)
		lw   	$ra, 28($sp)
		lw   	$a0, 24($sp)
		lw   	$a1, 20($sp)
		lw 	$a2, 16($sp)
		lw 	$s0, 12($sp)
		lw 	$s1, 8($sp)
		addi 	$sp, $sp, 32

		jr $ra

mult_signed:
	addi $sp, $sp, -48	# Store frame so that it saves all saved registers to be sure 
	sw $fp, 48($sp)		#it does not mess up on frame creation
	sw $ra, 44($sp)	
	sw $a0, 40($sp)
	sw $a1, 36($sp)
	sw $s0, 32($sp)
	sw $s1, 28($sp)
	sw $s2, 24($sp)
	sw $s3, 20($sp)
	sw $s4, 16($sp)
	sw $s5, 12($sp)
	sw $s6, 8($sp)
	addi $fp, $sp, 48

	move $s0,$a0	# Saved argument $a0 in $s0 for using twos_complement_64bit later if needed
	move $s1,$a1	# Saved argument $a1 in $s1 for using twos_complement_64bit later if needed
	jal	twos_complement_if_neg	#Invert bit pattern and add one if $a0 is negative
	move $s2, $v0	#Store result in $s2
	
	move $a0, $s1			#$s1 is really $a1, but we are loading $s0 in $a0
	jal twos_complement_if_neg	#Invert bit pattern and add one if $a0 is negative, store in 
	move $s3, $v0	#Store result in $s3
	
	move $a0,$s2	#Loading in new arguments in to do mult_unsigned
	move $a1,$s3
	jal	mult_unsigned
	move $s4, $v0	#Save LO result into $s4
	move $s5, $v1	#Save HI result into $s5
	
	li $t9, 31
	extract_nth_bit($t0,$s0,$t9) #Extract MSB bit from $a0	
	extract_nth_bit($t1,$s1,$t9) #Extract MSB bit from $a1
	xor $s6, $t0, $t1						  											
	beq $s6, 0, RESTORE_MULT_SIGNED #IF the XOR == 0, then go restore, as answer is positive
	move $a0,$s4	#ELSE, do twos_complement_64bit
	move $a1,$s5
	jal	twos_complement_64bit														
	j	RESTORE_MULT_SIGNED					
	
RESTORE_MULT_SIGNED:
	lw $fp, 48($sp)		#it does not mess up on frame creation
	lw $ra, 44($sp)	
	lw $a0, 40($sp)
	lw $a1, 36($sp)
	lw $s0, 32($sp)
	lw $s1, 28($sp)
	lw $s2, 24($sp)
	lw $s3, 20($sp)
	lw $s4, 16($sp)
	lw $s5, 12($sp)
	lw $s6, 8($sp)
	addi $sp, $sp, 48
	jr $ra

mult_unsigned: 
	addi	$sp, $sp, -48
	sw   	$fp, 48($sp)
	sw   	$ra, 44($sp)
	sw   	$a0, 40($sp)
	sw   	$a1, 36($sp)
	sw 	$a2, 32($sp)
	sw 	$s0, 28($sp)
	sw 	$s1, 24($sp)
	sw 	$s2, 20($sp)
	sw 	$s3, 16($sp)
	sw 	$s4, 12($sp)
	sw 	$s5, 8($sp)
	addi 	$fp, $sp, 48
	
	addi $s0, $zero, 0 #I
	move $s1, $a1 #MPLR L
	addi $s2, $zero, 0x00000000 #H
	move $s3, $a0 #MCND M
	
mult_loop:	
	extract_nth_bit($t3,$s1, $zero) #Extract first bit of LO
	move $a0, $t3 		#Preparing to call bit_replicator by moving $t3 to $a0
	jal bit_replicator
	move $t3, $v0  		#Move the result back to $t3(R)
	
	and $t4, $t3, $s3 	# $t4 = M & R *** $t4 = X
	move $a1, $t4		#Preparing to do H = H + X *** $a1 is new X
	move $a0, $s2		#$a0 = H
	jal add_logical 	
	move $s2, $v0   	#s2 = H + X
	srl $s1,$s1,1 	 # L>>1
	
	extract_nth_bit($t5, $s2, $zero) # Extracting H[0], putting it into $t5
	addi $t6, $zero, 31
	insert_to_nth_bit($s1, $t6, $t5, $t7) #Inserting $t5 to L[31]
	
	srl $s2, $s2, 1	# H>>1
	addi $s0, $s0, 1 # I++
	
	blt $s0, 32, mult_loop
	
RESTORE_MULT_UNSIGNED:
	move $v0, $s1 #Moving $s1 to LO
	move $v1, $s2 #Moving $s2 to HI
	
	lw   	$fp, 48($sp)
	lw   	$ra, 44($sp)
	lw   	$a0, 40($sp)
	lw   	$a1, 36($sp)
	lw 	$a2, 32($sp)
	lw 	$s0, 28($sp)
	lw 	$s1, 24($sp)
	lw 	$s2, 20($sp)
	lw 	$s3, 16($sp)
	lw 	$s4, 12($sp)
	lw 	$s5, 8($sp)
	addi 	$sp, $sp, 48
	
	jr $ra
	
div_signed: 
	addi	$sp, $sp, -56
	sw   	$fp, 56($sp)
	sw   	$ra, 52($sp)
	sw   	$a0, 48($sp)
	sw   	$a1, 44($sp)
	sw 	$a2, 40($sp)
	sw 	$s0, 36($sp)
	sw 	$s1, 32($sp)
	sw 	$s2, 28($sp)
	sw 	$s3, 24($sp)
	sw 	$s4, 20($sp)
	sw 	$s5, 16($sp)
	sw 	$s6, 12($sp)
	sw 	$s7, 8($sp)
	addi 	$fp, $sp, 56
	
	move $s0,$a0	# Saved argument $a0 in $s0 for using/testing twos_complement_quotient and twos_complement_remainder later 
	move $s1,$a1	# Saved argument $a1 in $s1 for using/testing twos_complement_quotient later 
	jal	twos_complement_if_neg	#Invert bit pattern and add one if $a0 is negative
	move $s2, $v0	#Store result in $s2
	
	move $a0, $s1			#$s1 is really $a1, but we are loading $s0 in $a0
	jal twos_complement_if_neg	#Invert bit pattern and add one if $a0 is negative, store in 
	move $s3, $v0	#Store result in $s3
	
	move $a0,$s2	#Loading in new arguments in to do div_unsigned
	move $a1,$s3
	jal	div_unsigned
	move $s4, $v0	#Save LO result into $s4
	move $s5, $v1	#Save HI result into $s5
	
	addi $t9, $zero, 31
	extract_nth_bit($t0, $s0, $t9)
	extract_nth_bit($t1, $s1, $t9)
	xor $s6, $t0, $t1
	
	move $s7, $t0 #USED LATER TO CHANGE REMAINDER TO NEGATIVE if $s7 is 
	beq $s6, 1, twos_complement_quotient
	j twos_complement_remainder

	j RESTORE_DIV_SIGNED
	
twos_complement_quotient: 
	move $a0, $s4
	jal twos_complement
	move $s4, $v0
	
twos_complement_remainder: 
	bne $s7, 1, RESTORE_DIV_SIGNED
	move $a0, $s5
	jal twos_complement
	move $s5, $v0
	
RESTORE_DIV_SIGNED:
	move $v0, $s4
	move $v1, $s5
	lw   	$fp, 56($sp)
	lw   	$ra, 52($sp)
	lw   	$a0, 48($sp)
	lw   	$a1, 44($sp)
	lw 	$a2, 40($sp)
	lw 	$s0, 36($sp)
	lw 	$s1, 32($sp)
	lw 	$s2, 28($sp)
	lw 	$s3, 24($sp)
	lw 	$s4, 20($sp)
	lw 	$s5, 16($sp)
	lw 	$s6, 12($sp)
	lw 	$s7, 8($sp)
	addi 	$sp, $sp, 56
	
	jr $ra
	
div_unsigned:
	addi	$sp, $sp, -48
	sw   	$fp, 48($sp)
	sw   	$ra, 44($sp)
	sw   	$a0, 40($sp)
	sw   	$a1, 36($sp)
	sw 	$a2, 32($sp)
	sw 	$s0, 28($sp)
	sw 	$s1, 24($sp)
	sw 	$s2, 20($sp)
	sw 	$s3, 16($sp)
	sw 	$s4, 12($sp)
	sw 	$s5, 8($sp)
	addi 	$fp, $sp, 48
	
	addi $s0, $zero, 0 #I
	add $s1, $zero, 0 #Remainder
	move $s2, $a0 #DVSR (Divisor) ALSO Q
	move $s3, $a1 #DVDN (Dividend) AlSO D
	
div_loop: 

	sll $s1, $s1, 1 #Shifting R to left by 1
	addi $t0, $t0, 31
	extract_nth_bit($s4, $s2, $t0) #Extracting Q[31] and putting it into $s4
	insert_to_nth_bit($s1, $zero, $s4, $t9) #Inserting bit of $sit into $s1[0] which is R[0]
	sll $s2, $s2, 1 #Shifting Q to left by 1
	move $a0, $s1 #Moving R into first argument
	move $a1, $s3 #Moving D into first argument
	jal sub_logical 
	move $s5, $v0 #S = R - D
	
	bgt $s5, -1, div_greater
	addi $s0, $s0, 1
	blt $s0, 32, div_loop
	
	j RESTORE_DIV_UNSIGNED
	
div_greater: 	
	move $s1, $s5  #R = S
	addi $t1, $zero, 1
	insert_to_nth_bit($s2, $zero, $t1, $t9)
	addi $s0, $s0, 1
	blt $s0, 32, div_loop

RESTORE_DIV_UNSIGNED:

	move $v0, $s2
	move $v1, $s1
	
	lw   	$fp, 48($sp)
	lw   	$ra, 44($sp)
	lw   	$a0, 40($sp)
	lw   	$a1, 36($sp)
	lw 	$a2, 32($sp)
	lw 	$s0, 28($sp)
	lw 	$s1, 24($sp)
	lw 	$s2, 20($sp)
	lw 	$s3, 16($sp)
	lw 	$s4, 12($sp)
	lw 	$s5, 8($sp)
	addi 	$sp, $sp, 48
	jr $ra
	
twos_complement_if_neg:
	blt $a0, 0, twos_complement	# If $a0 is negative, jump to twos_complement
	move $v0, $a0		#Else, since twos_complement returns $v0, we have to return the original argument if it is not negative	
	jr $ra				

twos_complement:
	addi $sp, $sp, -24									
	sw $fp, 24($sp)
	sw $ra, 20($sp)
	sw $a0, 16($sp)
	sw $a1, 12($sp)
	sw $a2, 8($sp)
	addi $fp, $sp, 24
	
	not $a0, $a0	#Do an inversion of bit pattern
	addi $a1, $zero, 1	#Add one to the inversion by calling add_logical
	jal add_logical	# $v0 will hold result
	
	lw $fp, 24($sp)											
	lw $ra, 20($sp)
	lw $a0, 16($sp)
	lw $a1, 12($sp)
	lw $a2, 8($sp)
	addi $sp, $sp, 24
	
	jr $ra
	
twos_complement_64bit:
	addi	$sp, $sp, -40
	sw   	$fp, 40($sp)
	sw   	$ra, 36($sp)
	sw   	$a0, 32($sp)
	sw   	$a1, 28($sp)
	sw 	$a2, 24($sp)
	sw 	$s0, 20($sp)
	sw 	$s1, 16($sp)
	sw	$s2, 12($sp)
	sw 	$s3, 8($sp)
	addi 	$fp, $sp, 40	
	
	not $a0, $a0	#Invert both arguments				
	not $a1, $a1
	move $s1, $a1 #Have to save at least one of the registers for the second call for add_logical
	li $a1, 1
	jal add_logical	#Adding 1($a1) to $a0
	move $s2, $v0	#Moving result in $s2
	move $a0,$s1
	move $a1, $v1	#TAKING THE CARRY FROM PREVIOUS CALL AND STORING IT AS FIRST OPERAND IN upcoming add_logical
	jal add_logical 
	move $s3, $v0
	move $v0, $s2 #New LO(32-bit) 
	move $v1, $s3 #New HI(32-bit)
			
	
	lw   	$fp, 40($sp)
	lw   	$ra, 36($sp)
	lw   	$a0, 32($sp)
	lw   	$a1, 28($sp)
	lw 	$a2, 24($sp)
	lw 	$s0, 20($sp)
	lw 	$s1, 16($sp)
	lw	$s2, 12($sp)
	lw 	$s3, 8($sp)
	addi 	$sp, $sp, 40
	
	jr $ra
	
bit_replicator: 
	addi $sp, $sp, -16
	sw $fp, 16 ($sp)
	sw $ra, 12($sp)	
	sw $a0, 8($sp)
	addi $fp, $sp, 16
		
	beq $a0, 0x1, bit_replicator_negative	#If extracted bit from $a0 is 1, it is negative
	lui $a0, 0x0000	#Else, $a0 is positive and load 0x00000000 into $a0
	ori $a0, 0x0000
	move $v0, $a0	#returning $v0, so move $a0's contents to $v0
	j restore_bit_replicator
		
bit_replicator_negative: 
	lui $a0, 0xFFFF #Loading bit pattern of $a0 with all ones which is 0xFFFFFFFF
	ori $a0, 0xFFFF
	move $v0, $a0	#returning $v0, so move $a0's contents to $v0
	
restore_bit_replicator:
	lw $fp, 16 ($sp)
	lw $ra, 12($sp)	
	lw $a0, 8($sp)
	addi $sp, $sp, 16
	jr $ra	
	
FINISH: 
	jr 	$ra
