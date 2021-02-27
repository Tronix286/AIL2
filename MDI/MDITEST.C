//############################################################################
//##                                                                        ##
//##  Miles Sound System                                                    ##
//##                                                                        ##
//##  MDITEST.C: MIDI sound driver test bed                                 ##
//##                                                                        ##
//##  Source compatible with 32-bit 80386 C/C++                             ##
//##                                                                        ##
//##  Version 1.00 of 29-May-94: Initial                                    ##
//##          1.12 of 24-Sep-94: Added device name display                  ##
//##                                                                        ##
//##  Author: John Miles                                                    ##
//##                                                                        ##
//############################################################################
//##                                                                        ##
//##  Copyright (C) RAD Game Tools, Inc.                                    ##
//##                                                                        ##
//##  Contact RAD Game Tools at 425-893-4300 for technical support.         ##
//##                                                                        ##
//############################################################################

#define VERSION "1.12"

#include "stdlib.h"
#include "stdio.h"
#include "string.h"
#include "conio.h"
#include "dos.h"
#include <io.h>
#include <sys\types.h>
#include <sys\stat.h>
#include <fcntl.h>

#define MSS_H
#include "..\..\..\..\include\mss.h"

#include "mdi_ddk.h"

AIL_DRIVER drvr;

LONG driver_valid;
LONG XMI_valid;

typedef union
   {
   signed char *S8;
   UBYTE       *U8;
   WORD        *S16;
   UWORD       *U16;
   LONG        *S32;
   ULONG       *U32;
   void        *V;
   }
FLEX_PTR;

/****************************************************************************/
void *mem_alloc(ULONG bytes)
{
   void *ptr;

   ptr = malloc(bytes);

   if (ptr == NULL)
      {
      printf("\nError: Out of memory\n");
      exit(1);
      }

   return ptr;
}

/****************************************************************************/
LONG file_size(BYTE *filename)
{
   LONG handle;
   LONG len;

   handle = open(filename,O_RDONLY | O_BINARY);
   if (handle==-1)
      {
      printf("\nError: Could not open file '%s'\n",filename);
      exit(1);
      }

   len = filelength(handle);

   close(handle);
   return len;
}

/****************************************************************************/
void *read_file(BYTE *filename, void *dest)
{
   LONG i,handle;
   LONG len;
   BYTE *buf, *mem;

   len = file_size(filename);
   if (len==-1L)
      {
      printf("\nError: Could not open file '%s'\n",filename);
      exit(1);
      }

   buf = mem = (dest==NULL)? mem_alloc(len) : dest;

   handle = open(filename,O_RDONLY | O_BINARY);

   i = read(handle,buf,len);

   if (i != len)
      {
      free(mem);
      printf("\nError: Could not read file '%s'\n",filename);
      exit(1);
      }

   close(handle);
   return mem;   
}

/****************************************************************************/
void locate(ULONG x, ULONG y)
{
   union REGS inregs,outregs;

   inregs.h.ah = 0x0f;
   int386(0x10,&inregs,&outregs);

   inregs.h.ah = 0x02;
   inregs.h.dh = (UBYTE) y;
   inregs.h.dl = (UBYTE) x;
   inregs.h.bh = outregs.h.bh;
   int386(0x10,&inregs,&outregs);
}

/****************************************************************************/
void curpos(ULONG *x, ULONG *y)
{
   union REGS inregs,outregs;

   inregs.h.ah = 0x0f;
   int386(0x10,&inregs,&outregs);

   inregs.h.bh = outregs.h.bh; inregs.h.ah = 0x03;
   int386(0x10,&inregs,&outregs);

   if (x != NULL)
      *x = (ULONG) outregs.h.dl;

   if (y != NULL)
      *y = (ULONG) outregs.h.dh;
}

