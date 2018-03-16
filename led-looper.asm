; ====================================================
; LedLooper-with-Assembly Copyright(C) 2018 Furkan Türkal
; This program comes with ABSOLUTELY NO WARRANTY; This is free software,
; and you are welcome to redistribute it under certain conditions; See
; file LICENSE, which is part of this source code package, for details.
; ====================================================

; ======================PORTS=============================
; Ports to use
; ========================================================

; Template => LEDX -> PORTY-Z -> PIN W

; LED0 -> PORTC-0 -> 37
; LED1 -> PORTC-1 -> 36
; LED2 -> PORTC-2 -> 35
; LED3 -> PORTC-3 -> 34
; LED4 -> PORTC-4 -> 33
; LED5 -> PORTC-5 -> 32
; LED6 -> PORTC-6 -> 31
; LED7 -> PORTC-7 -> 30

; BTN1 -> PORTB-0 -> 53 -> H -> SPEED
; BTN2 -> PORTB-1 -> 52 -> Y -> DIRECTION
; BTN3 -> PORTB-2 -> 51 -> S -> COUNT

; ======================DEF CONSTS========================
; The .def variables to be held in Arduino's registers
; ========================================================

.def DATA = R16					; That definition to keep the temporary-register to be used for IN/OUT operations

.def LED_DIRECTION = R17		; That definition to keep the LED-direction-register
.def LED_COUNT = R19			; That definition to keep the LED-count-register
.def LED_SPEED = R20			; That definition to keep the LED-speed-register
.def LED_DATA = R21				; That definition to keep the LED-data-register
.def LED_DATA_PREV = R22		; That definition to keep the LED-data-prev-register


.def BTN_STATUS_INIT = R23		; That definition to keep the BUTTON-status-init-register
.def BTN_STATUS_CHANGED = R24	; That definition to keep the BUTTON-status-changed-register

.def BTN_STATUS_PINB = R25		; That definition to keep the BUTTON-status-pinb-register
								; That definition to keep the current status of the PINB's input
								
.def BTN_STATUS_TEMP = R26		; That definition to keep the BUTTON-status-temp-register
								; The temporary register to be used for comparison with the previous value of the PINB

; ======================ORG 0=============================
; JMP to MAIN
; ========================================================

.org 0
	rjmp MAIN

; ======================MAIN==============================
; Input/Output definitions for the Buttons and LEDs
; ========================================================

MAIN:							; MAIN function
    ldi DATA, 0xFF				; 0xFF = 1111 1111 -> Set all the bits 1

	ldi LED_DATA, 0x01			; The register indicating which bit LED's was HIGH
								; 0x00 = All of LOW
								; 0x01 = Only 0th LED was HIGH
								; 0x02 = Only 1st LED was HIGH
								; 0x03 = Only 0th and 1st LED was HIGH
								; ...
								
	ldi LED_DATA_PREV, 0x00		; The register that holds the LED_DATA in the previous loop
								; When you shift the previous LED_DATA, the new LED is added to the LED_DATA
								; More verbosely;
								; Before shifting LED_DATA check if you should add another LED bit
								; If no, just shift as above 
								; If yes, remember the old value of LED_DATA, shift LED_DATA as above, 
								; and then set LED_DATA = LED_DATA | prevLedData

	ldi LED_SPEED, 0x10			; The register that holds the LED loop-speed
								; Default: 0x10
								; If it falls, the speed was increases
								
	ldi LED_DIRECTION, 0x01		; The register that holds the LED rotation direction
								; Default: 0x01 --> 0x00 = Left, 0x01 = Right
								; The LEDs will turn towards the given direction
								
	ldi LED_COUNT, 0x01			; The register that holds the total enabled LED count
								; Default: 0x01 
								; Exactly led count calculation is : Min: 1, Max: 4 --> Clamp(LED_COUNT, 1, 4) 
	

	ldi BTN_STATUS_CHANGED, 0x00; The register that holds the Button press-status 
								; The value should change if button pressed
								; Default: 0x00
								; In case of pushing any button: it will be set as 0x01,
								; In case of pulling any button: it will be 0x00
								
	ldi BTN_STATUS_INIT, 0x07	; The register that holds the buttons first logic states (pressed or not state)
								; Default: 0x01 + 0x02 + 0x04 = 0x07
								; 1. Button -> 0x01,  2. Button -> 0x02, 3. Button -> 0x04


	out DDRC, DATA				; Set the Output all the pins of the PORTC (DATA = 0xFF)
	ldi DATA, 0x00				; Set DATA to 0x00
	out DDRB, DATA				; Clear the OUTPUT of all the pins of the DDRB (DATA = 0x00)
	ldi DATA, 0x07				; Set DATA to 0x07
	out PORTB,DATA				; Set the Output all the pins of the PORTB (DATA = 0x07)
	ldi DATA, 0x01				; Set DATA to 0x01

