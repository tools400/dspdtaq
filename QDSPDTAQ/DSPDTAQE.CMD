/* ----------------------------------------------------------------- */
/* DSPDQE- Display Data Queue Entries - Command Definition           */
/* By   Craig Rutledge, 06/11/93                                     */
/* ----------------------------------------------------------------- */
/* Command Summary:                                                  */
/* The command will display, in a subfile, all entries in a DATAQ.   */
/* The entries on the queue are not touched or disturbed.            */
/* ----------------------------------------------------------------- */
/* Related Objects:                                                  */
/* DSPDTAQR   *PGM    RPGLE    display data queue entries            */
/* DSPDTAQD   *FILE   DSPF                                           */
/* DSPDTAQP   *PNLGRP          Help Text                             */
/* DSPDTAQRV  *PGM    RPGLE    Validity checker                      */
/* ----------------------------------------------------------------- */
/* >>PRE-COMPILER<<                                                  */
/*                                                                   */
/*   >>CRTCMD<< CRTCMD       CMD(&LI/&OB) +                          */
/*                           SRCFILE(&SL/&SF) +                      */
/*                           SRCMBR(&SM);                            */
/*                                                                   */
/*   >>COMPILE<<                                                     */
/*     >>PARM<< PGM(*LIBL/DSPDTAQR);                                 */
/*     >>PARM<< ALWLMTUSR(*NO);                                      */
/*     >>PARM<< HLPID(DSPDTAQ);                                      */
/*     >>PARM<< MODE(*ALL);                                          */
/*     >>PARM<< ALLOW(*ALL);                                         */
/*     >>PARM<< VLDCKR(&LI/DSPDTAQRV);                               */
/*     >>PARM<< HLPPNLGRP(&LI/DSPDTAQP);                             */
/*     >>PARM<< TEXT(*SRCMBRTXT);                                    */
/*     >>PARM<< PRDLIB(&LI);                                         */
/*   >>END-COMPILE<<                                                 */
/*                                                                   */
/*   >>EXECUTE<<                                                     */
/*                                                                   */
/* >>END-PRE-COMPILER<<                                              */
/* ----------------------------------------------------------------- */
             CMD        PROMPT('Display Data Queue Entries')

             PARM       KWD(DTAQ) TYPE(QUAL1) MIN(1) PROMPT('Data +
                          queue:')
             PARM       KWD(OBJTYP) TYPE(*CHAR) LEN(10) +
                          CONSTANT('*DTAQ     ')

 QUAL1:      QUAL       TYPE(*NAME) LEN(10) MIN(1)
             QUAL       TYPE(*NAME) LEN(10) DFT(*LIBL) +
                          SPCVAL((*LIBL)) PROMPT('Library name:')