/****************************************************************************/
void fill_text_line(LONG code)
{
   UWORD *screen;
   ULONG x,y;
   
   screen = (UWORD *) (((*(WORD *) 0x463L) == 0x3b4) ? 0xb0000L : 0xb8000L);

   curpos(NULL,&y);

   if ((UBYTE) y == *(UBYTE *) 0x484)
      {
      printf("\n");

      locate(0,--y);
      }

   for (x=0; x < 80; x++)
      {
      screen[(80*y)+x] = (UWORD) (code & 0xffff);
      }
}

/****************************************************************************/
LONG menu_choice(BYTE *title, BYTE **choices, BYTE *prompt, LONG *valid, LONG count)
{
   LONG i,n;

   printf("%s",title);

   for (i=1; i <= count; i++)
      {
      fill_text_line((valid == NULL) || valid[i] ? 0x0f20 : 0x0120);

      printf("%u) %s\n",i,choices[i]);
      }

   printf("%s",prompt);

   do
      {
      n = getch();

      if (n == 27)
         {
         printf("None                  \n");
         exit(0);
         }

      n -= '0';
      }
   while (((n < 0) || (n > count)) || ((valid != NULL) && (!valid[n])));

   printf("%d\n",n);

   return n;
}

/****************************************************************************/
void shutdown_proc(void)
{
   DDK_shutdown();

   if (XMI_valid)
      {
      XMI_shutdown();
      }

   if (driver_valid)
      {
      driver_valid = 0;

      DDK_call_driver(&drvr, DRV_SHUTDOWN_DEV, NULL, NULL);
      }
}

/****************************************************************************/
void cdecl serve_proc(void)
{
   if (!drvr.VHDR->busy)
      {
      DDK_call_driver(&drvr, DRV_SERVE, NULL, NULL);
      }
}

/****************************************************************************/
void register_driver(AIL_DRIVER *drvr)
{
   VDI_CALL VDI;

   //
   // Set up pointer to driver's VDI header
   //  

   drvr->VHDR = drvr->buf;

   //
   // Initialize driver variables
   //

   drvr->VHDR->busy       = 0;
   drvr->VHDR->driver_num = 0;

   //
   // Link driver into INT 66H chain after current ISR
   //

   drvr->VHDR->prev_ISR = DDK_get_real_vect(0x66);

   DDK_set_real_vect(0x66, drvr->seg + drvr->VHDR->this_ISR);

   //
   // Identify driver type and call initialization functions
   //

   if (!strnicmp(drvr->VHDR->ID,"AIL3MDI",7))
      {
      drvr->type = AIL3MDI;
      }
   else if (!strnicmp(drvr->VHDR->ID,"AIL3MDI",7))
      {
      drvr->type = AIL3MDI;
      }
   else
      {
      drvr->type = -1;
      }

   DDK_call_driver(drvr, DRV_INIT,     NULL, NULL);
   DDK_call_driver(drvr, DRV_GET_INFO, NULL, &VDI);

   drvr->DDT = (void *) (((ULONG) VDI.DX << 4) + (ULONG) VDI.AX);
   drvr->DST = (void *) (((ULONG) VDI.CX << 4) + (ULONG) VDI.BX);
}

/****************************************************************************/
LONG show_IO_parms(IO_PARMS *IO)
{
   LONG i,l;

   if (IO->IO == -1)
      printf("                                IO: Don't care\n");
   else
      printf("                                IO: %04XH        \n",
         IO->IO);

   if (IO->IRQ == -1)
      printf("                               IRQ: Don't care\n");
   else
      printf("                               IRQ: %d           \n",
         IO->IRQ);

   if (IO->DMA_8_bit == -1)
      printf("                             DMA 8: Don't care\n");
   else
      printf("                             DMA 8: %d           \n",
         IO->DMA_8_bit);

   if (IO->DMA_16_bit == -1)
      printf("                            DMA 16: Don't care\n");
   else
      printf("                            DMA 16: %d           \n",
         IO->DMA_16_bit);

   l = 4;

   for (i=0;i<4;i++)
      {
      if (IO->IO_reserved[i] != -1)
         {
         printf("                             RSV %u: %d          \n",i,
            IO->IO_reserved[i]);

         l++;
         }
      }

   return l;
}

