# $s0 = energy depletion rate
# $s1 = maximum energy level
# $s2 = initial energy level
# $s3 = current energy level
# $s4 = command
# $s5 = commandUnit
# $s6 = Start Time (Timestamp before waiting)
# $s7 = Total Time (Aggregated seconds)

.data

# inputParameters
header:	.asciiz "\n=== Digital Pet Simulator (MIPS32) ===\nInitializing system..."
inputPrompt: .asciiz "Please set parameters (press Enter for default):\n"

# askEDR
inputMessage_EDR: .asciiz "Enter Natural Energy Depletion Rate (EDR) [Default: 1]: "
userInput_EDR: .space 20
default_EDR: .word 1

# askMEL
inputMessage_MEL: .asciiz "Enter Maximum Energy Level (MEL) [Default: 15]: "
userInput_MEL: .space 20
default_MEL: .word 15

# askIEL
inputMessage_IEL: .asciiz "Enter Initial Energy Level (IEL) [Default: 5]: "
userInput_IEL: .space 20
default_IEL: .word 5

# Time depletion messages
timeMessageStart: .asciiz "\nTime +" 
timeMessageEnd: .asciiz "s... Natural energy depletion!\n"

# askCommand
inputCommandMessage: .asciiz "\n\nEnter a command (F, E, P, I, R, Q, H) > "
inputCommand: .space 30
newLine: .asciiz "\n"
pleaseResetMessage: .asciiz "\nYour pet has died. Please press R to revive it.\n"

# executeCommand
feedMessage:       .asciiz "\n\nCommand recognized: Feed "
playMessage:       .asciiz "\n\nCommand recognized: Entertain "
petMessage:        .asciiz "\n\nCommand recognized: Pet "
ignoreMessage:     .asciiz "\n\nCommand recognized: Ignore "
resetMessage:      .asciiz "\n\nCommand recognized: Reset.\nDigital Pet has been reset to its initial state!\n"
quitMessage:       .asciiz "\n\nCommand recognized: Quit.\nSaving session... goodbye!\n--- simulation terminated ---\n"
haltMessage:	.asciiz "\n\nCommand recognized: Halt.\n"
deadMessage:	.asciiz "\n*** Your Digital Pet has died! ***\n"
dot:	.asciiz "."
totalTimeMessage: .asciiz "\nYour pet was alive for: "
secondsMessage: .asciiz " seconds\n"
currentStatusMessage: .asciiz "Current status: \n"

# halt
startHaltMessage:       .asciiz "\nThe game is now halted.\nEnter C to continue the game: "


# calculateEnergyChange
feedMultiplier: .word 1
entertainAndPetMultiplier: .word 2
ignoreMultiplier: .word -3
positiveEnergyChangePrompt: .asciiz "\nEnergy increased by "
negativeEnergyChangePrompt: .asciiz "\nEnergy decreased by "
energyChangeUnit: .asciiz " unit "
energyChangeUnits: .asciiz " units "
leftBracket: .asciiz "("
rightBracket: .asciiz ").\n"
multipleSign: .asciiz "x"
reachMaximumPrompt:  .asciiz "\nError, maximum energy level reached! Capped to the Max.\n"
reachMinimumPrompt:       .asciiz "Error, energy level equal or less than 0. DP is dead!\n"

# printEnergyBar
barLeft: .asciiz "["
barRight: .asciiz "]"
barFill: .asciiz "#"
barEmpty: .asciiz "-"
energyPrompt: .asciiz " Energy: "
flash: .asciiz "/"

# setSuccessfully
setSuccessfullyPrompt: .asciiz "Parameters set successfully!\n"
sign_EDR: .asciiz "- EDR: "
sign_MEL: .asciiz "- MEL: "
sign_IEL: .asciiz "- IEL: "
unit_EDR: .asciiz " units/sec\n"
unit_MEL: .asciiz " units\n"
unit_IEL: .asciiz " units\n\n"
aliveMessage: .asciiz "Your Digital Pet is alive! Current status:\n"