; ======================MAIN LOOP=========================
; Main program cycle, button call cycle, LED control cycle
; ========================================================

LOOP_MAIN:						; LOOP_MAIN function
	out PORTC, LED_DATA			; Out the PORTC, write to LED_DATA

	call LOOP_BUTTON			; CALL the LOOP_BUTTON function

	call DELAY					; CALL the DELAY function

	call LOOP_BUTTON			; CALL the LOOP_BUTTON function (again, double-check)

	cpi LED_DIRECTION, 0x01		; Compare LED_DIRECTION with 0x01
	brne SHIFT_RIGHT			; Return to SHIFT_RIGHT if LED_DIRECTION is NOT 0x01

	SHIFT_LEFT:					; Else, Return to SHIFT_LEFT
	lsl LED_DATA				; Logic-Shift-Left the LED_DATA
	brcc CARRY_0				; If the C bit is 0, so carry is not set
								; LSB not set, skip to setting the LSB (0000 0000 (C=0))
	ori LED_DATA, 1				; Perform OR operation with the current LED_DATA and 1
								; Current LED_DATA = 0000 0000
								; OR 1 = 0000 0001

	CARRY_0:					; Keep the MSB as 0
	rjmp LOOP_MAIN				; RJMP LOOP_MAIN

	SHIFT_RIGHT:				; Return to SHIFT_RIGHT if Z bit is 0
	lsr LED_DATA				; Logic-Shift-RIGHT the LED_DATA
	brcc CARRY_0				; If the C bit is not set, so MSB is not set, skip to setting the LSB
	ori LED_DATA, 0x80			; Perform OR operation with the current LED_DATA and 0x80
								; Current LED_DATA = 0000 0000
								; OR 0x80 = 1000 0000

	LOOP_END:					; LOOP_END function
	rjmp LOOP_MAIN				; RJMP LOOP_MAIN

; ======================BUTTON LOOP=======================
; Button Controller, (CHANGED-PUSHED-PULLED CONTROL)
; ========================================================

