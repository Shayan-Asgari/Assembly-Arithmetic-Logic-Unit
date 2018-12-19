	#$regD is what is returned as final
	#$regS is what is to be extracted from
	#regT is the bit position to be extracted
	.macro extract_nth_bit($regD, $regS, $regT)
		addi $t8, $zero, 1
		sllv $t8, $t8, $regT
		and $regD, $regS, $t8
		srlv $regD, $regD, $regT
	.end_macro
		
	#$regD original bit pattern that 0 or 1 will be inserted in at $regS position
	#$regS position to be modified [0-31]
	#regT register that contains bit to insert which will be 0x0 or 0x1
	#$maskReg register that is the ne
	.macro insert_to_nth_bit($regD, $regS, $regT, $maskReg)
	 	addi $maskReg, $zero, 1
		sllv $maskReg, $maskReg, $regS
		not $maskReg, $maskReg
		and $regD, $regD, $maskReg
		sllv $regT, $regT, $regS
		or $regD, $regD, $regT
	.end_macro

	
