      *----------------------------------------------------------------
      * OBJCHKRV- Validity checking program
      * Copyright (C) 04/13/1986  Craig Rutledge   <craig_rutledge@mohawkind.com>
      * This program is free software, you can redistribute it and/or modify it under the terms
      * of the GNU General Public License as published by the Free Software Foundation.
      * 09/07/2001 - converted from CL to use APIs
      *----------------------------------------------------------------
      * program summary:
      * execute api to retrieve object description.
      * if error returned by api,
      *    retrieve message with replacement values
      *    send message back to command.
      *----------------------------------------------------------------
      * api (application program interfaces) used:
      * qusrobjd  get object description
      * qmhrtvm   retrieve messages
      * qmhsndpm  send messages
      *----------------------------------------------------------------
      * >>PRE-COMPILER<<
      *
      *   >>CRTCMD<< CRTBNDRPG    PGM(&LI/&OB) +
      *                           SRCFILE(&SL/&SF) +
      *                           SRCMBR(&SM);
      *
      *   >>COMPILE<<
      *     >>PARM<< TRUNCNBR(*NO);
      *     >>PARM<< DBGVIEW(*LIST);
      *     >>PARM<< DFTACTGRP(*YES);
      *   >>END-COMPILE<<
      *
      *   >>EXECUTE<<
      *
      * >>END-PRE-COMPILER<<
      * ---------------------------------------------------------------
     H EXPROPTS(*RESDECPOS)
     H DATFMT(*ISO)   TIMFMT(*ISO)    OPTION(*NODEBUGIO)
      /COPY QDSPDTAQ,COPYRIGHT
      *
     D mMsgRtv         ds                  inz
     D mMsgRtvLen              9     12i 0                                      length msg retrieved
     D mMsgMessage            25    256                                         message retrieved
     D mMsgLen         s             10i 0 inz(%len(mMsgRtv))                   length of message
     D qm_msgid        s              7
     D qm_msgtxt       s            128
     D qm_msgtyp       s             10
     D alpha8          s              8
      *
      *--------------------------------------------------------------------
      * create parm prototypes
      *--------------------------------------------------------------------
     D qusrobjd        PR                  ExtPgm('QUSROBJD')                   object descriptions
     Db                               8
     D                               10i 0 const
     D                                8    const                                TYPE FORMAT
     D                               20    const                                OBJ  LIB
     D                               10    const                                OBJ TYPE
     Db                                    like(vApiErrDS)                      error parm
      *    -------------------------------------------------------------
     D qmhrtvm         PR                  ExtPgm('QMHRTVM')                    RETRIEVE MESSAGE
     D                              256                                         message retrieved
     D                               10i 0                                      length of message
     D                                8    const                                requested format
     D                                7                                         msg identifier
     D                               20    const                                qualified msgf name
     D                              128                                         replacement data
     D                               10i 0 const                                len of replace data
     D                               10    const                                substitution char
     D                               10    const                                format control char
     Db                                    like(vApiErrDs)
      *
      *--------------------------------------------------------------------
     D qmhsndpm        PR                  ExtPgm('QMHSNDPM')                   SEND MESSAGES
     D                                7                                         ID
     D                               20    const                                FILE
     Db                                    like(qm_msgtxt)                      TEXT
     D                               10i 0 const                                LENGTH
     D                               10    const                                TYPE
     D                               10    const                                QUEUE
     D                               10i 0 const                                STACK ENTRY
     D                                4    const                                KEY
     Db                                    like(vApiErrDS)
      *    -------------------------------------------------------------
      * Error return code parm for APIs.
     D vApiErrDs       ds
     D  vbytpv                       10i 0 inz(%size(vApiErrDs))                bytes provided
     D  vbytav                       10i 0 inz(0)                               bytes returned
     D  vmsgid                        7a                                        error msgid
     D  vresvd                        1a                                        reserved
     D  vrpldta                     128a                                        replacement data
      *    -------------------------------------------------------------
     D  main           PR                  extpgm('OBJCHKRV ')
     D  i_obj_lib                    20A   const
     D  i_otyp                       10A   const
      *    -------------------------------------------------------------
     D  main           PI
     D  i_obj_olib                   20A   const
     D  i_otyp                       10A   const
      *
      *---------------------------------------------------------------------------------------
      * check to see if object exists.
     C                   callp     QUSROBJD(                                    get object descripti
     C                             alpha8:
     C                             8:
     C                             'OBJD0100':                                  TYPE FORMAT
     C                             i_obj_olib:                                  OBJ LIB  20
     C                             i_otyp:                                      OBJ TYPE
     C                             vapierrds)
 B01 C                   if        vbytav>0                                     error occurred
      *
      * call retrieve message API to pull in the subsitution variables
     C                   callp     QMHRTVM(                                     rtvmsgd
     C                             mMsgRtv :                                    message retrieved
     C                             mMsgLen :                                    length of message
     C                             'RTVM0100':                                  requested format
     C                             vmsgid:                                      msg identifier
     C                             'QCPFMSG   *LIBL':                           qualified msg file
     C                             vrpldta:                                     replacement data
     C                             %size(vrpldta):                              len of replace data
     C                             '*YES      ':                                substitution char
     C                             '*NO       ':                                format control char
     C                             vApiErrDs)
      *
      * set values to send messages, make message size not too big
 B02 C                   if        mMsgRtvLen > %size(mMsgMessage)
     C                   eval      mMsgRtvLen = %size(mMsgMessage)
 E02 C                   endif
     C                   eval      QM_msgtxt =
     C                             '0000 ' + %trimr(vmsgid) +': ' +
     C                                       %subst(mMsgMessage:1:mMsgRtvLen)
     C                   eval      QM_msgid = 'CPD0006'
     C                   eval      QM_msgtyp = '*DIAG'
     C                   exsr      srSndErrMsg                                  send error message
      *
     C                   eval      qm_msgtxt  = *blanks
     C                   eval      qm_msgid   = 'CPF0002'
     C                   eval      qm_msgtyp  = '*ESCAPE'
     C                   exsr      srSndErrMsg
 E01 C                   endif
     C                   eval      *inlr=*on
     C                   return
      *
      * call send program message api
     C     srSndErrMsg   begsr
     C                   callp     qmHSNDPM(
     C                             qm_msgid:
     C                             'QCPFMSG   *LIBL     ':
     C                             qm_msgtxt:
     C                             %size(qm_msgtxt):
     C                             qm_msgtyp:
     C                             '*CTLBDY':
     C                             1:
     C                             '    ':
     C                             vApiErrDS)
     C                   endsr
