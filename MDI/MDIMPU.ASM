;#############################################################################
;##                                                                         ##
;##  MDIMPU.ASM                                                             ##
;##                                                                         ##
;##  Miles Sound System Version 3                                           ##
;##                                                                         ##
;##  MIDI sound driver for all MPU-401 General MIDI devices                 ##
;##                                                                         ##
;##  Version 1.00 of 29-May-94: Initial version for MSS 3.0                 ##
;##          1.12 of 24-Sep-94: Added DEVICE_NAME descriptor                ##
;##          1.13 of  5-Jun-95: Workaround for SB16 MIDI/digital DSP lockup ##
;##                                                                         ##
;##  Author: John Miles                                                     ##
;##                                                                         ##
;##  8086 ASM source compatible with MASM or TASM                           ##
;##                                                                         ##
;#############################################################################
;##                                                                         ##
;##  Copyright (C) RAD Game Tools, Inc.                                     ##
;##                                                                         ##
;##  Contact RAD Game Tools at 425-893-4300 for technical support.          ##
;##                                                                         ##
;#############################################################################

WB_FIX          equ 1        ;Use WaveBlaster hardware bug workaround

DEVICE_NAME     equ <'General MIDI (Roland MPU-401 interface or 100% compatible)'>

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
                ;Constant configuration data
                ;

dev_configs     IO_PARMS <330h,-1,-1,-1, -1,-1,-1,-1>
                IO_PARMS <320h,-1,-1,-1, -1,-1,-1,-1>
                IO_PARMS <300h,-1,-1,-1, -1,-1,-1,-1>
N_CONFIGS       equ 3

;#############################################################################
;##                                                                         ##
;##  Device-specific data and procedures                                    ##
;##                                                                         ##
;#############################################################################

DATA_IO         dw ?                    ;IO_addr
STAT_COM        dw ?                    ;IO_addr+1

;#############################################################################
;##                                                                         ##
;##  Write byte in AL to MPU-401 device                                     ##
;##                                                                         ##
;##  All registers preserved                                                ##
;##                                                                         ##
;#############################################################################

MPU_write       PROC

                push ax
                push dx
                push cx

                mov ah,al

                mov dx,STAT_COM
                mov cx,65535

__wait_cts:     in al,dx
                test al,40h
                je __write_it

                dec cx
                jz __allow_ISR

__chk_rcvr:     test al,80h
                jne __wait_cts

                pushf
                sti                     ;if MIDI byte incoming, give receiving
                mov dx,100h             ;process a chance to catch it ...
__pause:        dec dx                  ;prevents lost data and/or hangups
                jnz __pause             ;during Cakewalk and MIDIECHO
                popf

                mov dx,DATA_IO
                in al,dx

                mov dx,STAT_COM
                jmp __wait_cts

__write_it:     mov dx,DATA_IO

                mov al,ah
                out dx,al

                pop cx
                pop dx
                pop ax
                ret

__allow_ISR:    
                IF WB_FIX

                  pushf
                  sti                     ;allow SB16 digital section to service
                  mov cx,100h             ;interrupt if necessary
__pause_2:        dec cx                 
                  jnz __pause_2
                  popf

                ENDIF

                jmp __chk_rcvr

MPU_write       ENDP

;#############################################################################
;##                                                                         ##
;##  Send command in AL to MPU-401 device; returns AX = 1 if successful     ##
;##                                                                         ##
;##  All registers preserved (except AX)                                    ##
;##                                                                         ##
;##  Note: Only UART mode (3F) command used by AIL                          ##
;##                                                                         ##
;#############################################################################

MPU_send_cmd    PROC

                push cx
                push dx

                mov ah,al

                mov dx,STAT_COM

                mov cx,-1
__wait_cts_1:   in al,dx
                test al,40h
                jz __cts_1
                loop __wait_cts_1
                jmp __exit_bad

__cts_1:        mov al,ah
                out dx,al

                mov cx,-1

__wait_ack:     mov dx,STAT_COM
                in al,dx
                test al,80h
                jnz __next_loop

                mov dx,DATA_IO
                in al,dx
                cmp al,0feh
                je __exit_OK

__next_loop:    loop __wait_ack

__exit_bad:     mov ax,0
                jmp __exit

__exit_OK:      mov ax,1

__exit:         pop dx
                pop cx

                ret
MPU_send_cmd    ENDP

;#############################################################################
;##                                                                         ##
;##  Attempt to reset MPU-401 device                                        ##
;##                                                                         ##
;##  Returns 0 on failure; returns 1 on success                             ##
;##                                                                         ##
;##  Destroys all registers                                                 ##
;##                                                                         ##
;#############################################################################

