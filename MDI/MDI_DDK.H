//############################################################################
//##                                                                        ##
//##  Miles Sound System                                                    ##
//##                                                                        ##
//##  MDI_DDK.H: API function prototypes for MSS 3.0 DDK functions          ##
//##                                                                        ##
//##  Flat-model source compatible with IBM 32-bit ANSI C/C++               ##
//##                                                                        ##
//##  Version 1.00 of 11-Apr-94: Initial version for MSS 3.0                ##
//##          1.12 of 24-Sep-94: DDK version 1.12                           ##
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

#ifndef MDI_DDK_H
#define MDI_DDK_H

#ifdef __cplusplus
extern "C" {
#endif

#ifndef TYPEDEFS
#define TYPEDEFS

typedef unsigned char  UBYTE;
typedef unsigned short UWORD;
typedef unsigned long  ULONG;
typedef          char  BYTE;
typedef signed   short WORD;
typedef signed   long  LONG;

#endif

typedef ULONG REALFAR;              // Real-mode far pointer type

#ifndef REALPTR
#define REALPTR(x) ((void *) (ULONG) (((x)>>16<<4) + ((x) & 0xffff)))
#endif

typedef int HTIMER;                 // Handle to timer
typedef int HSEQUENCE;              // Handle to XMIDI sequence

typedef struct                      // I/O parameters structure
{
   WORD IO;
   WORD IRQ;
   WORD DMA_8_bit;
   WORD DMA_16_bit;
   LONG IO_reserved[4];
}
IO_PARMS;

typedef struct                      // Standard MSS 3.X VDI driver header
{                                    
   BYTE     ID[8];                  // "AIL3xxx" ID string, followed by ^Z

   ULONG    driver_version;        

   REALFAR  common_IO_configurations;
   UWORD    num_IO_configurations;

   REALFAR  environment_string;     // Name of environment variable 
   
   IO_PARMS IO;                     // I/O parameters in use

   WORD     service_rate;           // Callback rate in hertz

   UWORD    busy;

   UWORD    driver_num;             // Driver number

   UWORD    this_ISR;               // Offset of INT 66H dispatcher
   REALFAR  prev_ISR;               // Pointer to previous INT 66H ISR

   BYTE     scratch[128];           // Shared scratch workspace

   BYTE     dev_name[80];           // Device name
}  
VDI_HDR;

typedef struct
{
   REALFAR  library_environment;
   REALFAR  GTL_suffix;

   UWORD    num_voices;

   UWORD    max_melodic_channel;
   UWORD    min_melodic_channel;
   UWORD    percussion_channel;
}
MDI_DDT;

typedef struct
{
   BYTE     library_directory[128];
   BYTE     GTL_filename[128];

   BYTE     MIDI_data[512];
}
MDI_DST;

typedef struct                      // Handle to driver
{
   REALFAR  seg;                    // Seg:off pointer to driver (off=0)
   void    *buf;                    // Protected-mode pointer to driver
   VDI_HDR *VHDR;                   // Pointer to driver header (same as buf)
   LONG     type;                   // AIL3DIG or AIL3MDI (see below)
   MDI_DDT *DDT;                    // Protected-mode pointer to DDT
   MDI_DST *DST;                    // Protected-mode pointer to DST
}
AIL_DRIVER;

typedef struct
{
   AIL_DRIVER *drvr;                // Base driver descriptor
}
MDI_DRIVER;

typedef struct                      // VDI interface register structure
{
   WORD AX;
   WORD BX;
   WORD CX;
   WORD DX;
   WORD SI;
   WORD DI;
}
VDI_CALL;

#define AIL3DIG                  0        // .DIG driver
#define AIL3MDI                  1        // .MDI driver

#define DIG_DETECT_8_BIT_ONLY    0x0001   // Detect 8-bit DMA only
#define DIG_DETECT_16_BIT_ONLY   0x0002   // Detect 16-bit DMA only
#define DIG_DETECT_8_AND_16_BITS 0x0004   // Detect both 8- and 16-bit DMA
#define AIL_DETECT_SCAN          0x0008   // Test environment var, then scan
#define AIL_DETECT_USE_ENV_VAR   0x0010   // Test environment var only
#define AIL_DETECT_USE_PARMS     0x0018   // Test using explicit parameters

#ifndef FILE_ERRS
#define FILE_ERRS

#define NO_ERROR          0         // FILE_error() codes
#define IO_ERROR          1
#define OUT_OF_MEMORY     2
#define FILE_NOT_FOUND    3
#define CANT_WRITE_FILE   4
#define CANT_READ_FILE    5
#define DISK_FULL         6

#endif

#define DRV_INIT          0x300     // Functions common to .MDI and .DIG
#define DRV_GET_INFO      0x301     // drivers
#define DRV_SERVE         0x302
#define DRV_PARSE_ENV     0x303
#define DRV_VERIFY_IO     0x304
#define DRV_INIT_DEV      0x305
#define DRV_SHUTDOWN_DEV  0x306

#define MDI_HW_VOLUME     0x500     // .MDI driver functions
#define MDI_INIT_INS_MGR  0x501
#define MDI_MIDI_XMIT     0x502
#define MDI_INSTALL_T_SET 0x503
#define MDI_GET_T_STATUS  0x504
#define MDI_PROT_UNPROT_T 0x505
#define MDI_VSE           0x506

//
// Support services
//

extern void    cdecl   DDK_startup(void);
extern void    cdecl   DDK_shutdown(void);

extern ULONG   cdecl   DDK_get_real_vect(ULONG vectnum);
extern void    cdecl   DDK_set_real_vect(ULONG vectnum, ULONG real_ptr);

extern ULONG   cdecl   DDK_disable_interrupts(void);
extern ULONG   cdecl   DDK_restore_interrupts(ULONG FD_register);

//
// Driver services
//

extern LONG   cdecl    DDK_call_driver(AIL_DRIVER *drvr, LONG fn,
                                       VDI_CALL *in, VDI_CALL *out);

extern HTIMER cdecl    DDK_register_timer(void *callback_fn);
extern void   cdecl    DDK_set_timer_frequency(HTIMER timer, ULONG hertz);
extern void   cdecl    DDK_start_timer(HTIMER timer);

//
// XMIDI services used by DDK
//

extern void   cdecl    XMI_init(void);
extern void   cdecl    XMI_shutdown(void);
extern ULONG  cdecl    XMI_state_table_size(void);

extern void   cdecl    XMI_serve(void);

extern HSEQUENCE cdecl XMI_register_sequence(void *FORM_XMID,
                                             ULONG sequence_num, 
                                             void *state_table, 
                                             void *controller_table);

extern void   cdecl    XMI_release_sequence_handle(HSEQUENCE sequence);


extern void * cdecl    XMI_TIMB_address(HSEQUENCE sequence);

extern void   cdecl    XMI_start_sequence(HSEQUENCE sequence);
extern void   cdecl    XMI_stop_sequence(HSEQUENCE sequence);

#ifdef __cplusplus
}
#endif
   
#endif