# validationLogic
inputBuffer: .space 250
invalidMessage: .asciiz "\nInvalid command. Please input command again."

# validateInt
validateIntInput: .asciiz "Invalid input, please enter a number\n"

errIELTLimitError: .asciiz "\nInitial energy level cannot be greater than max energy level\n"

# save/load

saveFilename:   .asciiz "pet_save.dat"
askLoadMsg:     .asciiz "\nFound save file. Continue previous state? (y/n): "
askSaveMsg:     .asciiz "\nSave current state before quitting? (y/n): "
errInvalidInput:.asciiz "\n[!] Invalid input. Please enter 'y' or 'n'.\n"
saveSuccess:    .asciiz "\nGame state saved successfully!\n"
loadSuccess:    .asciiz "\nGame state loaded successfully!\n"
errSave:        .asciiz "\nError, Failed to write file. Check permissions.\n"
    
.align 2 # Alignment for word storage
fileBuffer:     .space 20

.text
.globl main

main:
	jal tryLoadState
    	beq $v0, 1, _startGame
	jal initialization
	jal _gameLoop

_startGame:
	jal printEnergyBar

_gameLoop:
	jal startTimer
	jal askCommand
	jal waitForCommand  					# return command
	jal handleTimeCatchup
	jal deathValidation

	beqz $v0, _canExecute
	li $t0, 'R'
	beq $s4, $t0, _canExecute
	li $t0, 'Q'
	beq $s4, $t0, _canExecute
	j _gameLoop

_canExecute:
	jal executeCommand
	jal deathValidation
	bne $v0, $zero, _gameLoop
	j _gameLoop


# Command LifeCycle Functions
startTimer:
	li $v0, 30 
	syscall 
	move $s6, $a0
	jr $ra

askCommand:
	# Check if the pet is dead
	bne $s3, $zero, _petNotDead

	li $v0, 4
	la $a0, pleaseResetMessage
	syscall

_petNotDead:
	li $v0, 4
	la $a0, inputCommandMessage
	syscall
	jr $ra

waitForCommand:
_getUserInput:
	li $v0, 8
	la $a0,inputBuffer 
	li $a1, 250
	syscall

# Initialize iterator pointer
	la $t0, inputBuffer
	li $t7, 0 		#flag for checking following digits

_charLoopStart:
	lb $t1, 0($t0)      	# loads a byte
	beqz $t1,  _invalidCommand
       
	# skip white spaces
	li $t2, 32          	# space ' '
	beq $t1, $t2,  _skipChar
	li $t2, 9           	# tab '\t'
	beq $t1, $t2,  _skipChar
	li $t2, 10          	# newline '\n'
	beq $t1, $t2,  _skipChar
       
 	# check for F, E, P, I, R, Q, H
	li $t2, 'F'
	beq $t1, $t2, _validCommand
	li $t2, 'E'
	beq $t1, $t2, _validCommand
	li $t2, 'P'
	beq $t1, $t2, _validCommand
	li $t2, 'I'
	beq $t1, $t2, _validCommand
	li $t2, 'R'
	beq $t1, $t2, _validCommand
	li $t2, 'Q'
	beq $t1, $t2, _validCommand
	li $t2, 'H'
	beq $t1, $t2, _validCommand
    
 	j _invalidCommand

_validCommand:
	move $t5, $t1
	addiu $t0, $t0, 1
 	li $t6, 0


_parseNumStart:
	lb $t1, 0($t0)
	beqz $t1, _iterateLoopEnd 
          
	# skip white space
	li $t2, 32      
	beq $t1, $t2, _skipNumChar
	li $t2, 9       
	beq $t1, $t2, _skipNumChar
	li $t2, 10      
	beq $t1, $t2, _skipNumChar
	li $t2, '0' #initialise lower range for parsing int
	li $t3, '9' #initialise upper range for parsing int
	blt $t1, $t2, _invalidCommand
	bgt $t1, $t3, _invalidCommand
	mul $t6, $t6, 10
	addiu $t1, $t1, -48
	addu  $t6, $t6, $t1 
	li $t7, 1 #has digit, set flag to 1
	addiu $t0, $t0, 1
	j _parseNumStart