LOOP_BUTTON:					; LOOP_BUTTON function
	in BTN_STATUS_PINB, PINB	; Read input the buttons in the PINB and copy them to BTN_STATUS_PINB
	mov BTN_STATUS_TEMP, BTN_STATUS_PINB	; MOV the BTN_STATUS_PINB to BTN_STATUS_TEMP
	eor BTN_STATUS_PINB, BTN_STATUS_INIT	; To check if there is a changing button (If BTN_STATUS_PINB XOR BTN_STATUS_INIT == 1)
	mov BTN_STATUS_INIT, BTN_STATUS_TEMP	; MOV the BTN_STATUS_TEMP to BTN_STATUS_INIT
	breq BUTTON_NO							; Return to BUTTON_NO if Z bit cleared (If any BUTTON state has not changed)
	brne BUTTON_YES							; Eðer Z biti 1 ise yani BUTON durumlarý deðiþmiþ ise BUTTON_YES 'e dallan

	BUTTON_YES:
	cpi BTN_STATUS_PINB, 0x01;	; Compare BTN_STATUS_PINB with 0x01 (1st Button)
	breq BUTTON_CHANGED_SPEED	; Return to BUTTON_CHANGED_SPEED if BTN_STATUS_PINB is 0x01
	cpi BTN_STATUS_PINB, 0x02	; Compare BTN_STATUS_PINB with 0x02 (2th Button)
	breq BUTTON_CHANGED_DIRECTION	; Return to BUTTON_CHANGED_DIRECTION if BTN_STATUS_PINB is 0x02
	cpi BTN_STATUS_PINB, 0x04	; Compare BTN_STATUS_PINB with 0x04 (3th Button)
	breq BUTTON_CHANGED_SPEED	; Return to BUTTON_CHANGED_SPEED if BTN_STATUS_PINB is 0x04
	rjmp BUTTON_OK				; RJMP BUTTON_OK

	; [SPEED BUTTON] CHANGED-PUSHED-PULLED CONTROL

	BUTTON_CHANGED_SPEED:		; BUTTON_CHANGED_SPEED function
	cpi BTN_STATUS_CHANGED, 0x01; Compare BTN_STATUS_CHANGED with 0x01
	breq BUTTON_PULLED_SPEED	; Return to BUTTON_PULLED_SPEED if BTN_STATUS_CHANGED is 0x01
	brne BUTTON_PUSHED_SPEED	; Return to BUTTON_PUSHED_SPEED if BTN_STATUS_CHANGED is NOT 0x01

	BUTTON_PULLED_SPEED:		; BUTTON_PULLED_SPEED function			
	dec BTN_STATUS_CHANGED		; Set BTN_STATUS_CHANGED register to 0x00
	rjmp BUTTON_OK				; RJMP BUTTON_OK	

	BUTTON_PUSHED_SPEED:		; BUTTON_PUSHED_SPEED function
	inc BTN_STATUS_CHANGED		; Set BTN_STATUS_CHANGED register to 0x01
	CALL BUTTON_CLICK_SPEED		; CALL BUTTON_CLICK_SPEED
	rjmp BUTTON_OK				; RJMP BUTTON_OK

	; [DIRECTION BUTTON] CHANGED-PUSHED-PULLED CONTROL

	BUTTON_CHANGED_DIRECTION:	; BUTTON_CHANGED_DIRECTION function
	cpi BTN_STATUS_CHANGED, 0x01; Compare BTN_STATUS_CHANGED with 0x01
	breq BUTTON_PULLED_DIRECTION; Return to BUTTON_PULLED_DIRECTION if BTN_STATUS_CHANGED is 0x01
	brne BUTTON_PUSHED_DIRECTION; Return to BUTTON_PUSHED_DIRECTION if BTN_STATUS_CHANGED is NOT 0x01

	BUTTON_PULLED_DIRECTION:	; BUTTON_PULLED_DIRECTION function
	dec BTN_STATUS_CHANGED		; Set BTN_STATUS_CHANGED register to 0x00
	rjmp BUTTON_OK				; RJMP BUTTON_OK

	BUTTON_PUSHED_DIRECTION:
	inc BTN_STATUS_CHANGED		; Set BTN_STATUS_CHANGED register to 0x01
	CALL BUTTON_CLICK_DIRECTION	; CALL BUTTON_CLICK_DIRECTION function
	rjmp BUTTON_OK				; RJMP BUTTON_OK

	; [COUNT BUTTON] CHANGED-PUSHED-PULLED CONTROL

	BUTTON_CHANGED_SPEED:		; BUTTON_CHANGED_SPEED function
	cpi BTN_STATUS_CHANGED, 0x01; Compare BTN_STATUS_CHANGED with 0x01
	breq BUTTON_PULLED_SPEED	; Return to BUTTON_PULLED_SPEED if BTN_STATUS_CHANGED is 0x01
	brne BUTTON_PUSHED_SPEED	; Return to BUTTON_PUSHED_SPEED if BTN_STATUS_CHANGED is NOT 0x01

	BUTTON_PULLED_SPEED:		; BUTTON_PULLED_SPEED function
	dec BTN_STATUS_CHANGED		; Set BTN_STATUS_CHANGED register to 0x00
	rjmp BUTTON_OK				; RJMP BUTTON_OK

	BUTTON_PUSHED_SPEED:		; BUTTON_PUSHED_SPEED function
	inc BTN_STATUS_CHANGED		; Set BTN_STATUS_CHANGED register to 0x01
	CALL BUTTON_CLICK_COUNT		; CALL BUTTON_CLICK_COUNT function
	rjmp BUTTON_OK				; RJMP BUTTON_OK


	BUTTON_OK:					; BUTTON_OK function
	BUTTON_NO:					; BUTTON_NO
	ret							; Return from the function

; ======================SPEED BUTTON======================
; Functions that change the speed of the running LEDs
; ========================================================

BUTTON_CLICK_SPEED:				; LED_SPEED change function				
	cpi LED_SPEED, 0x04			; Compare LED_SPEED with 0x20
	breq SPEED_RESET			; Return to SPEED_RESET if LED_SPEED is 0x20
	brne SPEED_INCREASE			; Return to SPEED_INCREASE if LED_SPEED is NOT 0x20
	SPEED_RESET:				; SPEED_RESET function
	ldi LED_SPEED, 0x10			; Load Immediate the LED_SPEED to 0x04
	rjmp SPEED_END				; RJMP SPEED_END
	SPEED_INCREASE:				; SPEED_INCREASE function
	lsr LED_SPEED				; Logic-Shift-Right the LED_SPEED (multiply by 2)
	SPEED_END:					; SPEED_END function
	rjmp LOOP_MAIN				; RJMP LOOP_MAIN

; ======================DIRECTION BUTTON==================
; Functions that change the working direction of the running LEDs
; ========================================================

