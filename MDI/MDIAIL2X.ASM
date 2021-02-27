;#############################################################################
;##                                                                         ##
;##  MDIAIL2X.ASM                                                           ##
;##                                                                         ##
;##  Miles Sound System Version 3                                           ##
;##                                                                         ##
;##  Compatibility shell for AIL 2.X real-mode MIDI interpreters            ##
;##                                                                         ##
;##  Version 1.00 of 21-Aug-94: Preliminary version for MSS 3.0             ##
;##          1.01 of  9-Sep-94: Enable IRQs while installing timbre set     ##
;##          1.02 of 26-Nov-94: SB drivers check BLASTER variable           ##
;##                                                                         ##
;##  Author: John Miles                                                     ##
;##                                                                         ##
;##  8086 ASM source compatible with MASM or TASM                           ##
;##                                                                         ##
;#############################################################################
;##                                                                         ##
;##    Porting an existing AIL 2.X MIDI interpreter .INC file to MSS 3.X    ##
;##컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�##
;##                                                                         ##
;##  - Rename the old driver's DDT symbol to DDT_2X                         ##
;##                                                                         ##
;##  - Delete the 'service_rate' definition in the DDT_2X structure         ##
;##                                                                         ##
;##  - Rename all occurrences of the following labels:                      ##
;##      IO_ADDR -> IO_PORT                                                 ##
;##      IRQ     -> INTR                                                    ##
;##                                                                         ##
;##  - Implement self-contained local timbre cache, if required             ##
;##                                                                         ##
;##  - (Optional) Implement RPN 00 00, MSB = pitch bend range in semitones  ##
;##                                                                         ##
;##  - (Optional) Implement General MIDI channelization (1-16, 10=drums)    ##
;##                                                                         ##
;##  - (Optional) Implement send_MIDI_sysex function, if applicable         ##
;##                                                                         ##
;#############################################################################
;##                                                                         ##
;##  Copyright (C) RAD Game Tools, Inc.                                     ##
;##                                                                         ##
;##  Contact RAD Game Tools at 425-893-4300 for technical support.          ##
;##                                                                         ##
;#############################################################################

                ;
                ;Device type equates
                ;

                IFDEF SBSTD
YM3812          equ 1
SBLASTER        equ 1
DEVICE_NAME     equ <'Creative Labs Sound Blaster or 100% compatible'>
                ENDIF

                IFDEF ADLIBSTD
YM3812          equ 1
DEVICE_NAME     equ <'Ad Lib Music Synthesizer Card or 100% compatible'>
                ENDIF

                IFDEF PAS
YM3812          equ 1
STEREO          equ 1
DEVICE_NAME     equ <'Media Vision Pro Audio Spectrum (old version)'>
                ELSEIFDEF PASOPL
YMF262          equ 1
STEREO          equ 1
DEVICE_NAME     equ <'Media Vision Pro Audio Spectrum (-Plus or -16)'>
                ENDIF

                IFDEF SBPRO1
YM3812          equ 1
STEREO          equ 1
SBLASTER        equ 1
DEVICE_NAME     equ <'Creative Labs Sound Blaster Pro (old version)'>
                ELSEIFDEF SBPRO2
YMF262          equ 1
STEREO          equ 1
SBLASTER        equ 1
DEVICE_NAME     equ <'Creative Labs Sound Blaster Pro (new version)'>
                ENDIF

                IFDEF GENOPL3
YMF262          equ 1
STEREO          equ 1
DEVICE_NAME     equ <'Generic Yamaha OPL3-based FM music synthesizer'>
                ENDIF

                IFDEF ADLIBG
YMF262          equ 1
STEREO          equ 1
DEVICE_NAME     equ <'Ad Lib Gold Music Synthesizer Card'>
                ENDIF

                IFDEF TANDY
SPKR            equ 1
DEVICE_NAME     equ <'Tandy 3-voice music'>
                ENDIF
                
                IFDEF CMS
SPKR            equ 1
DEVICE_NAME     equ <'CMS 12-voice'>
                ENDIF

                IFDEF IBMPC
SPKR            equ 1
DEVICE_NAME     equ <'IBM internal speaker music'>
                ENDIF

                IFDEF MT32
                IFDEF MPU401