/****************************************************************************/
//
// MIDI message transmission routines called by XMIDI API
//
/****************************************************************************/

ULONG message_cnt;
ULONG buffer_ptr;

void cdecl MIDI_flush_buffer(void)
{
   VDI_CALL VDI;

   if (message_cnt > 0)
      {
      VDI.CX = (WORD) message_cnt;

      DDK_call_driver(&drvr, MDI_MIDI_XMIT, &VDI, NULL);

      message_cnt = 0;
      buffer_ptr  = 0;
      }
}

void cdecl MIDI_message(ULONG status, ULONG d1, ULONG d2)
{
   ULONG size;

   switch (status & 0xf0)
      {
      case 0x80: 
      case 0x90:
      case 0xa0:
      case 0xb0:
      case 0xe0: size = 3; break;

      case 0xc0:
      case 0xd0: size = 2; break;

      default  : return;
      }

   if ((buffer_ptr + size) > 512)
      {
      MIDI_flush_buffer();
      }

   drvr.DST->MIDI_data[buffer_ptr++] = (BYTE) (status & 0xff);
   drvr.DST->MIDI_data[buffer_ptr++] = (BYTE) (d1     & 0xff);

   if (size == 3)
      drvr.DST->MIDI_data[buffer_ptr++] = (BYTE) (d2  & 0xff);

   ++message_cnt;
}
/****************************************************************************/
void main(LONG argc, BYTE *argv[])
{
   LONG        n,vol;
   ULONG       x,y,i;
   LONG        IO_valid,try_config,found;
   LONG        valid[10];
   BYTE       *choice[10];
   LONG        n_bytes,n_paras;
   IO_PARMS    IO;
   union REGS  inregs,outregs;
   BYTE       *envname;
   BYTE       *envval;
   VDI_CALL    VDI;
   HTIMER      timer;
   HTIMER      XMI_timer;
   HSEQUENCE   hseq;
   void       *state_table;

   setbuf(stdout,NULL);

   printf("\nMDITEST - Version " MSS_VERSION ".           " MSS_COPYRIGHT "\n");
   printf("-------------------------------------------------------------------------------\n");

   if ((argc == 1) || (argv [argc-1] [strlen(argv[argc-1])-1] == '?'))
      {
      printf("\nMDITEST validates all basic playback functions of MSS 3.0 MIDI sound drivers.\n\n");

      printf("Usage: MDITEST driver.MDI\n");
      exit(1);
      }

   //
   // Initialize globals
   //

   driver_valid = 0;
   XMI_valid    = 0;
   message_cnt  = 0;
   buffer_ptr   = 0;

   //
   // Get size of driver file
   //

   n_bytes = file_size(argv[1]);

   n_paras = (n_bytes+16) / 16;

   //
   // Allocate a buffer for the driver in real-mode (lower 1MB) memory
   //

   inregs.x.eax = 0x100;
   inregs.x.ebx = n_paras;

   int386(0x31,&inregs,&outregs);

   if (outregs.x.cflag)
      {
      printf("\nError: Insufficient DOS memory available\n");
      exit(1);
      }

   drvr.seg = outregs.x.eax << 16;
   drvr.buf = (void *) (outregs.x.eax * 16);

   //
   // Read the entire driver file into memory
   //

   drvr.buf = read_file(argv[1],drvr.buf);

   //
   // Start up API
   // 

   DDK_startup();

   //
   // Register shutdown procedure
   //

   atexit(shutdown_proc);

   //
   // Register driver with API
   //

   register_driver(&drvr);

   //
   // Display device name
   //

   printf("\nDevice name: %s\n",drvr.VHDR->dev_name);

   printf("\n             Driver revision level: %X\n",drvr.VHDR->driver_version);

   //
   // Copy library environment string to DST, if requested
   //

   printf("      Library environment variable: ");

   envname = REALPTR(drvr.DDT->library_environment);

   if ((envname == NULL) || (envname[0] == 0))
      {
      printf("(None)\n");
      }
   else
      {
      envval = getenv(envname);
      
      printf("%s\n",envname);

      if ((envval == NULL) || (envval[0] == 0))
         {
         printf("Warning: Library variable not present in DOS environment\n");
         }
      else
         {
         printf("      Instrument library directory: [%s]\n",envval);

         strncpy(drvr.DST->library_directory,envval,128);
         }   
      }

   //
   // Copy AIL 2.X GTL filename to DST, if requested
   //
   // (MDITEST test bed program uses FATMAN.XXX GTL filenames)
   //

   printf("                    MSS GTL suffix: ");

   envname = REALPTR(drvr.DDT->GTL_suffix);

   if ((envname == NULL) || (envname[0] == 0))
      {
      printf("(None)\n");
      }
   else
      {
      strcpy(drvr.DST->GTL_filename,"FATMAN");
      strcat(drvr.DST->GTL_filename,envname);

      printf("%s (%s)\n",envname,drvr.DST->GTL_filename);
      }

   //
   // Read configuration from environment variable, if available -- 
   // else get first "common configuration" if available
   //

   printf("Configuration environment variable: ");

   envname = REALPTR(drvr.VHDR->environment_string);

   if ((envname == NULL) || (envname[0] == 0))
      {
      printf("(None)\n");

      IO_valid = 0;
      }
   else
      {
      printf("%s\n",envname);

      envval = getenv(envname);

      if ((envval == NULL) || (envval[0] == 0))
         {
         printf("Warning: Configuration variable not present in DOS environment\n");

         IO_valid = 0;
         }
      else
         {
         printf("      Configuration variable value: [%s]\n",envval);

         strncpy(drvr.VHDR->scratch,envval,128);

         if (DDK_call_driver(&drvr, DRV_PARSE_ENV, NULL, NULL) == -1)
            {
            printf("Error: %s variable could not be parsed\n",envname);
            exit(1);
            }

         IO = drvr.VHDR->IO;

         show_IO_parms(&IO);

         IO_valid = 1;
         }
      }

   try_config = 0;

   if (drvr.VHDR->num_IO_configurations)
      {
      if (!IO_valid)
         {
         IO = ((IO_PARMS *)
               (REALPTR(drvr.VHDR->common_IO_configurations)))[try_config++];

         IO_valid = 1;
         }
      }

   //
   // Try to detect using current IO member; on failure, try next most-
   // common configuration
   //

   found = 0;

   while (1)
      {
      printf("       Attempting I/O verification:\n");

      if (IO_valid)
         i = show_IO_parms(&IO) + 1;
      else
         i = 1;

      if (found)
         break;

      curpos(&x,&y);
      locate(x,y-i);

      drvr.VHDR->IO = IO;

      if ((n = DDK_call_driver(&drvr, DRV_VERIFY_IO, &VDI, NULL)) != 0)
         {
         printf("       Attempting I/O verification: Found (result=%X)     \n",
            n & 0xffff);

         IO = drvr.VHDR->IO;

         found = 1;
         }
      else
         {
         printf("       Attempting I/O verification: Not found             \n");
         }

      if (!found)
         {
         if (try_config >= drvr.VHDR->num_IO_configurations)
            {
            locate(x,y);

            printf("Error: Device verification unsuccessful\n");
            exit(1);
            }
         else
            {
            IO = ((IO_PARMS *)
                  (REALPTR(drvr.VHDR->common_IO_configurations)))[try_config++];

            IO_valid = 1;
            }
         }

      locate(x,y-i);
      }

   //
   // Initialize device
   //

   printf("               Initializing device: ");

   DDK_call_driver(&drvr, DRV_INIT_DEV, NULL, NULL);

   printf("Done\n");

   driver_valid = 1;

   //
   // Initialize instrument manager
   //

   printf("   Initializing instrument manager: ");

   DDK_call_driver(&drvr, MDI_INIT_INS_MGR, NULL, &VDI);

   switch (VDI.AX)
      {
      default:
         printf("Invalid return code\n");
         exit(1);

      case -1:
         printf("Not supported\n");
         break;

      case 1:
         printf("Done\n");
         break;

      case 0:
         printf("Failed\n");
         exit(1);
      }

   //
   // Arrange for timer callback service, if requested
   //

   if (drvr.VHDR->service_rate > 0)
      {
      printf("            Service rate requested: %u Hz\n",
         drvr.VHDR->service_rate);

      timer = DDK_register_timer(serve_proc);
      DDK_set_timer_frequency(timer,drvr.VHDR->service_rate);
      DDK_start_timer(timer);
      }

   //
   // Initialize XMIDI API
   //

   printf("            Initializing XMIDI API: ");

   XMI_init();

   printf("Done\n");

   XMI_valid = 1;

   //
   // Arrange for XMIDI timer service
   //

   printf("               XMIDI timer service: 120 Hz\n");

   XMI_timer = DDK_register_timer(XMI_serve);
   DDK_set_timer_frequency(XMI_timer,120);
   DDK_start_timer(XMI_timer);

   //
   // Register test sequence
   //

   printf("        Registering XMIDI sequence: ");

   state_table = mem_alloc(XMI_state_table_size());

   hseq        = XMI_register_sequence(read_file("..\\..\\\media\\title.xmi",NULL),
                                       0,
                                       state_table,
                                       NULL);

   printf("Done\n");

   //
   // Install timbre set
   //

   printf("    Installing sequence timbre set: ");

   memmove(drvr.DST->MIDI_data,
           XMI_TIMB_address(hseq),
           512);

   DDK_call_driver(&drvr, MDI_INSTALL_T_SET, NULL, &VDI);

   switch (VDI.AX)
      {
      default:
         printf("Invalid return code\n");
         exit(1);

      case -1:
         printf("Not supported\n");
         break;

      case 1:
         printf("Done\n");
         break;

      case 0:
         printf("Error -- bank %d, patch %d\n",
            VDI.BX >> 8,
            VDI.BX & 0xff);
         exit(1);
      }

   //
   // Prompt for keypress before menu displayed
   //

   printf("\n\n");
   curpos(&x,&y);
   locate(x,y-1);
   printf("Press any key to continue ... ");

   if (getch() == 27)
      exit(0);

   locate(x,y-2);

   //
   // Sequence credits
   //

   printf("\n");
   printf("旼컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴커\n");
   printf("� \"GMW: A Tribute\" from Kaleidosonics (Masque Publishing, (303) 290-9853)  �\n");
   printf("� Original music by Rob Wallace for the Roland Sound Canvas                �\n");
   printf("� Copyright (C) 1993 Wallace Music and Sound, Inc. (602) 979-6201          �\n");
   printf("읕컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴켸\n");

   //
   // Select test function
   //

   choice[1] = "Start playback";  valid[1] = 1;
   choice[2] = "Stop playback";   valid[2] = 1;
   choice[3] = "Increase volume"; valid[3] = 1;
   choice[4] = "Decrease volume"; valid[4] = 1;

   VDI.DX = -1;
   vol = DDK_call_driver(&drvr, MDI_HW_VOLUME, &VDI, NULL);

   if (vol == -1)
      {
      valid[3] = 0;
      valid[4] = 0;
      }

   for (i=0;i<7;i++)
      {
      printf("\n");
      }

   while (1)
      {
      curpos(&x,&y);
      locate(x,y-7);

      switch (menu_choice("\n",choice,"\nCommand: ", valid, 4))
         {
         case 1:
            XMI_start_sequence(hseq);
            break;

         case 2:
            XMI_stop_sequence(hseq);
            break;

         case 3:
            VDI.DX = (vol == 127) ? 127 : vol+1;
            vol = DDK_call_driver(&drvr, MDI_HW_VOLUME, &VDI, NULL);
            break;

         case 4:
            VDI.DX = (vol == 0) ? 0 : vol-1;
            vol = DDK_call_driver(&drvr, MDI_HW_VOLUME, &VDI, NULL);
            break;
         }

      if (vol != -1)
         {
         curpos(NULL,&y);
         locate(11,y-1);
         printf("(Volume=%d)\n",vol);
         }
      }
}
