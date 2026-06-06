**free
//----------------------------------------------------------------
// OBJCHKRV- Validity checking program
// Copyright (C) 04/13/1986  Craig Rutledge   <craig_rutledge@mohawkind.com>
// This program is free software, you can redistribute it and/or modify it under the terms
// of the GNU General Public License as published by the Free Software Foundation.
// 09/07/2001 - converted from CL to use APIs
//----------------------------------------------------------------
// program summary:
// execute api to retrieve object description.
// if error returned by api,
//    retrieve message with replacement values
//    send message back to command.
//----------------------------------------------------------------
// api (application program interfaces) used:
// qusrobjd  get object description
// qmhrtvm   retrieve messages
// qmhsndpm  send messages
//----------------------------------------------------------------
// >>PRE-COMPILER<<
//
//   >>CRTCMD<< CRTBNDRPG    PGM(&LI/&OB) +
//                           SRCFILE(&SL/&SF) +
//                           SRCMBR(&SM);
//
//   >>COMPILE<<
//     >>PARM<< TRUNCNBR(*NO);
//     >>PARM<< DBGVIEW(*LIST);
//     >>PARM<< DFTACTGRP(*YES);
//   >>END-COMPILE<<
//
//   >>EXECUTE<<
//
// >>END-PRE-COMPILER<<
// ---------------------------------------------------------------
ctl-opt expropts(*resdecpos);
ctl-opt datfmt(*iso) timfmt(*iso) option(*nodebugio);
/copy QDSPDTAQ,COPYRIGHT

dcl-ds mMsgRtv inz;
  mMsgRtvLen  int(10) pos(9); // length msg retrie
  mMsgMessage char(232) pos(25); // message retrieved
end-ds;
dcl-s mMsgLen int(10) inz(%len(mMsgRtv)); // length of message
dcl-s qm_msgid char(7);
dcl-s qm_msgtxt char(128);
dcl-s qm_msgtyp char(10);
dcl-s alpha8 char(8);

//--------------------------------------------------------------------
// create parm prototypes
//--------------------------------------------------------------------
dcl-pr qusrobjd extpgm('QUSROBJD'); // object descriptio
  b  char(8);
  *n int(10) const;
  *n char(8) const; // TYPE FORMAT
  *n char(20) const; // OBJ  LIB
  *n char(10) const; // OBJ TYPE
  b  like(vApiErrDS); // error parm
end-pr;
//    -------------------------------------------------------------
dcl-pr qmhrtvm extpgm('QMHRTVM'); // RETRIEVE MESSAGE
  *n char(256); // message retrieved
  *n int(10); // length of message
  *n char(8) const; // requested format
  *n char(7); // msg identifier
  *n char(20) const; // qualified msgf na
  *n char(128); // replacement data
  *n int(10) const; // len of replace da
  *n char(10) const; // substitution char
  *n char(10) const; // format control ch
  b  like(vApiErrDs);
end-pr;

//--------------------------------------------------------------------
dcl-pr qmhsndpm extpgm('QMHSNDPM'); // SEND MESSAGES
  *n char(7); // ID
  *n char(20) const; // FILE
  b  like(qm_msgtxt); // TEXT
  *n int(10) const; // LENGTH
  *n char(10) const; // TYPE
  *n char(10) const; // QUEUE
  *n int(10) const; // STACK ENTRY
  *n char(4) const; // KEY
  b  like(vApiErrDS);
end-pr;
//    -------------------------------------------------------------
// Error return code parm for APIs.
dcl-ds vApiErrDs;
  vbytpv  int(10) inz(%size(vApiErrDs)); // bytes provided
  vbytav  int(10) inz(0); // bytes returned
  vmsgid  char(7); // error msgid
  vresvd  char(1); // reserved
  vrpldta char(128); // replacement data
end-ds;
//    -------------------------------------------------------------
dcl-pr main extpgm('OBJCHKRV ');
  i_obj_lib char(20) const;
  i_otyp    char(10) const;
end-pr;
//    -------------------------------------------------------------
dcl-pi main;
  i_obj_olib char(20) const;
  i_otyp     char(10) const;
end-pi;

//---------------------------------------------------------------------------------------
// check to see if object exists.
QUSROBJD(                                                                // get object descri
alpha8:
8:
'OBJD0100':                                                              // TYPE FORMAT
i_obj_olib:                                                              // OBJ LIB  20
i_otyp:                                                                  // OBJ TYPE
vapierrds);
if vbytav>0;                                                             // error occurred

  // call retrieve message API to pull in the subsitution variables
  QMHRTVM(                                                              // rtvmsgd
  mMsgRtv :                                                             // message retrieved
  mMsgLen :                                                             // length of message
  'RTVM0100':                                                           // requested format
  vmsgid:                                                               // msg identifier
  'QCPFMSG   *LIBL':                                                    // qualified msg fil
  vrpldta:                                                              // replacement data
  %size(vrpldta):                                                       // len of replace da
  '*YES      ':                                                         // substitution char
  '*NO       ':                                                         // format control ch
  vApiErrDs);

  // set values to send messages, make message size not too big
  if mMsgRtvLen > %size(mMsgMessage);
    mMsgRtvLen = %size(mMsgMessage);
  endif;
  QM_msgtxt =
  '0000 ' + %trimr(vmsgid) +': ' +
           %subst(mMsgMessage:1:mMsgRtvLen);
  QM_msgid = 'CPD0006';
  QM_msgtyp = '*DIAG';
  exsr srSndErrMsg;                                                     // send error messag

  qm_msgtxt  = *blanks;
  qm_msgid   = 'CPF0002';
  qm_msgtyp  = '*ESCAPE';
  exsr srSndErrMsg;
endif;
*inlr=*on;
return;

// call send program message api
begsr srSndErrMsg;
  qmHSNDPM(
  qm_msgid:
  'QCPFMSG   *LIBL     ':
  qm_msgtxt:
  %size(qm_msgtxt):
  qm_msgtyp:
  '*CTLBDY':
  1:
  '    ':
  vApiErrDS);
endsr;
