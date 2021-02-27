###############################################################
#                                                             #
#  MAKEFILE for AIL development                               #             
#  13-Mar-91 John Miles                                       #
#                                                             #
#  Execute with Microsoft (or compatible) MAKE                #
#                                                             #
###############################################################

##########################################################################
#                                                                        #
# TASM: Case sensitivity on, enable multiple passes to optimize forward  #
#       references/jumps, generate debug info, enable all warnings       #
#                                                                        #
#   TC: Compile only, generate debug info, large memory model            #
#                                                                        #
##########################################################################

#
# Tandy 3-voice XMIDI driver
#

cms.mdi: mdiail2x.asm
  tasm /m /w+ /ml /dTASM /dCMS mdiail2x.asm
  tlink /tiny mdiail2x,cms.mdi,,,,