_skipChar:
	addiu $t0, $t0, 1
	j _charLoopStart

_skipNumChar:
	addiu $t0, $t0, 1
	j _parseNumStart

_invalidCommand:
	li $v0, 4
	la $a0, invalidMessage
	syscall	
	li $t1, 0
	la $t4, inputBuffer
	li $t0, 0
	li $t2, 50

_clearLoop:
	bge $t0, $t2,  _clearDone  # If ($t0 >= 50), exit loop
	sb $t1, 0($t4)
	addiu $t4, $t4, 1
	addiu $t0, $t0, 1
	j _clearLoop
      
_clearDone:
	move $t5, $zero
	li $v0, 4
	la $a0, inputCommandMessage
	syscall
	j _getUserInput

_iterateLoopEnd:
	# Checks if command needs numerical value
	li $t0, 'F'
	beq $t5, $t0, _checkDigit
	li $t0, 'E'
	beq $t5, $t0, _checkDigit
	li $t0, 'P'
	beq $t5, $t0, _checkDigit
	li $t0, 'I'
	beq $t5, $t0, _checkDigit
	j _commandValidationSuccess

_checkDigit:
	#checks if command have numerical value
	beqz $t7, _invalidCommand

_commandValidationSuccess:
	move $s4, $t5
	move $s5, $t6

	jr $ra

handleTimeCatchup:
	addiu $sp, $sp, -4
    	sw   $ra, 0($sp)	
    	li $t0, 'Q'
    	beq $s4, $t0, _endCatchup
    	li $t0, 'R'
    	beq $s4, $t0, _endCatchup

    	li $v0, 30
    	syscall

    	subu $t0, $a0, $s6     
    	div $t0, $t0, 1000      

    	beqz $t0, _endCatchup   

    	mul $t2, $t0, $s0       
    	subu $s3, $s3, $t2

	addu $s7, $s7, $t0       

    	bge $s3, $zero, _printTimeMsg	# If energy >= 0, skip to printing
    	move $s3, $zero	# Else, force energy to 0

_printTimeMsg:
	li $v0, 4
	la $a0, timeMessageStart
    	syscall

    	# Print the number of seconds (e.g. 3)
    	li $v0, 1
    	move $a0, $t0
    	syscall

    	# Print "s... Natural energy depletion!\n"
    	li $v0, 4
    	la $a0, timeMessageEnd
    	syscall

    	jal printEnergyBar

_endCatchup:
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra

executeCommand:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)	
	beq $s4, 'F', _feedBranch
	beq $s4, 'E', _entertainBranch
	beq $s4, 'P', _petBranch
	beq $s4, 'I', _ignoreBranch
	beq $s4, 'R', _reset
	beq $s4, 'Q', _quit
	beq $s4, 'H', _halt
	j _endExecuteCommand
	
_feedBranch:
	la $a0, feedMessage
	jal printRecPrompt
	jal feed

	j _endExecuteCommand
_entertainBranch:
	la $a0, playMessage
	jal printRecPrompt
	jal entertain
	j _endExecuteCommand
_petBranch:
	la $a0, petMessage
	jal printRecPrompt
	jal pet
	j _endExecuteCommand
_ignoreBranch:
	la $a0, ignoreMessage
	jal printRecPrompt
	jal ignore
	j _endExecuteCommand
_reset:
	la $a0, resetMessage
	li $v0, 4
	syscall
	jal reset
	j _endExecuteCommand
_halt:
	la $a0, haltMessage
	li $v0, 4
	syscall

	jal halt

	la $a0, currentStatusMessage
	li $v0, 4
	syscall

	j _endExecuteCommand
_quit:
	jal saveStateSequence

	la $a0, quitMessage
	li $v0, 4
	syscall

	li $v0, 10 
	syscall

_endExecuteCommand:
	jal printEnergyBar

	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra

