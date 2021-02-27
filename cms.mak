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
# Application Program Interface (API) module
#

ail.obj: ail.asm ail.inc ail.mac
   tasm /m /w+ /ml ail.asm;


#
# CMS
#

cms.adv: xmidi.asm spkr.inc ail.inc ail.mac
   tasm /zi /m /w+ /ml /dCMS xmidi.asm;
   tlink /c /x xmidi;
   exe2bin xmidi.exe cms.adv
   del xmidi.exe

