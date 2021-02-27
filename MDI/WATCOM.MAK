###############################################################
#                                                             #
#  MAKEFILE for MSS development                               #             
#  6-Jun-96 Jeff Roberts                                      #
#                                                             #
#  Watcom                                                     #
#                                                             #
#  Execute with wmake                                         #
#                                                             #
###############################################################


DEBUG=0
CAUSEWAY=1

TASMPATH=\devel\ta\
MASMPATH=\devel\masm\bin\
LINKPATH=\devel\msvc\bin\
CAUSEWAYPATH=\devel\libs\cause\

!ifneq CAUSEWAY 0
BIND1=$(CAUSEWAYPATH)le23p
BIND2=$(CAUSEWAYPATH)cwc
!else
BIND1=rem 
BIND2=rem 
!endif

!ifneq DEBUG 0
CMP=wcc386 /w9 /s /zq /we /zp1 /zm /bt=dos /d2 /5r -fpi87 -fp5
LINK=wlink op q op el d all system dos4g
!else
CMP=wcc386 /w9 /s /zq /we /zp1 /zm /bt=dos /5r /otexan -fpi87 -fp5
LINK=wlink op q op el system dos4g
!endif




all: mpu401.mdi mt32mpu.mdi adlib.mdi sblaster.mdi sbpro1.mdi sbpro2.mdi pas.mdi pasplus.mdi adlibg.mdi opl3.mdi tandy.mdi pcspkr.mdi null.mdi mditest.exe sample.ad fatman.ad



# ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
# Standard MPU-401 General MIDI
# ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

mpu401.mdi: mdimpu.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM mdimpu.asm
  $(LINKPATH)link /tiny mdimpu,mpu401.mdi,,,,

#
# General MIDI with Roland MPU-401-compatible interface XMIDI driver
#

#
# MT-32 family with Roland MPU-401-compatible interface XMIDI driver
#

mt32mpu.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dMT32 /dMPU401 mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,mt32mpu.mdi,,,,


#
# Standard Ad Lib / generic OPL2 XMIDI driver
#

adlib.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dADLIBSTD mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,adlib.mdi,,,,


#
# Standard Sound Blaster XMIDI driver
#

sblaster.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dSBSTD mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,sblaster.mdi,,,,


#
# Sound Blaster Pro I XMIDI driver
#

sbpro1.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dSBPRO1 mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,sbpro1.mdi,,,,


#
# Sound Blaster Pro II XMIDI driver
#

sbpro2.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dSBPRO2 mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,sbpro2.mdi,,,,


#
# Pro Audio Spectrum (original 8-bit dual-YM3812) XMIDI driver
#

pas.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dPAS mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,pas.mdi,,,,


#
# Pro Audio Spectrum-Plus or -16 (OPL3-based) XMIDI driver
#

pasplus.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dPASOPL mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,pasplus.mdi,,,,


#
# Ad Lib Gold XMIDI driver
#

adlibg.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dADLIBG mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,adlibg.mdi,,,,


#
# Generic OPL3 XMIDI driver (Tandy VIS, etc.)
#

opl3.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dGENOPL3 mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,opl3.mdi,,,,


#
# Tandy 3-voice XMIDI driver
#

tandy.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dTANDY mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,tandy.mdi,,,,


#
# IBM internal speaker XMIDI driver
#

pcspkr.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM /dIBMPC mdiail2x.asm
  $(LINKPATH)link /tiny mdiail2x,pcspkr.mdi,,,,


#
# Null XMIDI driver (used when sequencing without sound output is needed)
#

null.mdi: mdiail2x.asm
  $(TASMPATH)tasm /m /w+ /ml /dTASM mdinull.asm
  $(LINKPATH)link /tiny mdinull,null.mdi,,,,


# ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
# MDITEST validation program
# ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

mditest.exe: mditest.c ddk.obj ddkxmidi.bin
  $(CMP) mditest
  copy /b ddkxmidi.bin ddkxmidi.obj
  $(LINK) f mditest,ddk,ddkxmidi
  $(BIND1) mditest
  $(BIND2) mditest

ddk.obj: ..\dig\ddk.asm
  $(MASMPATH)ml /c /W0 /Cp /Zd /DDPMI ..\dig\ddk.asm

# ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
# the sample XMIDI patches
# ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

sample.ad: sample.cat sample.bnk
  ..\..\..\tools\dos\glib sample.cat
  copy /b sample.ad sample.opl

fatman.ad: fatman.cat fatman.bnk
  ..\..\..\tools\dos\glib fatman.cat
  copy /b fatman.ad fatman.opl