MPU_reset       PROC                  

                mov ax,0ffh
                call MPU_send_cmd

                or ax,ax
                jne __exit_reset     

                mov ax,0ffh
                call MPU_send_cmd       ;retry once in case UART mode active

__exit_reset:   ret

MPU_reset       ENDP

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
                ;Initialize driver data
                ;

                mov ax,OFFSET dev_configs
                mov common_configs,ax

                mov num_configs,N_CONFIGS

                mov env_name,0
                mov env_name+2,0

                mov library_env,0
                mov library_env+2,0

                mov GTL_suffix,0
                mov GTL_suffix+2,0

                mov num_voices,-1       ;(# of voices manufacturer-dependent)

                mov max_melodic_ch,16
                mov min_melodic_ch,1
                mov percussion_ch,10

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
                
                mov caller_AX,-1
                ret

FN_303H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 304H (Verify Device I/O Parameters)                           ##
;##                                                                         ##
;#############################################################################

FN_304H         PROC

                ;
                ;Set I/O addresses
                ;

                mov ax,IO_ADDR

                mov DATA_IO,ax
                inc ax
                mov STAT_COM,ax

                ;
                ;Attempt to reset MPU-401 interface
                ;

                call MPU_reset

                mov caller_AX,ax

__exit:         ret

FN_304H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 305H (Initialize Device)                                      ##
;##                                                                         ##
;#############################################################################

FN_305H         PROC

                mov ax,3fh              ;assert MPU-401 UART mode
                call MPU_send_cmd

                mov caller_AX,1
                ret

FN_305H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 306H (Shut Down Device)                                       ##
;##                                                                         ##
;#############################################################################

FN_306H         PROC

                call MPU_reset
                
                mov caller_AX,1
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

;#############################################################################
;##                                                                         ##
;##  Function 501H (Initialize Instrument Manager)                          ##
;##                                                                         ##
;#############################################################################

FN_501H         PROC
                
                mov caller_AX,-1
                ret

FN_501H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 502H (Transmit MIDI Data)                                     ##
;##                                                                         ##
;#############################################################################

FN_502H         PROC
                
                cld

                ;
                ;Exit if no MIDI messages to send
                ;

                mov cx,caller_CX        ;get # of MIDI messages to send
                jcxz __exit             ;exit if none

                mov si,OFFSET MIDI_data ;SI -> MIDI message list to send

                ;
                ;Fetch and send first byte
                ;

__for_message:  mov ax,0
                lodsb                   ;get status/channel byte
                mov dx,ax               ;save it
                call MPU_write          ;send it

                cmp al,0f0h             ;SysEx message?
                je __sysex
                cmp al,0f7h             ;Escape message?
                je __sysex

                ;
                ;Send remainder of Channel Voice message
                ;

                lodsb                   ;get 1st data byte
                call MPU_write          ;send it

                mov ax,dx               ;recover status/channel byte
                and ax,0f0h             

                cmp ax,0c0h             ;Program Change (Cxh) = 1 data byte
                je __next_message
                cmp ax,0d0h             ;Channel Pressure (Dxh) = 1 data byte
                je __next_message

                lodsb                   ;get 2nd data byte
                call MPU_write          ;send it

__next_message: loop __for_message      ;do for all messages in list

                ;
                ;Exit w/success code when done
                ;

__exit:         mov caller_AX,1
                ret

                ;
                ;Send System Exclusive or Escape message
                ;
                ;F0 or F7 byte was already transmitted, so fetch
                ;length and transmit remainder of data block
                ;

__sysex:        push cx                 ;save message count
                
                mov ax,0                ;get DX:AX = variable-length number
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

                mov cx,ax               ;DX:AX = # of bytes in rest of message
__send_sysex:   lodsb                   ;SI -> rest of sysex message
                call MPU_write          
                loop __send_sysex
                
                pop cx                  ;recover message count and continue
                jmp __next_message

FN_502H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 503H (Install Timbre Set)                                     ##
;##                                                                         ##
;#############################################################################

FN_503H         PROC

                mov caller_AX,-1
                ret

FN_503H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 504H (Get Timbre Status)                                      ##
;##                                                                         ##
;#############################################################################

FN_504H         PROC
                
                mov caller_AX,-1
                ret

FN_504H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 505H (Protect/Unprotect Timbre)                               ##
;##                                                                         ##
;#############################################################################

FN_505H         PROC
                
                mov caller_AX,-1
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