deathValidation:
	# $v0 = isDead
	bne $s3, $zero, _notDead			# If not dead, don’t print dead message

	li $v0, 4
	la $a0, deadMessage
	syscall

	li $v0, 4
	la $a0, totalTimeMessage
	syscall
	
	li $v0, 1
	move $a0, $s7
	syscall

	li $v0, 4
	la $a0, secondsMessage
	syscall

	li $v0, 1
	jr $ra
	
_notDead:
	li $v0, 0
	jr $ra


# Recognize command
printRecPrompt:
	# $a0 = commandMessage
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	li $v0, 4
	syscall

	move $a0, $s5
	li $v0, 1
	syscall

	la $a0, dot
	li $v0, 4
	syscall

	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra

# Six Main Functions
feed:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)
	lw $a0, feedMultiplier($zero)
	jal calculateEnergyChange
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra
	
entertain:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	lw $a0, entertainAndPetMultiplier($zero)
	jal calculateEnergyChange
	lw $ra, 0($sp) 
	addi $sp, $sp, 4
	jr $ra

pet:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	lw $a0, entertainAndPetMultiplier($zero)
	jal calculateEnergyChange
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra
	
ignore:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	lw $a0, ignoreMultiplier($zero)
	jal calculateEnergyChange
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra

reset:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	move $s3, $s2
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra

halt:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	li $v0, 4
	la $a0, startHaltMessage
	syscall

_startHaltLoop:
	li $v0, 12
	syscall
	move $t0, $v0
	beq $t0, 'C', _endHaltLoop
	j _startHaltLoop
_endHaltLoop:
	li $v0, 4
	la $a0, newLine
	syscall

	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra
	

# Calculate change of energy
calculateEnergyChange:
	# $a0 = command multiplier
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	move $t0, $a0				# $t0 = command multiplier
	mul $a1, $s5, $t0			# $a1 = energy change = unit * commandMultiplier
	addu $t2, $s3, $a1			# $t2 = temp current energy

	bgt $t2, $s1, _upperLimit
	blez  $t2, _energyZero
	addu $s3, $s3, $a1			# Add energy change to current energy level
	bgt $t0, $zero, _printPos
	j _printNeg

_upperLimit:
	jal printUpperLimit
	j _endCalculate
_energyZero:                                                                   
	jal printNegEnergyChange
	jal printEnergyZero
	j _endCalculate
_printPos:
	jal printPosEnergyChange
	j _endCalculate
_printNeg:
	jal printNegEnergyChange
_endCalculate:
	
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra

# Print Calculation Result Prompt
printUpperLimit:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)
	move $s3, $s1					#set the current energy to the maximum level
	li $v0, 4
	la $a0, reachMaximumPrompt
	syscall
	jr $ra

printEnergyZero:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	move $s3, $zero
	li $v0, 4
	la $a0, reachMinimumPrompt
	syscall
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra

printPosEnergyChange:
	# $a0 = command multiplier
	# $a1 = energy change
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	move $t0, $a0					# $t0 = command multiplier
	move $t1, $a1					# $t1 = energy change

	li $v0, 4
	la $a0, positiveEnergyChangePrompt	
	syscall						# print “Energy increase by”
	
	move $a0, $t1					
	li $v0, 1					
	syscall						# print {energy change}
	
	beq $t1, 1, _pos_printUnit
	j _pos_printUnits

_pos_printUnit:
	li $v0, 4
	la $a0, energyChangeUnit					
	syscall						# print “unit”
	j _pos_finishPrintUnits

_pos_printUnits:
	li $v0, 4
	la $a0, energyChangeUnits					
	syscall						# print “units”

_pos_finishPrintUnits:
	move $a0, $t0
	beq $t1, 1, _pos_dontprintBrackets
	jal printBrackets

_pos_dontprintBrackets:
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra
	
printNegEnergyChange:
	# $a0 = command multiplier
	# $a1 = energy change
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)	
	subu $t0, $zero, $a0
	subu $t1, $zero, $a1

	li $v0, 4
	la $a0, negativeEnergyChangePrompt	# “Energy decrease by”
	syscall
	
	move $a0, $t1
	li $v0, 1					# “{energy change}”
	syscall

	beq $t1, 1, _neg_printUnit
	j _neg_printUnits

