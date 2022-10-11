TITLE String Primitives .and Macros    (Proj6_onlessa.asm)

; Author: Andy Olness
; Last Modified: 3-13-22
; OSU email address: olnessa@oregonstate.edu
; Course number/section:   CS271 Section 400
; Project Number:  6         Due Date:3-14-22
; Description: Program asks user to input 10 signed integers, each one must fit into an SDWORD,
;				otherwise the program will tell user number is not valid and ask for another number.
;				After 10 numbers have been entered, the sum and average are calculated and displayed.

INCLUDE Irvine32.inc

;----------------------------------------------------------------------------------------------------------------
; Name: mGetString
;
; Description: Gets a string from user input and saves it as well as the length of the string.
;
; Preconditions: userInput must be a BYTE string, sizeOfInput must be the maximum length of userInput,
;					bytesRead must be a DWORD counter.
;
; Postconditions: None
;
; Receives:
;			prompt		= address of string
;			userInput	= address to store user generated string
;			sizeOfInput = maximum length of userInput
;			bytesRead	= address to store the length user inputted
;
; Returns:
;			userInput	= saved user input
;			bytesRead	= length of userInput
;
; ----------------------------------------------------------------------------------------------------------------
mGetString	MACRO	prompt, userInput, sizeOfInput, bytesRead
  
  PUSHAD
  MOV	EDX, prompt
  CALL	WriteString
  MOV	EDX, userInput
  MOV	ECX, sizeOfInput
  CALL	ReadString
  MOV	EBX, bytesRead
  MOV	[EBX], EAX
  POPAD

ENDM

;----------------------------------------------------------------------------------------------------------------
; Name: mDisplayString
;
; Description: Receives a string address and calls WriteString to display the string.
;
; Preconditions: stringMem must be address of string to be displayed.
;
; Postconditions: None
;
; Receives:
;			stringMem = address of string to display
;
; Returns: None
;
; ----------------------------------------------------------------------------------------------------------------
mDisplayString	MACRO	stringMem

  PUSHAD
  MOV	EDX, stringMem
  CALL	WriteString
  POPAD

ENDM

NEGLIMIT = 2147483648

.data

introPrompt	BYTE	"PROGRAMMING ASSIGNMENT 6: Designing low-level I/O procedures",13,10
			BYTE	"Written by: Andy Olness",13,10,13,10
			BYTE	"Please provide 10 signed decimal integers.",13,10,13,10
			BYTE	"Each number needs to be small enough to fit inside a 32 bit register.",13,10
			BYTE	"After you have finished inputting the raw numbers I will display a list of the integers,",13,10
			BYTE	"their sum, and their average value.",13,10,13,10,0
getPrompt	BYTE	"Please enter a signed number: ",0
inputString	BYTE	25 DUP (?)
count		DWORD	0
errorMsg	BYTE	"ERROR: You did not enter a signed number or your number was too big.",13,10,0
numArray	SDWORD	10 DUP (?)
numHolder	SDWORD	0
enterPrompt	BYTE	13,10,"You entered the following numbers: ",13,10,0
outString	BYTE	11 DUP (?)
revString	BYTE	11 DUP (?)
sumPrompt	BYTE	13,10,"The sum of these numbers is: ",0
sumInt		SDWORD	0
avgPrompt	BYTE	13,10,"The truncated average is: ",0
avgInt		SDWORD	0
byePrompt	BYTE	13,10,13,10,"Thanks for playing!",13,10,0
spacing		BYTE	", ",0

.code
main PROC

  ; introduce program and prepare for _getInput loop
  mDisplayString OFFSET introPrompt
  MOV	ECX, 10								; counter for _getInput loop
  MOV	EDI, OFFSET numArray

  ; get 10 signed integers from user, validate each integer, and save each in numArray
_getInput:
  PUSH	OFFSET getPrompt
  PUSH	OFFSET inputString
  PUSH	OFFSET count
  PUSH	SIZEOF inputString
  PUSH	OFFSET errorMsg
  PUSH	EDI									; current number in numArray
  CALL	readVal
  ADD	EDI, 4								; next number in numArray
  LOOP	_getInput
  
  ; prompt and set counter for displaying all integers
  mDisplayString OFFSET enterPrompt
  MOV	ECX, 10								; counter for _output loop
  MOV	ESI, OFFSET numArray

  ; display all integers in a single string
_output:
  PUSH	OFFSET outString
  PUSH	OFFSET revString
  PUSH	ESI									; current number in numArray
  CALL	writeVal
  CMP	ECX, 1								; if last number from numArray, no comma needed after
  JE	_listEnd
  mDisplayString OFFSET spacing				; a comma and a space
  ADD	ESI, 4								; next number in numArray
  LOOP	_output

