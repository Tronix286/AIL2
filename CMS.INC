;DEBUG_CMS EQU 1

DetectCMS PROC
		IFDEF CMS
    ;-----------------------------
    ;    detect Game Blaster     :
    ;-----------------------------
CMS_TEST_CODE            EQU         0C6H

       MOV    DX,210h		       ; start detect from port 210h 

PROBE_IO:
       ADD    DL,6                     ; write the test code to
       MOV    AL,CMS_TEST_CODE         ;   output port 2x6H
       OUT    DX,AL                    ; ...
       SUB    AL,AL
       ADD    DL,4                     ; read the data back from
       OUT    DX,AL
       IN     AL,DX                    ;   input port 2xAH
       CMP    AL,CMS_TEST_CODE         ; the same data ?
       JNE    CARD10                   ; no

       SUB    DL,4                     ; to ensure, try inverse data
       MOV    AL,NOT CMS_TEST_CODE     ; output port 2x6H
       OUT    DX,AL                    ; ...
       SUB    AL,AL
       ADD    DL,4                     ; read the data back from
       OUT    DX,AL
       IN     AL,DX                    ;   input port 2xAH
       CMP    AL,NOT CMS_TEST_CODE     ; the same data ?
       JNE    CARD10                   ; no

       SUB    DX,10		       ; restore true base adrr (2xAh - 10 = DX)
       MOV    default_IO,dx	       ; save current port
       MOV    AX,1		       ; success
       RET
CARD10:
       
       ADD    DX,6		       ; next true base adrr (2xAh + 6 = DX)
       CMP    DX,270h                  ; port < 270h ?
       JNE    PROBE_IO
       XOR    AX,AX		       ; failed
       RET

	ENDIF
ENDP

cmsWrite	MACRO
		IFDEF CMS
;
;	parameters
;	dx = port base+offset
;	ah = register
;	al = data

		inc  dx
		xchg al,ah
		out  dx,al
		dec  dx
		xchg al,ah
		out  dx,al

		;ret

		ENDIF
		ENDM

cmsNull		PROC
		IFDEF CMS
;
;	parameters
;	dx = port offset to null

		add   dx,default_IO
		mov   cx,20h
		xor   ax,ax
loop_null:           ; null all 20 registers 
		cmsWrite
		inc   ah
		loop  loop_null

		mov   ax,01C02h ; reset chip 
		cmsWrite

		mov   ax,01C01h ; enable this chip 
		cmsWrite

		ret

		ENDIF
		ENDP

	
cmsReset	PROC
		IFDEF CMS
		mov  dx,0
		call cmsNull
		mov  dx,2
		call cmsNull
		ret

		ENDIF
		ENDP

		IFDEF CMS		
CmsSound	PROC voice_n,freq,octave,amplitudeLeft,amplitudeRight:WORD

; first get port base 
		mov   bx,voice_n

		IFDEF BEBUG_CMS
		cmp bl,0		; if channel < 0
		jb @no_valid_chan	; out of range
		cmp bl,11		; if channel > 11
		ja @no_valid_chan	; out of range
		ENDIF
		
		mov   dx,default_IO
		cmp   bl,06h		; check channel num > 5?
		jl    @setOctave	; yes - set port = port + 2
		add   dx,2
@setOctave:
		mov   bl,ChanReg[bx]	; bx = true channel (0 - 5)
		mov   ah,OctavReg[bx]   ; ah = Set octave command
;
;	ah now = register
;		0,1,6,7=$10
;		2,3,8,9=$11
;		4,5,10,11=$12
;
;	CMS octave regs are write only, so we have to track
;	the values in adjoining voices manually

		mov   al,ah
		xor   ah,ah		; ax = set octave cmd (10h - 12h)
		mov   di,ax		; di = ax
		sub   di,010h		; di = octave cmd - 10h (0..2 index)
		mov   cx,voice_n
		cmp   cl,06h
                jl    skip_inc
		add   di,3
skip_inc:
		mov   ah,al		; set ah back to octave cmd

		mov   al,CmsOctaveStore[di]
		mov   bh,byte ptr octave
		test  bl,01h
		jnz   @shiftOctave
		and   al,0F0h
		jmp   @outOctave
@shiftOctave:
		and   al,0Fh
		mov   cl,4
		shl   bh,cl
@outOctave:
		or    al,bh
		mov   CmsOctaveStore[di],al
		cmsWrite		; set octave to CMS
@setAmp:
		mov   al,byte ptr amplitudeLeft
		mov   ah,byte ptr amplitudeRight
		;and   al,0Fh
		mov   cl,4
		shl   ah,cl
		or    al,ah
		mov   ah,bl
		cmsWrite
@setFreq:
		mov   al,byte ptr freq
		or    ah,08h

		IFDEF DEBUG_CMS
		cmp   ah,0dh		; if set freq cmd > 0dh
		ja    @no_valid_chan    ; out of range
		ENDIF

		cmsWrite
@voiceEnable:
		mov   al,14h
		inc   dx
		out   dx,al
		dec   dx

		xor   di,di
		mov   cx,voice_n
		cmp   cl,06h
                jl    skip_inc2
		inc   di
skip_inc2:
		mov   al,ChanEnableReg[di]
		mov   ah,01h
		mov   cl,bl
		shl   ah,cl
		or    al,ah
		out   dx,al
		mov   ChanEnableReg[di],al
;		mov   ax,1C01h ; enable this chip again, cms on 386 bug?
;		call  cmsWrite
		ret

		IFDEF DEBUG_CMS
@no_valid_chan:
		mov al,ah
		mov ah,0
		call IntToAsc		; print al
		mov al,' '
		int 29h
		mov al,bl
		mov ah,0
		call IntToAsc		; print bl
		mov al,10
		int 29h
		mov al,13
		int 29h
		ret
		ENDIF

		ENDP
		ENDIF