_neg_printUnit:
	li $v0, 4
	la $a0, energyChangeUnit					
	syscall						# print “unit”
	j _neg_finishPrintUnits

_neg_printUnits:
	li $v0, 4
	la $a0, energyChangeUnits					
	syscall						# print “units”

_neg_finishPrintUnits:
	move $a0, $t0
	beq $t1, 1, _neg_dontprintBrackets
	jal printBrackets

_neg_dontprintBrackets:
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra


printBrackets:
	# $a0 = command multiplier

	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	move $t0, $a0					# $t0 = command multiplier

	li $v0, 4
	la $a0, leftBracket				#”(”
	syscall

	move $a0, $s5
	li $v0, 1					#”{userinput unit}”
	syscall

	li $v0, 4
	la $a0, multipleSign				#”x”
	syscall

	move $a0, $t0
	li $v0, 1					#”{multiplier}”
	syscall

	li $v0, 4
	la $a0, rightBracket				#”)”
	syscall
	
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra
# Print Energy Bar
printEnergyBar:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	li $v0, 4
	la $a0, barLeft
	syscall
	
# Print fill part
	move $t0, $s3
_printFillLoop:
	blez $t0, _endPrintFillLoop
	li $v0, 4
	la $a0, barFill
	syscall
	subiu $t0, $t0, 1
	j _printFillLoop

_endPrintFillLoop:
	subu $t0, $s1, $s3
_printEmptyLoop:
	blez $t0, _printBarRight
	li $v0, 4
	la $a0, barEmpty
	syscall
	subiu $t0, $t0, 1
	j _printEmptyLoop
	
_printBarRight:
	li $v0, 4
	la $a0, barRight
	syscall	

	jal _printEnergyPrompt

	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

_printEnergyPrompt:
	addiu $sp, $sp, -4
	sw $ra 0($sp)

	li $v0, 4
	la $a0, energyPrompt
	syscall

	move $a0, $s3
	li $v0, 1
	syscall

	li $v0, 4
	la $a0, flash
	syscall

	move $a0, $s1
	li $v0, 1
	syscall

	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra
# Initialization Functions
initialization:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	jal inputParameters
	jal askEDR
	jal askMEL
	jal askIEL
	jal setSuccessfully
	jal printEnergyBar
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra

inputParameters:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	li $v0, 4
	la $a0, header
	syscall
	
	li $v0, 4
	la $a0, inputPrompt
	syscall
	
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra
	
askEDR:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)
	# Print prompt
	li $v0, 4
	la $a0, inputMessage_EDR
	syscall
	
	# Read String
	li $v0, 8
	la $a0, userInput_EDR
	li $a1, 20
	syscall
	
	# Check for empty input
	la $t0, userInput_EDR
	lb $t1, 0($t0)
	beq $t1, 10, _useDefaultEDR

	move $a0, $t0
	jal validateInt
	beqz $v0, _invalidIntEDR
	
	# Parse String to Integer
	la $a0, userInput_EDR
	jal stringToInteger
	move $s0, $v0
	j _endAskEDR

_invalidIntEDR:
	li $v0, 4
	la $a0, validateIntInput
	syscall
	j askEDR


_useDefaultEDR:
	la $t2, default_EDR
	lw $s0, 0($t2)

_endAskEDR:
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra

stringToInteger:
	# $a0 = input string
	# $v0 = converted integer
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	move $t0, $a0
	li $v0, 0
_startStringToInteger:
	lb $t1, 0($t0) 				# Load a character 
	beq $t1, 10, _endStringToInteger	# Stop if Newline 
	beq $t1, 0, _endStringToInteger		# Stop if Null terminator 
	subiu $t1, $t1, 48 			# Convert ASCII '0'-'9' to integer 0-9 
	mul $v0, $v0, 10 			# Shift previous result (x10) 
	addu $v0, $v0, $t1 			# Add new digit 
	addiu $t0, $t0, 1 			# Move to next character 
	j _startStringToInteger