BUTTON_CLICK_DIRECTION:			; LED_DIRECTION change function	
	cpi LED_DIRECTION, 0x00		; Compare LED_DIRECTION with 0x00
	brne LED_DIRECTION_LEFT		; Return to LED_DIRECTION_LEFT if LED_SPEED is NOT 0x20
	LED_DIRECTION_RIGHT:		; LED_DIRECTION_RIGHT function (if LED_SPEED is 0x20)
	ldi LED_DIRECTION, 0x01		; Load Immediate the LED_DIRECTION to 0x01
	rjmp LED_DIRECTION_END		; RJMP LED_DIRECTION_END
	LED_DIRECTION_LEFT:			; LED_DIRECTION_LEFT function
	ldi LED_DIRECTION, 0x00		; Load Immediate the LED_DIRECTION to 0x00
	LED_DIRECTION_END:			; LED_DIRECTION_END function
	rjmp LOOP_MAIN				; RJMP LOOP_MAIN

; ======================LED COUNT BUTTON==================
; Functions that regulate the total number of running LEDs
; ========================================================

BUTTON_CLICK_COUNT:				; BUTTON_CLICK_COUNT function
	inc LED_COUNT				; Increment by 1 the LED_COUNT
	cpi LED_COUNT, 0x05			; Compare LED_COUNT with 0x05
	breq COUNT_RESET			; Return to COUNT_RESET if LED_SPEED is 0x05
	rjmp COUNT_SHIFT			; Else, RJMP the COUNT_SHIFT
	COUNT_RESET:				; Otherwise, call COUNT_RESET function 
	ldi LED_COUNT, 0x01			; Load Immediate the LED_COUNT to 0x01
	
	mov LED_DATA_PREV, LED_DATA ; MOV the LED_DATA to LED_DATA_PREV

	NEG LED_DATA				; Take the LED_DATA's two's complement.
								; In this case, only 1 bit logic-1 will be
	AND LED_DATA, LED_DATA_PREV ; AND the LED_DATA with LED_DATA_PREV, Then write result to LED_DATA 
								; Only 1 bit LED will be lit


	ldi LED_DATA_PREV, 0x00		; Load Immediate the LED_DATA_PREV to 0x00
	rjmp COUNT_END				; RJMP LOOP_MAIN
	COUNT_SHIFT:				; COUNT_SHIFT function
	mov LED_DATA_PREV, LED_DATA ; MOV the LED_DATA to LED_DATA_PREV

	cpi LED_DIRECTION, 0x01		; Compare LED_DIRECTION with 0x01
	brne ADD_RIGHT				; Return to ADD_RIGHT if LED_DIRECTION is NOT 0x01
	
	ADD_LEFT:					; Else, CALL ADD_LEFT
	lsl LED_DATA				; Logic-Shift-Left the LED_DATA
	brcc CARRY_00				; Branch the CARRY_00 is carry cleared
	ori LED_DATA, 1				; Else, Perform OR operation with the current LED_DATA and 0x01, and lit the 0th LED


	CARRY_00:					; CARRY_00 function 					
	or LED_DATA, LED_DATA_PREV 	; Perform OR operation with the current LED_DATA and LED_DATA_PREV, so in any case new LED will be added
	rjmp LOOP_MAIN				; RJMP LOOP_MAIN
		
	ADD_RIGHT:
	lsr LED_DATA				; Logic-Shift-Right the LED_DATA
	brcc CARRY_00				; Return the CARRY_00, If carry cleared, 
	ori LED_DATA, 0x80			; Else, Perform OR operation with the current LED_DATA and 0x80
	

	COUNT_END:					; COUNT_END function
	rjmp LOOP_MAIN				; RJMP LOOP_MAIN

; ======================DELAY=============================
; Delay function
; ========================================================

DELAY:				; Our delay function
   push r16			; We need to use loop_main's r16 and r17's values in delay_ms function
   push r17			; Using the push command, we record the values inside these registers into stack
   
   mov r16,LED_SPEED; Run the loop LED_SPEED times
   ldi r17,0x00 	; Run the ~12 million command cycle
   ldi r18,0x00 	; ~0.7s time delay will be obtained for 16Mhz working frequency
_w0:
   dec r18			; Decrement by 1 the r18's value 
   brne _w0			; If the result of reduction is not 0, return _w0 branch
   dec r17			; Decrement by 1 the r17's value 
   brne _w0			; If the result of reduction is not 0, return _w0 branch
   dec r16			; Decrement by 1 the r16's value 
   brne _w0			; If the result of reduction is not 0, return _w0 branch
   pop r17			; Pop the latest pushed r17 before returning from function
   pop r16			; Pop the latest pushed r16 before returning from function
   ret				; Return from the function