DEVICE_NAME     equ <'Roland MT-32 MIDI with MPU-401 MIDI Interface'>
                ENDIF
                ENDIF

                ;
                ;Prologue and common driver functions
                ;

                INCLUDE mss_mdi.inc

                ;
                ;Driver description table (DDT)
                ;

DDT             LABEL WORD

library_env     dw ?
                dw ?

GTL_suffix      dw ?
                dw ?

num_voices      dw ?

max_melodic_ch  dw ?
min_melodic_ch  dw ?
percussion_ch   dw ?

                ;
                ;Driver state table (DST)
                ;

DST             LABEL WORD

library_dir     db 128 dup (?)
GTL_filename    db 128 dup (?)

MIDI_data       db 512 dup (?)

                ;
                ;Configuration data
                ;

                IFDEF SBLASTER

env_config        db 'BLASTER',0

                ENDIF

dev_configs     IO_PARMS <-1,-1,-1,-1, -1,-1,-1,-1>
N_CONFIGS       equ 1

suffix          db 8 dup (0)

;#############################################################################
;##                                                                         ##
;##  Compatibility data and procedures                                      ##
;##                                                                         ##
;#############################################################################

                ;
                ;MIDI and XMIDI controllers recognized by AIL drivers
                ;

CHAN_LOCK       equ 110                 ;General XMIDI controllers
CHAN_PROTECT    equ 111
VOICE_PROTECT   equ 112
TIMBRE_PROTECT  equ 113
PATCH_BANK_SEL  equ 114
INDIRECT_C_PFX  equ 115
FOR_LOOP        equ 116
NEXT_LOOP       equ 117
CLEAR_BEAT_BAR  equ 118
CALLBACK_TRIG   equ 119
SEQ_INDEX       equ 120

MODULATION      equ 1                   ;MIDI controllers and Channel Mode
DATA_MSB        equ 6                   ;messages recognized by AIL drivers
PART_VOLUME     equ 7                   
PANPOT          equ 10
EXPRESSION      equ 11
SUSTAIN         equ 64
RESET_ALL_CTRLS equ 121
ALL_NOTES_OFF   equ 123

                ;
                ;Macros used by AIL 2.X drivers (from AIL.MAC)
                ;

FAR_TO_HUGE     MACRO fp_seg,fp_off             ;normalize far pointer
                push ax bx             
                mov ax,fp_seg
                mov bx,fp_off
                shr bx,1
                shr bx,1
                shr bx,1
                shr bx,1
                add ax,bx
                mov fp_seg,ax
                and fp_off,0fh
                pop bx ax
                ENDM

ADD_PTR         MACRO add_l,add_h,pseg,poff     ;add 32-bit dword to far ptr
                push bx
                push cx
                mov bx,pseg
                xor cx,cx
                shl bx,1
                rcl cx,1
                shl bx,1
                rcl cx,1
                shl bx,1
                rcl cx,1
                shl bx,1
                rcl cx,1
                add bx,poff
                adc cx,0
                add bx,add_l
                adc cx,add_h
                mov poff,bx
                and poff,1111b
                shr cx,1
                rcr bx,1
                shr cx,1
                rcr bx,1
                shr cx,1
                rcr bx,1
                shr cx,1
                rcr bx,1
                mov pseg,bx
                pop cx
                pop bx
                ENDM

POP_F           MACRO                   ;avoid POPF bug on brain-dead 80286's
                LOCAL intel_bytes
                db 80h                  ;make an OR BH,00 instruction
intel_bytes:    iret
                db 00h
                push cs
                call intel_bytes
                ENDM

REP_MOVSB       MACRO                   ;do REP MOVSB with 16-bit transfers
                shr cx,1
                rep movsw
                adc cx,cx
                rep movsb
                ENDM

state_table     STRUC                   ;XMIDI compatibility state table   
TIMB            dd ?
state_table     ENDS

dummy_state     state_table <>

sequence_state  dd ?                    ;State array[0] -> dummy_state

GTL             dw -1                   ;GTL file handle

timbre_area     db 512 dup (0)          ;Timbre-loading area

;#############################################################################
;##                                                                         ##
;##  AIL 2.X-based MIDI interpreter module and options                      ##
;##                                                                         ##
;#############################################################################

NUM_CHANS       equ 16                  ;# of MIDI channels

