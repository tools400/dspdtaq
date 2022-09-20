/* -------------------------------------------------------------------------- */
/* DSPDTAQ    - SCRIPT MEMBER                                                 */
/* Use commands  xmlgenINC (generate text for install pgm)                    */
/*               xmlgenMBR (to define source members                          */
/*               xmlgenCMD (execute qcmdexc at run time                       */
/* Put &TOLIB where you want user selected lib at run time.                   */
   DCL &TOLIB *CHAR 10
/* -------------------------------------------------------------------------- */
/* >>PRE-COMPILER<<                                                           */
/*   >>CRTCMD<<  XMLGEN  XMLSCRIPT(&SM) SCRIPTSRCF(&SL/&SF);                  */
/*   >>IMPORTANT<<                                                            */
/*     >>PARM<<  SRCTOFILE(&LI/QXML);                                         */
/*     >>PARM<<  XMLMBR(*SCRIPT);                                             */
/*     >>PARM<<  ENCODING('ISO-8859-1');                                      */
/*     >>PARM<<  AUTHOR('Thomas Raddatz');                                    */
/*   >>END-IMPORTANT<<                                                        */
/*   >>EXECUTE<<                                                              */
/* >>END-PRE-COMPILER<<                                                       */
/* -------------------------------------------------------------------------- */
             XMLGENINC  XINCLUDE(*YES)

             XMLGENVRS XSRCFILE(QDSPDTAQ) XSRCLIB(TOOLS400) XSRCMBR(COPYRIGHT)

             XMLGENSET  XVAR(&SRCFILE) XVALUE(QDSPDTAQ)

/* ---------------------------------- */
/*  Deploy source member              */
/* ---------------------------------- */
             XMLGENMBR  XMBR(A_INSTALL ) XMBRATR(CLLE  ) XFROMSRCF(QDSPDTAQ  ) +
                          XFROMSRCL(TOOLS400) XTOSRCF(QDSPDTAQ ) XOBJTYPE(*PGM) +
                          XGENCRT(*NO ) XPARAM(*BLANK)

             XMLGENMBR  XMBR(A_README  ) XMBRATR(TXT   ) XFROMSRCF(QDSPDTAQ  ) +
                          XFROMSRCL(TOOLS400) XTOSRCF(QDSPDTAQ ) XOBJTYPE(*PGM) +
                          XGENCRT(*NO ) XPARAM(*BLANK)

             XMLGENMBR  XMBR(COPYRIGHT ) XMBRATR(RPGLE ) XFROMSRCF(QDSPDTAQ  ) +
                          XFROMSRCL(TOOLS400) XTOSRCF(QDSPDTAQ ) XOBJTYPE(*MODULE) +
                          XGENCRT(*NO ) XPARAM(*BLANK)

             XMLGENMBR  XMBR(DSPDTAQDE ) XMBRATR(DSPF  ) XFROMSRCF(QDSPDTAQ  ) +
                          XFROMSRCL(TOOLS400) XTOSRCF(QDSPDTAQ ) XOBJTYPE(*FILE) +
                          XGENCRT(*NO ) XPARAM(*BLANK)

             XMLGENMBR  XMBR(DSPDTAQE  ) XMBRATR(CMD   ) XFROMSRCF(QDSPDTAQ  ) +
                          XFROMSRCL(TOOLS400) XTOSRCF(QDSPDTAQ ) XOBJTYPE(*CMD) +
                          XGENCRT(*NO ) XPARAM(*BLANK)

             XMLGENMBR  XMBR(DSPDTAQPE ) XMBRATR(PNLGRP) XFROMSRCF(QDSPDTAQ  ) +
                          XFROMSRCL(TOOLS400) XTOSRCF(QDSPDTAQ ) XOBJTYPE(*PNLGRP) +
                          XGENCRT(*YES) XPARAM(*BLANK)

             XMLGENMBR  XMBR(DSPDTAQR  ) XMBRATR(RPGLE ) XFROMSRCF(QDSPDTAQ  ) +
                          XFROMSRCL(TOOLS400) XTOSRCF(QDSPDTAQ ) XOBJTYPE(*PGM) +
                          XGENCRT(*NO ) XPARAM(*BLANK)

             XMLGENMBR  XMBR(DSPDTAQRV ) XMBRATR(RPGLE ) XFROMSRCF(QDSPDTAQ  ) +
                          XFROMSRCL(TOOLS400) XTOSRCF(QDSPDTAQ ) XOBJTYPE(*PGM) +
                          XGENCRT(*NO ) XPARAM(*BLANK)

/* ---------------------------------- */
/*  Create objects                    */
/* ---------------------------------- */
             XMLGENCMD  XCMD(CRTBNDCL PGM(&TOLIB/A_INSTALL) +
                          SRCFILE(&TOLIB/QDSPDTAQ) SRCMBR(*PGM) +
                          DFTACTGRP(*NO) ACTGRP(*NEW) +
                          DBGVIEW(*LIST)) XDLTSPLF(A_INSTALL)

             XMLGENCMD  XCMD(CALL PGM(&TOLIB/A_INSTALL) +
                             PARM('&TGTRLS' '&SRCFILE' '&TOLIB'))
             XMLGENCMD  XCMD(DLTPGM PGM(&TOLIB/A_INSTALL))