_endStringToInteger:
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra
	
askMEL:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)
	li $v0, 4
	la $a0, inputMessage_MEL
	syscall
	
	li $v0, 8
	la $a0, userInput_MEL
	li $a1, 20
	syscall

	# Check for empty input
	la $t0, userInput_MEL
	lb $t1, 0($t0)
	beq $t1, 10, _useDefaultMEL

	move $a0, $t0
	jal validateInt
	beqz $v0, _invalidIntMEL

	# Parse String to Integer
	la $a0, userInput_MEL
	jal stringToInteger
	move $s1, $v0
	j _endAskMEL

_invalidIntMEL:
	li $v0, 4
	la $a0, validateIntInput
	syscall
	j askMEL


_useDefaultMEL:
	la $t2, default_MEL
	lw $s1, 0($t2)

_endAskMEL:
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra
	
askIEL:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)
	li $v0, 4
	la $a0, inputMessage_IEL
	syscall
	
	li $v0, 8
	la $a0, userInput_IEL
	li $a1, 20
	syscall

	# Check for empty input
	la $t0, userInput_IEL
	lb $t1, 0($t0)
	beq $t1, 10, _useDefaultIEL

	move $a0, $t0
	jal validateInt
	beqz $v0, _invalidIntIEL

	
	# Parse String to Integer
	la $a0, userInput_IEL
	jal stringToInteger
	move $s2, $v0				# Set initial energy level to $s2
	move $s3, $s2			
	j _endAskIEL

_invalidIntIEL:
	li $v0, 4
	la $a0, validateIntInput
	syscall
	j askIEL

_useDefaultIEL:
	la $t2, default_IEL
	lw $s2, 0($t2)

_endAskIEL:
	bgt $s2, $s1, _ielExceedLimit
	move $s3, $s2				# Set current energy level to $s3
	lw $ra, 0($sp) 
	addiu $sp, $sp, 4
	jr $ra

_ielExceedLimit:
	li $v0, 4
	la $a0, errIELTLimitError
	syscall
	j askIEL

printParameters:
	addiu $sp, $sp, -4
	sw $ra, 0($sp)

	li $v0, 4
	la $a0, sign_EDR
	syscall

	li $v0, 1
	move $a0, $s0
	syscall

	li $v0, 4
	la $a0, unit_EDR
	syscall

	li $v0, 4
	la $a0, sign_MEL
	syscall

	li $v0, 1
	move $a0, $s1
	syscall

	li $v0, 4
	la $a0, unit_MEL
	syscall

	li $v0, 4
	la $a0, sign_IEL
	syscall

	li $v0, 1
	move $a0, $s2
	syscall

	li $v0, 4
	la $a0, unit_IEL
	syscall

	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

setSuccessfully:
	addiu $sp, $sp, -4
	sw   $ra, 0($sp)
	
	li $v0, 4
   	la $a0, setSuccessfullyPrompt
   	syscall

    	jal printParameters

	li $v0, 4
	la $a0, aliveMessage
	syscall

    	lw $ra, 0($sp)
    	addiu $sp, $sp, 4
    	jr $ra

validateInt:
	addiu $sp, $sp, -4
    	sw $ra, 0($sp)
    
	move $t2, $a0        			#Use $t2 to iterate, preserving $a0

_validationLoop:
	lb $t3, 0($t2)
	beq $t3, 10, _validationLoopValid
	beq $t3, 0, _validationLoopValid 	#sorts out issue of null and newline after input
	
	li $t4, '0'
	li $t5, '9'
	blt $t3, $t4, _validationLoopInvalid
	bgt $t3, $t5, _validationLoopInvalid
	
	addiu $t2, $t2, 1	
	j _validationLoop
	
#returns 1 for valid, 0 for invalid
_validationLoopInvalid:
	li $v0, 0
	j _exitValidation

_validationLoopValid:
	li $v0, 1
	j _exitValidation

_exitValidation:
	lw $ra, 0($sp)
	addiu $sp, $sp, 4
	jr $ra