DEF_PITCH_L     equ 00h
DEF_PITCH_H     equ 40h                 ;Default pitch bend = 4000h (mid-way)

                IFDEF MT32
                INCLUDE mt32.inc        ;Roland MT-32-compatible synthesizer
                ENDIF

                IFDEF YM3812
                INCLUDE yamaha.inc      ;Standard Ad Lib-style chipset
                ENDIF

                IFDEF YMF262
                INCLUDE yamaha.inc      ;YMF262 support for Ad Lib Gold et al.
                ENDIF

                IFDEF SPKR              
                INCLUDE spkr.inc        ;Internal speaker support for PC/Tandy
                ENDIF

;#############################################################################
;##                                                                         ##
;##  Function 300H (Initialize Driver)                                      ##
;##                                                                         ##
;##  Must call MDI_init in MSS_MDI.INC to initialize common driver          ##
;##  data, then set up variables which are specific to this driver          ##
;##                                                                         ##
;#############################################################################

FN_300H         PROC
                
                call MDI_init

                ;
                ;Call interpreter's AIL_describe_driver() handler to 
                ;validate default I/O settings, GTL suffix
                ;
                ;Also set up num_voices and channelization based on 
                ;interpreter equates
                ;

                call describe_driver C,0,0,0

                mov ax,default_IO
                mov bx,default_INTR
                mov cx,default_DMA

                mov dev_configs.IP_IO_ADDR,ax
                mov dev_configs.IP_IRQ,bx
                mov dev_configs.IP_DMA_8,cx

                mov ax,WORD PTR data_suffix
                mov dx,WORD PTR data_suffix+2

                mov BYTE PTR suffix,'.'
                mov WORD PTR suffix+1,ax
                mov WORD PTR suffix+3,dx

                ;
                ;Initialize DDT and remainder of VHDR
                ;

                mov library_env,0
                mov library_env+2,0

                mov GTL_suffix,OFFSET suffix

                mov num_voices,NUM_VOICES

                mov max_melodic_ch,MAX_REC_CHAN
                mov min_melodic_ch,MIN_REC_CHAN
                mov percussion_ch,10

                ;
                ;Initialize VHDR 
                ;

                mov common_configs,OFFSET dev_configs

                mov num_configs,N_CONFIGS

                IFDEF SBLASTER

                  mov ax,OFFSET env_config
                  mov env_name,ax

                ELSE

                  mov env_name,0
                  mov env_name+2,0

                ENDIF

                mov service_rate,-1

                ;
                ;Return success
                ;

                mov caller_AX,1
                ret

FN_300H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 301H (Get Driver Information)                                 ##
;##                                                                         ##
;#############################################################################

FN_301H         PROC

                mov caller_DX,cs
                mov caller_AX,OFFSET DDT

                mov caller_CX,cs
                mov caller_BX,OFFSET DST

                ret

FN_301H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 302H (Periodic Interrupt Service)                             ##
;##                                                                         ##
;#############################################################################

FN_302H         PROC

                mov caller_AX,-1
                ret

FN_302H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 303H (Parse Environment String)                               ##
;##                                                                         ##
;#############################################################################

FN_303H         PROC
                
                IFDEF SBLASTER

                  ;
                  ;Initialize VHDR.IO members to -1
                  ;
                  
                  cld
                  mov cx,SIZE IO_PARMS
                  mov di,OFFSET IO_ADDR
                  mov al,-1
                  rep stosb
                  
                  ;
                  ;Shift scratch string right one character and left-pad
                  ;with blank, to ensure leading space before first field
                  ;
                  
                  mov bx,OFFSET scratch+126
__shift:          mov al,[bx]
                  mov [bx+1],al
                  dec bx
                  cmp bx,OFFSET scratch-1
                  jne __shift
                  
                  mov scratch[0],' '
                  
                  ;
                  ;Expected BLASTER format: _A220 _I5 _D1 _H5 _P300 _T6
                  ;(_ = space)
                  ;
                  
                  mov bx,0
                  
__scan_string:    cmp bx,128
                  jae __parse_done
                  
                  cmp BYTE PTR scratch[bx],0
                  je __parse_done
                  
                  cmp WORD PTR scratch[bx],'A '
                  je __parse_A
                  
                  cmp WORD PTR scratch[bx],'a '
                  je __parse_A
                  
                  inc bx
                  jmp __scan_string
                  
__parse_A:        add bx,2
                  mov ax,16
                  call ASC_val
                  mov IO_ADDR,ax
                  jmp __scan_string
                  
