;#############################################################################
;##                                                                         ##
;##  MDINULL.ASM                                                            ##
;##                                                                         ##
;##  Miles Sound System Version 3                                           ##
;##                                                                         ##
;##  Null MIDI sound driver                                                 ##
;##                                                                         ##
;##  Version 1.00 of 11-Sep-94: Initial version for MSS 3.0                 ##
;##          1.01 of 16-Nov-94: Added 'ret' to FN_502H                      ##
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

DEVICE_NAME     equ <'No music'>

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

dev_configs     IO_PARMS <-1,-1,-1,-1, -1,-1,-1,-1>
N_CONFIGS       equ 1

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

                mov num_voices,-1

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

                mov caller_AX,1
                ret

FN_304H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 305H (Initialize Device)                                      ##
;##                                                                         ##
;#############################################################################

FN_305H         PROC

                mov caller_AX,1
                ret

FN_305H         ENDP

;#############################################################################
;##                                                                         ##
;##  Function 306H (Shut Down Device)                                       ##
;##                                                                         ##
;#############################################################################

FN_306H         PROC

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

;###############################################################################
;##                                                                         ##
;##  Function 501H (Initialize Instrument Manager)                          ##
;##                                                                         ##
;#############################################################################

FN_501H         PROC
                
                mov caller_AX,-1
                ret

FN_501H         ENDP

;###############################################################################
;##                                                                         ##
;##  Function 502H (Transmit MIDI Data)                                     ##
;##                                                                         ##
;#############################################################################

FN_502H         PROC
                
                mov caller_AX,1
                ret

FN_502H         ENDP

;###############################################################################
;##                                                                         ##
;##  Function 503H (Install Timbre Set)                                     ##
;##                                                                         ##
;#############################################################################

FN_503H         PROC

                mov caller_AX,-1
                ret

FN_503H         ENDP

;###############################################################################
;##                                                                         ##
;##  Function 504H (Get Timbre Status)                                      ##
;##                                                                         ##
;#############################################################################

FN_504H         PROC
                
                mov caller_AX,1
                ret

FN_504H         ENDP

;###############################################################################
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