_listEnd:
  CALL	CrLf

  ; calculate the sum and average of all integers
  PUSH	OFFSET avgInt
  PUSH	OFFSET numArray
  PUSH	OFFSET sumInt
  CALL	calculate

  ; display sumPrompt and the sum of all integers
  mDisplayString OFFSET sumPrompt
  PUSH	OFFSET outString
  PUSH	OFFSET revString
  PUSH	OFFSET sumInt
  CALL	writeVal

  ; display avgPrompt and the average of all integers
  mDisplayString OFFSET avgPrompt
  PUSH	OFFSET outString
  PUSH	OFFSET revString
  PUSH	OFFSET avgInt
  CALL	writeVal

  ; say goodbye
  mDisplayString OFFSET byePrompt

	Invoke ExitProcess,0	; exit to operating system
main ENDP

;----------------------------------------------------------------------------------------------------------------
; Name: readVal
;
; Description: Calls mGetString to get a signed integer from the user in the form of a string. Converts the string
;				to an integer and validates that the integer fits in a single SDWORD. If valid, saves the integer
;				into numArray.
;				
; Preconditions: User input must be a string of only number characters, but may start with + or -. Value must
;					fit in an SDWORD.
;
; Postconditions: None
;
; Receives:
;			[EBP + 8]  = Offset of current index in numArray
;			[EBP + 12] = Offset of errorMsg prompt
;			[EBP + 16] = Maximum size for user generated string
;			[EBP + 20] = Offset to store the number of BYTES user entered
;			[EBP + 24] = Offset to store the user entered string
;			[EBP + 28] = Offset of getPrompt to prompt user
;
; Returns:
;			numArray:		index updated with valid integer
;			inputString:	saves the user input
;			count:			stores the number of BYTEs entered
; ----------------------------------------------------------------------------------------------------------------
readVal	PROC

  PUSH	EBP
  MOV	EBP, ESP
  PUSHAD

  ; Get the string from the user.
_getString:
  mGetString [EBP + 28], [EBP + 24], [EBP + 16], [EBP + 20]

  ; Set up registers and counter for validation and conversion.
  MOV	ESI, [EBP + 24]		; Ofset of userInput for string storage
  MOV	EDI, [EBP + 8]		; current index in numArray
  MOV	EDX, [EBP + 20]		; count refference
  MOV	ECX, [EDX]			; number of elements of string (count value)	
  MOV	EBX, 0				; temporaray number holder
  MOV	EDX, 0				
  CLD

  ; Check the first character in the string. If less than 48 (0 character), checks if it is 
  ;		+ or - character.
_checkForSign:
  MOV	EAX, 0
  LODSB						; current string char into AL, also in EAX because EAX was zeroed previously
  CMP	EAX, 48				; compare character with 0 character
  JGE	_validate
  CMP	EAX, 45				; compare character with - character
  JE	_negative
  CMP	EAX, 43				; compare character with + character
  JE	_positive
  JMP	_notValid			; less than 0 and not + or -

  ; First character is - character. Set temporary sign tracker and load second character.
_negative:
  MOV	EDX, 1				; temporary sign tracker, set to negative
  DEC	ECX					
  LODSB
  JMP	_validate

  ; First character is + character. Set temporary sign tracker and load second character.
_positive:
  MOV	EDX, 0				; temporary sign tracker, set to positive
  DEC	ECX
  LODSB
  JMP	_validate
  
  ; Character is not valid, display error message and get string input again.
_notValid:
  MOV	EDX, [EBP + 12]		; errorMsg prompt
  CALL	WriteString
  JMP	_getString

  ; Check subsequent characters for validity and confirm the integer fits in SDWORD.
_validate:
  CMP	EAX, 48				; less than 0
  JL	_notValid
  CMP	EAX, 57				; greater than 9
  JG	_notValid
  IMUL	EBX, 10				; multiply temporary num holder to get the proper digits place
  JO	_negate				; if overflow, jumps to check if equal to the neg limit of an SDWORD
  SUB	EAX, 48				; convert character to integer
  ADD	EBX, EAX			; add integer to temp num holder
  JO	_negate
  LODSB
  LOOP	_validate
  CMP	EDX, 0				; check temporary sign holder
  JE	_store				; integer is pos
  NEG	EBX					; integer is neg
  JMP	_store

  ; -----------------------------------------------------------------------------------------------------
  ; If overflow, checks the temporary sign holder. If number will be negative, check to see if the 
  ;		integer equals 2147483648. If so, and there are no more numbers to add, negate and store number.
  ;		Otherwise the negative number is too large (small) to fit.
  ;------------------------------------------------------------------------------------------------------