# SAVE / LOAD IMPLEMENTATION

tryLoadState:
    	addiu $sp, $sp, -4
    	sw $ra, 0($sp)

    	li $v0, 13
    	la $a0, saveFilename
    	li $a1, 9 # Append + Create Mode
    	li $a2, 0
    	syscall
    	move $t0, $v0

    	blt $t0, 0, _noLoad

    	li $v0, 16
    	move $a0, $t0
    	syscall

    	li $v0, 13
    	la $a0, saveFilename
    	li $a1, 0 # Read Mode
    	li $a2, 0
    	syscall
    	move $t0, $v0

    	# Try to load 16 bytes to identify whether it is real data
    	li $v0, 14
    	move $a0, $t0
    	la $a1, fileBuffer
    	li $a2, 20
    	syscall
    	move $t1, $v0

    	li $v0, 16
    	move $a0, $t0
    	syscall

    	blt $t1, 20, _noLoad

    	j _askLoadLoop

_askLoadLoop:
    	li $v0, 4
    	la $a0, askLoadMsg
    	syscall

    	li $v0, 8
    	la $a0, inputBuffer
    	li $a1, 10
    	syscall
    
    	la $t1, inputBuffer
    	lb $t0, 0($t1)
    
    	beq $t0, 'y', _doLoad_Confirm
    	beq $t0, 'n', _noLoad
    
    	li $v0, 4
    	la $a0, errInvalidInput
    	syscall
    	j _askLoadLoop

_doLoad_Confirm:
    	la $t1, fileBuffer
    	lw $s0, 0($t1)
    	lw $s1, 4($t1)
    	lw $s2, 8($t1)
    	lw $s3, 12($t1)
    	sw $s7, 16($t1)

    	li $v0, 4
    	la $a0, loadSuccess
    	syscall

    	addiu $sp, $sp, -4 
    	sw $ra, 0($sp) 
    	jal printParameters 
    	lw $ra, 0($sp) 
    	addiu $sp, $sp, 4

    	li $v0, 1
    	lw $ra, 0($sp)
    	addiu $sp, $sp, 4
    	jr $ra
    
_noLoad:
    	li $v0, 0
    	lw $ra, 0($sp)
    	addiu $sp, $sp, 4
    	jr $ra

saveStateSequence:
    	addiu $sp, $sp, -4
    	sw $ra, 0($sp)
    
_askSaveLoop:
    	li $v0, 4
    	la $a0, askSaveMsg
    	syscall

    	li $v0, 8
    	la $a0, inputBuffer
    	li $a1, 10
    	syscall
    
    	la $t1, inputBuffer
    	lb $t0, 0($t1)

    	beq $t0, 'y', _doSave
    	beq $t0, 'n', _noSave
    
    	li $v0, 4
    	la $a0, errInvalidInput
    	syscall
    	j _askSaveLoop

_doSave:
    	# Pack Data to Buffer
    	la $t1, fileBuffer
    	sw $s0, 0($t1)
    	sw $s1, 4($t1)
    	sw $s2, 8($t1)
    	sw $s3, 12($t1)
    	sw $s7, 16($t1)

    	# Open File 
    	li $v0, 13
    	la $a0, saveFilename
    	li $a1, 1 # Write Mode = 1
    	li $a2, 0
    	syscall
    	move $t0, $v0

    	blt $t0, 0, _saveFailedHandler

    	# Write File
    	li $v0, 15
    	move $a0, $t0
    	la $a1, fileBuffer
    	li $a2, 20
    	syscall

    	# Close File
    	li $v0, 16
    	move $a0, $t0
    	syscall

    	li $v0, 4
    	la $a0, saveSuccess
    	syscall

    	lw $ra, 0($sp)
    	addiu $sp, $sp, 4
    	jr $ra

_saveFailedHandler:
    	li $v0, 4
    	la $a0, errSave
    	syscall
    	lw $ra, 0($sp)
    	addiu $sp, $sp, 4
    	jr $ra

_noSave:
    	lw $ra, 0($sp)
    	addiu $sp, $sp, 4
    	jr $ra