__parse_done:     mov ax,IO_ADDR                  ;IO must be present
                  
                  mov caller_AX,ax                ;(-1 = 0ffffh)
                  ret

                ELSE

                  mov caller_AX,-1
                  ret

                ENDIF

FN_303H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 304H (Verify Device I/O Parameters)                           ##
;##                                                                         ##
;#############################################################################

FN_304H         PROC

                mov ax,IO_ADDR
                mov bx,IRQ
                mov cx,DMA_8

                call detect_device C,0,ax,bx,cx,-1

                mov caller_AX,ax

                ret

FN_304H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 305H (Initialize Device)                                      ##
;##                                                                         ##
;#############################################################################

FN_305H         PROC

                IFDEF set_IO_parms

                mov ax,IO_ADDR
                mov bx,IRQ
                mov cx,DMA_8

                call set_IO_parms C,ax,bx,cx,-1

                ENDIF

                IFDEF reset_interface
                call reset_interface
                ENDIF

                IFDEF init_interface
                call init_interface
                ENDIF

                call reset_synth
                call init_synth

                mov caller_AX,1
                ret

FN_305H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 306H (Shut Down Device)                                       ##
;##                                                                         ##
;#############################################################################

FN_306H         PROC

                call reset_synth

                IFDEF reset_interface
                call reset_interface
                ENDIF

                IFDEF shutdown_synth
                call shutdown_synth
                ENDIF

                mov bx,GTL
                cmp bx,-1
                je __exit

                mov ax,3e00h
                int 21h                 ;close GTL file if it exists

__exit:         mov caller_AX,1
                ret

FN_306H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 500H (Get/Set MIDI Hardware Volume)                           ##
;##                                                                         ##
;#############################################################################

FN_500H         PROC

                mov caller_AX,-1
                ret

FN_500H         ENDP

;###############################################################################
;##                                                                         ##
;##  Function 501H (Initialize Instrument Manager)                          ##
;##                                                                         ##
;#############################################################################

FN_501H         PROC
                
                mov dx,OFFSET GTL_filename

                mov bx,dx
                mov al,[bx]             ;make sure GTL filename is present
                cmp al,0
                je __no_GTL

                mov ax,3d00h            
                int 21h                 ;open GTL file in read-only mode
                jc __no_GTL

                mov GTL,ax
                jmp __exit              

__no_GTL:       mov GTL,-1

__exit:         mov caller_AX,1         ;call succeeds regardless of whether
                ret                     ;GTL file exists

FN_501H         ENDP

;###############################################################################
;##                                                                         ##
;##  Function 502H (Transmit MIDI Data)                                     ##
;##                                                                         ##
;#############################################################################

FN_502H         PROC
                LOCAL st,d1,d2,msgtype
                LOCAL event_len,event_type
                
                ;
                ;Exit if no MIDI messages to send
                ;

                mov di,caller_CX        ;DI = # of MIDI messages to send

                cmp di,0
                je __exit               ;exit if none

                mov si,OFFSET MIDI_data ;SI -> MIDI message list to send

                ;
                ;Fetch and send first byte
                ;

__for_message:  mov ax,0                
                mov bx,0
                mov cx,0
                
                mov al,[si]             ;AL = status/channel byte

                cmp al,0f0h             ;SysEx message?
                je __sysex
                cmp al,0f7h             ;Escape message?
                je __sysex

                inc si                  ;if not, index 1st data byte

                ;
                ;Send remainder of Channel Voice message
                ;

                mov bl,[si]             ;BL = 1st data byte
                inc si

                mov dl,al               
                and dl,0f0h             
                cmp dl,0c0h             ;Program Change (Cxh) = 1 data byte
                je __send_message
                cmp dl,0d0h             ;Channel Pressure (Dxh) = 1 data byte
                je __send_message

                mov cl,[si]             ;CL = 2nd data byte
                inc si

__send_message: call send_MIDI_message C,ax,bx,cx

__next_message: dec di
                jnz __for_message       ;do for all messages in list

                ;
                ;Exit w/success code when done
                ;

__exit:         mov caller_AX,1         ;exit w/success code when done
                ret

                ;
                ;Send System Exclusive or Escape message
                ;

__sysex:        push di                 ;save message count
                
                mov event_type,ax

                inc si                  ;adjust for type (F0 | F7) byte

                mov ax,0                ;get variable-length number
                mov dx,0
                jmp __calc_VLN