_negate:
  CMP	EDX, 0
  JE	_notValid
  CMP	EBX, NEGLIMIT		; neg limit is -2147483648, pos limit 2147483647
  JG	_notValid
  LODSB
  LOOP	_validate
  NEG	EBX

; Store integer in numArray and exit readVal
_store:
  MOV	[EDI], EBX

  POPAD
  POP	EBP
  RET	28

readVal ENDP

;----------------------------------------------------------------------------------------------------------------
; Name: writeVal
;
; Description: Receives an integer, converts it to a string, and calls mDisplayString to display the integer.
;
; Preconditions: The integer must be validated and stored in numArray.
;
; Postconditions: None
;
; Receives:
;			[EBP + 8]  = Offset of integer to convert and display
;			[EBP + 12] = Offset of revString to store the reversed converted string
;			[EBP + 16] = Offset of outString to store the corrected converted string
;
; Returns:
;			revString: the integer converted to a string in reverse order
;			outString: the integer converted to a string in corrected order
;
; ----------------------------------------------------------------------------------------------------------------
writeVal PROC

  PUSH	EBP
  MOV	EBP, ESP
  PUSHAD
  CLD

  ; Set up for conversion to string. If the integer is negative, add the negative
  ;		sign to the string and move to next character.
  MOV	EDI, [EBP + 12]		; revString
  MOV	EBX, [EBP + 8]		; offset integer to convert for display
  MOV	EAX, [EBX]			; value of integer
  CDQ
  MOV	EBX, 10				; used as a divisor to get each digit of the integer
  MOV	ECX, 0				; counter for the number of BYTEs converted
  CMP	EDX, 0				; check for negative number
  JE	_div				; not negative

  ; Set negative number to positive and add sign character to string
  NEG	EAX					
  MOV	EDX, 0
  PUSH	EAX
  MOV	EAX, 45				; - character
  STOSB
  POP	EAX
  INC	ECX

  ; Convert the integer to string characters, store characters in a string
_div:
  IDIV	EBX					; divide integer by 10 to get remainder
  PUSH	EAX					; save remaining numbers
  MOV	EAX, EDX			; remainder is the character we need to add to string
  ADD	EAX, 48				
  STOSB					
  POP	EAX					; retrieve the 'rest' of the number
  INC	ECX
  CDQ						; resets the remainder to 0
  CMP	EAX, 0				; check if any more of the integer is left
  JNE	_div
  MOV	AL, 0				; null terminator
  STOSB
  
  ; Set up for correcting the reversed string and check for - character
  MOV	ESI, [EBP + 12]		; offset reversed string
  MOV	EDI, [EBP + 16]		; offset corrected string
  MOV	EAX, [ESI]
  CMP	AL, 45				; check for - character
  JNE	_notNeg
  DEC	ECX
  MOVSB						; save the - character in the first index

  ; Moves the index to the end of the reversed string
_notNeg:
  ADD	ESI, ECX
  DEC	ESI

  ; Copy reversed string backwards into the corrected string
_rev:
  STD
  LODSB
  CLD
  STOSB
  LOOP	_rev
  MOV	AL, 0				; null terminator
  STOSB

  ; Display the converted, corrected string.
  mDisplayString [EBP + 16]

  POPAD
  POP	EBP
  RET	12
writeVal ENDP

;----------------------------------------------------------------------------------------------------------------
; Name: calculate
;
; Description: Calculates the sum and truncated average of all 10 integers entered by the user.
;
; Preconditions: All 10 user inputs must be validated, converted to integers, and saved in numArray.
;
; Postconditions: None
;
; Receives:
;			[EBP + 8]  = Offset sumInt to save the sum
;			[EBP + 12] = Offset of numArray
;			[EBP + 16] = Offset avgInt to save the avg
;
; Returns:
;			sumInt: the sum of all the integers
;			avgInt: the truncated average of all the integers
;
; ----------------------------------------------------------------------------------------------------------------
calculate PROC
  
  PUSH	EBP
  MOV	EBP, ESP
  PUSHAD

  ; Set up for calculating the average
  MOV	ESI, [EBP + 12]
  MOV	EBX, [EBP + 8]
  MOV	EAX, 0				; set temp num holder
  MOV	ECX, 10				; set counter for _getSum loop

  ; Calculate the sum
_getSum:
  ADD	EAX, [ESI]			; add current index to temp num holder
  ADD	ESI, 4				; next index
  LOOP	_getSum
  MOV	[EBX], EAX			; save sum in sumInt

  ; Calculate the average
_getAvg:
  MOV	EBX, 10				; set up the divisor
  CDQ
  IDIV	EBX					; divide sum by 10 (number of integers entered)
  MOV	EBX, [EBP + 16]
  MOV	[EBX], EAX			; move average to avgInt

  POPAD
  POP	EBP
  RET	12

calculate ENDP

END main