__shift_VLN:    mov cx,7
__mul_128:      shl ax,1
                rcl dx,1
                loop __mul_128
__calc_VLN:     mov cl,[si]
                inc si
                mov ch,cl
                and cl,7fh
                or al,cl
                or ch,ch
                js __shift_VLN

                mov di,si
                add si,ax              

                IFDEF send_MIDI_sysex
                call send_MIDI_sysex C,di,cs,event_type,ax
                ENDIF

                pop di                  ;recover message count and continue
                jmp __next_message

FN_502H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 503H (Install Timbre Set)                                     ##
;##                                                                         ##
;#############################################################################

FN_503H         PROC

                ;
                ;Enable interrupts since uploading process can be
                ;time-consuming
                ;

                sti

                ;
                ;Set up dummy state table to pass TIMB chunk address to
                ;interpreter via sequence_state[0]
                ;

                mov WORD PTR sequence_state,OFFSET dummy_state
                mov WORD PTR sequence_state+2,cs

                mov WORD PTR dummy_state.TIMB,OFFSET MIDI_data
                mov WORD PTR dummy_state.TIMB+2,cs

                ;
                ;Pass TIMB chunk to MIDI interpreter, and see if any
                ;new timbres are needed
                ;

__chk_request:  call get_request C,0,0

                ;
                ;Exit successfully if no more timbres requested
                ;

                cmp ax,0ffffh          
                je __success

                mov caller_BX,ax

                ;
                ;Otherwise, prepare to seek timbre definition by
                ;rewinding GTL file
                ;
                ;If GTL file handle not valid, fail call
                ;

                mov bx,GTL
                cmp bx,-1
                je __fail

                mov ax,4200h
                mov cx,0
                mov dx,0
                int 21h

                ;
                ;Read 6-byte GTL entry headers until requested
                ;timbre found
                ;

__read_entry:   mov ax,3f00h
                mov bx,GTL
                mov cx,6
                mov dx,OFFSET scratch
                int 21h

                ;
                ;If end of header list reached, fail call
                ;

                cmp BYTE PTR scratch[1],0ffh
                je __fail

                ;
                ;Is this the desired timbre entry?
                ;If not, continue searching
                ;

                mov ax,caller_BX
                cmp WORD PTR scratch[0],ax
                jne __read_entry

                ;
                ;Timbre header found -- seek to required offset in file
                ;and read timbre definition
                ;

                mov ax,4200h
                mov bx,GTL
                mov cx,WORD PTR scratch[4]
                mov dx,WORD PTR scratch[2]
                int 21h
                jc __fail

                mov ax,3f00h
                mov bx,GTL
                mov cx,SIZE timbre_area
                mov dx,OFFSET timbre_area
                int 21h

                ;
                ;Copy instrument to timbre cache
                ;

                mov ah,0
                mov al,BYTE PTR caller_BX

                mov bh,0
                mov bl,BYTE PTR caller_BX+1

                call install_timbre C,0,bx,ax,OFFSET timbre_area,cs

                ;
                ;Continue installing timbres...
                ;

                jmp __chk_request

__fail:         mov caller_AX,0
                ret

__success:      mov caller_AX,1
                ret

FN_503H         ENDP

;###############################################################################
;##                                                                         ##
;##  Function 504H (Get Timbre Status)                                      ##
;##                                                                         ##
;#############################################################################

FN_504H         PROC
                
                mov ax,caller_CX
                mov bx,ax
                
                and ax,0ffh
                shr bx,8

                call timbre_status C,0,bx,ax

                mov caller_AX,ax
                ret

FN_504H         ENDP

;###############################################################################
;##                                                                         ##
;##  Function 505H (Protect/Unprotect Timbre)                               ##
;##                                                                         ##
;#############################################################################

FN_505H         PROC
                
                mov ax,caller_CX
                mov bx,ax
                
                and ax,0ffh
                shr bx,8

                cmp caller_DX,0
                je __unprotect

                call protect_timbre C,0,bx,ax
                jmp __exit

__unprotect:    call unprotect_timbre C,0,bx,ax

__exit:         mov caller_AX,0
                ret

FN_505H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 506H (Vendor-Specific Extensions)                             ## 
;##                                                                         ##
;#############################################################################

FN_506H         PROC

                mov caller_AX,-1        ;No VSE functions available
                ret

FN_506H         ENDP

                END
