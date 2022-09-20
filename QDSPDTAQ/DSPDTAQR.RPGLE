      *----------------------------------------------------------------
      * DSPDQER  - Display Data Queue Entries                     v4r2
      * Copyright (C) 06/11/1993  Craig Rutledge   <craig_rutledge§mohawkind.com>
      * This program is free software, you can redistribute it and/or modify it under the terms
      * of the GNU General Public License as published by the Free Software Foundation.
      * --------
      *
      * 5/7/2001 V2 - rewrite.  Replace DMPOBJ logic with API to do
      * non-destructive display of dataq entries as messages.
      *
      * Thanks to Dennis Lovelady (www.lovelady.com) this program now uses
      * a user space as a retrieve variable.  Not quite a documented
      * feature, but it works| Now you can retrieve up to 12Meg of entries.
      * If this technique causes anyone problems, please advise me.
      *
      * I do NOT understand 1) why IBM made this API so radically different
      * than the normal qrcvdatq call.  2) why in heck they didn't make
      * this a user space api or at least give a continuation handle so
      * I could get all entries.  Almost makes you want to learn Unix.
      * 6/25/2001 - scan through entries before they are sent to screen to make sure no
      * hex data less than x'40' is embedded.
      * 11/09/2001 - Thomas Raddatz: Changed F4 to F11 to unfold/fold subfile.
      *                              Added hexadecimal display mode.
      *                              Added data column offset.
      * 12/05/2001 - Craig Rutledge: Subfile remains on same screen during Fkeys.
      *                              Added F19-column shift left
      *                              Added F20-column shift right
      * PTF note:  Api qmhrdqm requires PTF
      * sf63313 v4r2, sf63312 v4r3, sf62994 v4r4, sf63182 v5r1
      * be installed on your system to view keyed data queue entrys.
      *----------------------------------------------------------------
      * Program Summary:
      * Call API to retrieve data queue object description
      * Extract entries and load to subfile
      * Display subfile
      *----------------------------------------------------------------
      * API (application program interfaces) used:
      * QMHQRDQD  display data queue object description
      * QMHRDQM   retrieve dataq entries
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
     H BNDDIR('QC2LE') EXPROPTS(*RESDECPOS)
     H DATFMT(*ISO)   TIMFMT(*ISO)    OPTION(*NODEBUGIO)
      /COPY QDSPDTAQ,COPYRIGHT
      *
     Fdspdtaqd  cf   e             workstn sfile(data1:rrn1)
     F                                     infds(dsinf)
      *----------------------------------------------------------------
      *  allow subfile to stay on current screen
     D dsinf           ds
     D   bgrrn               378    379i 0
     D bgrrnsav        s                   like(bgrrn)
      *
     D rrn1            s              5u 0
     D torecNum        s              5u 0
     D aa              s              5u 0 inz
     D ff              s              5u 0 inz
     D mvr             s              5u 0 inz
     D Shift           s              5u 0 inz(58)
     D hex40           s              1    inz(x'40')
     D cSflPag         c                   const(7)
     D sflDspPag       s             10I 0
      *
      *----------------------------------------------------------------
      * Define parms for QMHQRDQD retrieve dataq description.
      *----------------------------------------------------------------
     D qrcvar          ds                  inz
     D  qMsgLength                   10i 0 overlay(qrcvar:9)
     D  qKeyLength                   10i 0 overlay(qrcvar:13)
     D  qAccessTyp            17     17
     D  qText                 20     69
     D  qTrimLen                     10i 0 inz
     D v0200len        s             10i 0
     D ExitPgmFlg      s              1    inz(*off)
      *
      *----------------------------------------------------------------
      * Define parms for QMHRDQM retrieve dataq entries
      *----------------------------------------------------------------
     D vrcvar          ds                  based(uheadptr)
     D vBytesReturned                10i 0 overlay(vrcvar:1)
     D vBytesAvail                   10i 0 overlay(vrcvar:5)
     D vNumMsgRtn                    10i 0 overlay(vrcvar:9)
     D vNumMsgAvl                    10i 0 overlay(vrcvar:13)                                      d
     D vKeyLenRtn                    10i 0 overlay(vrcvar:17)
     D vKeyLenAvl                    10i 0 overlay(vrcvar:21)
     D vMsgTxtRtn                    10i 0 overlay(vrcvar:25)
     D vMsgTxtAvl                    10i 0 overlay(vrcvar:29)
     D vEntryLenRtn                  10i 0 overlay(vrcvar:33)
     D vEntryLenAvl                  10i 0 overlay(vrcvar:37)
     D vOffset1stEnt                 10i 0 overlay(vrcvar:41)
     D vQLib                         10    overlay(vrcvar:45)
     D vMessageData               32767    varying
     D uheadptr        s               *   inz(*null)
      *
      *      ---------------------------------------------------------------------------------------
      *      Move pointer through message entries
      *      ---------------------------------------------------------------------------------------
     D vListEntry      ds                  based(vListPtr)
     D   vNextEntry                  10i 0
     D   vDateTime                    8                                         TOD format
     D   vMsgVar                  32767                                         variable text
      *
      *      ---------------------------------------------------------------------------------------
      *      Message selection info - RDQS0100 nonkeyed queues  RDQS0200 Keyed data queues
      *      ---------------------------------------------------------------------------------------
     D vRDQS0100       ds
     D   v1Selection                  1    inz('A')                             all
     D   v1Reserved                   3
     D   v1MsgByteRtv                10i 0 inz   overlay(vRDQS0100:5)           message bytes to rtv
      *
     D vRDQS0200       ds
     D   v2Selection                  1    inz('K')                             Keyed
     D   v2KeyOrder                   2    inz('GE')
     D   v2MsgByteRtv                10i 0 inz   overlay(vRDQS0200:5)           message bytes to rtv
     D   v2KeyByteRtv                10i 0 inz   overlay(vRDQS0200:9)           keys bytes to rtv
     D   v2KeyLen                    10i 0 inz   overlay(vRDQS0200:13)          key length
     D   v2Key                      256          overlay(vRDQS0200:17)          key value
      *
      *----------------------------------------------------------------
      * get entry date and time from API
      *----------------------------------------------------------------
     D dtDS            ds            16                                         extract C YYMMDD
     D  dtFiller                      1
     D  dtMDY                         6
     D  dtTIME                        6
      *
      *----------------------------------------------------------------
      * Divide entry up into subfile fields
      *----------------------------------------------------------------
     D ViewqDS         ds
     D   Viewq1
     D   Viewq2
     D TempqDS         s            116a
     D isHexMode       s               n   inz(*off)
     D ofs             s             10i 0 inz
     D ColumnShift     s             10i 0 inz
     D x               s             10i 0 inz
     D cRuler1         c                   const('....+....1....+....2+
     D                                            ....+....3....+....4+
     D                                            ....+....5....+....6+
     D                                            ....+....7....+....8+
     D                                            ....+....9....+....0+
     D                                            ....+....1....+....2+
     D                                            ....+....3....+....4+
     D                                            ....+....5....+....6+
     D                                            ....+....7....+....8+
     D                                            ....+....9....+....0+
     D                                            ....+....1....+....2')
     D cRuler2         c                   const('. . . . + . . . . 1 +
     D                                            . . . . + . . . . 2 +
     D                                            . . . . + . . . . 3 +
     D                                            . . . . + . . . . 4 +
     D                                            . . . . + . . . . 5 +
     D                                            . . . . + . . . . 6 +
     D                                            . . . . + . . . . 7 +
     D                                            . . . . + . . . . 8 +
     D                                            . . . . + . . . . 9 +
     D                                            . . . . + . . . . 0 +
     D                                            . . . . + . . . . 1 +
     D                                            . . . . + . . . . 2 +
     D                                            . . . . + . . . . 3 +
     D                                            . . . . + . . . . 4 +
     D                                            . . . . + . . . . 5 +
     D                                            . . . . + . . . . 6 +
     D                                            . . . . + . . . . 7 +
     D                                            . . . . + . . . . 8 +
     D                                            . . . . + . . . . 9 +
     D                                            . . . . + . . . . 0 ')
      *
      *----------------------------------------------------------------
      * Error return code parm for APIs.
      *----------------------------------------------------------------
     D vApiErrDs       ds
     D  vbytpv                       10i 0 inz(%size(vApiErrDs))                bytes provided
     D  vbytav                       10i 0 inz(0)                               bytes returned
     D  vmsgid                        7                                         error msgid
     D  vresvd                        1                                         reserved
     D  vrpldta                      50a                                        replacement data
      *
      *---------------------------------------------------------------------------------------------
      * Create Prototypes for calls
      *---------------------------------------------------------------------------------------------
     D qwccvtdt        PR                  ExtPgm('QWCCVTDT')                   api date converter
     D                               10    const                                FROM FORMAT
     D                                8                                         API DATE STAMP
     D                               10    const                                TO FORMAT
     Dd                                    like(dtDS)                           TO DATE
     Db                                    like(vApiErrDS)                      error parm
      *    -------------------------------------------------------------
     D qmhqrdqd        PR                  ExtPgm('QMHQRDQD')                   data q description
     Db                                    like(qrcvar)                         RECIEVER
     D                               10i 0 const                                LENGTH
     D                                8    const                                FORMAT
     Dd                              20                                         Q NAME & LIB
      *    -------------------------------------------------------------
     D qmhrdqm         PR                  ExtPgm('QMHRDQM ')                   get q entry
     Db                                    like(vrcvar)                         RECIEVER
     D                                       Options(*varsize)
     D                               10i 0 const                                LENGTH
     D                                8    const                                FORMAT
     D                               20                                         Q NAME & LIB
     Db                                    like(vRDQS0200) Options(*varsize)    KEY INFORMATION
     D                                        const
     D                               10i 0 const                                KEY INFO LENGTH
     D                                8    const                                INFORMATION
     Db                                    like(vApiErrDS) Options(*varsize)    error data structure
      *    -------------------------------------------------------------
     D quscrtus        PR                  ExtPgm('QUSCRTUS')                   create user space
     D                               20                                         Space Name
     D                               10    const                                Extended Attrb
     D                               10i 0 const                                length of space
     D                                1    const                                Hex0Init
     D                               10    const                                Use Authority
     D                               50    const                                text
     D                               10    const                                replace object
     Db                                    like(vApiErrDS)                      error parm
      *    -------------------------------------------------------------
     D uSpaceName      s             20    inz('JCRCMDS   QTEMP     ')
     D qusptrus        PR                  ExtPgm('QUSPTRUS')                   retrieve pointer
     D                               20                                         Space Name
     D                                 *                                        pointer
     Db                                    like(vApiErrDS)                      error parm
      *    -------------------------------------------------------------
     D cvthc           PR                  ExtProc('cvthc')                     Cvt. Hex to Char
     D  i_receiver                     *   value
     D  i_source                       *   value
     D  i_numSrcNib                  10i 0 value
      *    -------------------------------------------------------------
     D main            PR                  extpgm('DSPDQER ')
     D  i_qnamlib                    20A                                        NAME LIB 20
     D  i_qobjtyp                    10A
      *    -------------------------------------------------------------
     D main            PI
     D  i_qnamlib                    20A
     D  i_qobjtyp                    10A
      *---------------------------------------------------------------------------------------------
     C                   eval      vqname=%subst(i_qnamlib:1:10)
     C                   eval      vSflMode = *on
     C                   eval      *in03    = vSflMode                          subfile mode
     C                   eval      vpos     = 1
      *
      * create object list user space
     C                   callp     QUSCRTUS(                                    CREATE USER SPC
     C                             uSpaceName:                                  CREATE USER SPC
     C                             'TEST':                                      EXTENDED ATRIB
     C                             13000000:                                    SIZE IN BYTES
     C                             x'00':                                       INITIAL VALUE
     C                             '*ALL':                                      AUTHORITY
     C                             'List Objects  ':                            TEXT
     C                             '*NO ':                                      REPLACE OBJ
     C                             vApiErrDs)                                   ERROR
      *
      * Get pointer to object list user spaces
     C                   callp     QUSPTRUS(                                    GET POINTER TO SPACE
     C                             uSpaceName:                                  SPACE    LIB
     C                             uHeadPtr:                                    pointer to header
     C                             vApiErrDs)                                   error
      *
      * Call API to retrieve data queue description.
     C                   callp     QMHQRDQD(
     C                             qrcvar:                                      DATA STRUCT
     C                             %size(qrcvar):                               SIZE
     C                             'RDQD0100':                                  TYPE FORMAT
     C                             i_qnamlib)                                   NAME LIB
      *
      * Setup a looping subroutine so user can refresh screen
 B01 C                   dou       ExitPgmFlg=*on
     C                   exsr      RefreshScreen
 E01 C                   enddo
     C                   eval      *inlr = *on                                  PROGRAM END
     C                   return
      *
      *----------------------------------------------------------------
      * Call API to retrieve data queue entries
      *   Different type dataqs require a different parm list to the API.
      *----------------------------------------------------------------
     C     RefreshScreen begsr
 B01 C                   if        qAccessTyp ='K'                              keyed
     C                   eval      vacsType = '*KEYED'
     C                   eval      v2MsgByteRtv = qMsgLength                    message bytes to rtv
     C                   eval      v2KeyByteRtv = qKeyLength                    keys bytes to rtv
     C                   eval      v2KeyLen = qKeyLength                        keys length to rtv
     C                   eval      v0200Len=16+qKeyLength                       len of info
     C                   callp     QMHRDQM(
     C                             vrcvar:                                      return variable
     C                             12000000:                                    len of return var
     C                             'RDQM0200':                                  return format
     C                             i_qnamlib:                                   NAME LIB
     C                             vRDQS0200:                                   key information
     C                             v0200Len:                                    key information leng
     C                             'RDQS0200':                                  information format
     C                             vApiErrDS)                                   error data structure
 X01 C                   else
      *  non keyed
     C                   eval      vacsType = '*NON-KEYED'
     C                   eval      v1MsgByteRtv = qMsgLength                    message bytes to rtv
     C                   callp     QMHRDQM(
     C                             vrcvar:                                      return variable
     C                             12000000:                                    len of return var
     C                             'RDQM0100':                                  return format
     C                             i_qnamlib:                                   NAME LIB
     C                             vRDQS0100:                                   key information
     C                             %size(vRDQS0100):                            key information leng
     C                             'RDQS0100':                                  information format
     C                             vApiErrDS)                                   error data structure
 E01 C                   endif
      *
      *---------------------------------------------------------------------------------------------
      * Spin through the dataq entries.
      *   Convert API date/time stamp to human-readable.
      *     Load to subfile.
      *---------------------------------------------------------------------------------------------
     C                   clear                   rrn1
 B01 C                   if        vNumMsgRtn >  0                              there are entries
      *
      *      ---------------------------------------------------------------------------------------
      *      Move pointer through message entries
      *      ---------------------------------------------------------------------------------------
     C                   eval      vListPtr=uHeadPtr  + vOffset1stEnt           1st offset
 B02 C                   do        vNumMsgRtn
     C                   exsr      DecodeDate
     C                   exsr      srTempqDS
     C                   exsr      srDataToDsp
     C                   eval      rrn1=rrn1+1
     C                   write     data1
 B03 C                   if        rrn1=9999                                    subfile full
     C                   leave
 E03 C                   endif
     C                   eval      vListPtr=uHeadPtr  + vNextEntry
 E02 C                   enddo
 E01 C                   endif
      *
      *----------------------------------------------------------------
      * Display subfile.  Calc number of screens in subfile.
      *----------------------------------------------------------------
     C                   eval      vSrecNum=1
     C                   eval      ColumnShift=0
     C                   eval      vlen          = qMsgLength
     C                   eval      vqTotCnt      = vNumMsgAvl                   total number of entr
 B01 C                   dou       1=2
      *
     C                   eval      x = ofs + 1
 B02 C                   dow       x > 100
     C                   eval      x = x - 100
 E02 C                   enddo
      *
 B02 C                   if        isHexMode
     C                   eval      vRuler = %subst(cRuler2: (x*2)-1)
 X02 C                   else
     C                   eval      vRuler = %subst(cRuler1: x)
 E02 C                   endif
      *
 B02 C                   if        ofs = 0
     C                   eval      %subst(vRuler: 1: 1) = '*'
 E02 C                   endif
      *
 B02 C                   if        vSflMode = *on
     C                   eval      sflDspPag = cSflPag * 2
 X02 C                   else
     C                   eval      sflDspPag = cSflPag
 E02 C                   endif
      *
     C                   eval      vqentNum = rrn1                              # Q ENTRIES
     C     rrn1          div       sflDspPag     vScrnNum                       # OF SCREENS
     C                   mvr                     mvr
 B02 C                   if        mvr>0                                        OVERFLOW SCREENS
     C                   eval      vScrnNum =  vScrnNum+1
 E02 C                   endif
      *
     C                   eval      *in20=(rrn1>sflDspPag)                       more
     C                   eval      *in01=(rrn1>0)                               SFLDSP
     C                   eval      *in02 = *on                                  SFLDSPCTL
      *
     C                   write     header                                        DISPLAY
     C                   exfmt     contrl1                                       SCREENS
     C                   eval      *in03 = vSflMode
      * exit / cancel
 B02 C                   select
     C                   when      *inkc or *inkl
     C                   eval      ExitPgmFlg=*on
      * v4r4---          leavesr
     C                   goto      outtag                                       F3=exit    v4r2
      *
      * refresh
     C                   when      *inke                                        F5=refresh
     C                   eval      rrn1=0
     C                   eval      *in01=*off
     C                   eval      *in02=*off
     C                   write     contrl1                                      clear
      * v4r4---          leavesr                                                F5=REFRESH
     C                   goto      outtag                                       F5=REFRESH v4r2
      *
      * change display mode
     C                   when      *inkj                                        F10=Hex
 B03 C                   if        isHexMode
     C                   eval      isHexMode = *off
     C                   eval      Shift=58
 X03 C                   else
     C                   eval      isHexMode = *on
     C                   eval      Shift=25
 E03 C                   endif
     C                   eval      bgrrnSav=bgrrn
     C                   exsr      srUpdSfl
     C                   eval      bgrrn=bgrrnSav
      * fold/unfold
     C                   when      *inkk                                        F11=Fold/Unfold
 B03 C                   if        vSflMode = *on
     C                   eval      vSflMode = *off
 X03 C                   else
     C                   eval      vSflMode = *on
 E03 C                   endif
     C                   eval      *in03 = vSflMode
      *
      * shift column position to the left
     C                   when      *inkt                                        F19=column left
     C                   eval      ColumnShift=ColumnShift-Shift
 B03 C                   if        ColumnShift<0
     C                   eval      ColumnShift=1
 E03 C                   endif
     C                   eval      vdspPos=ColumnShift
      *
      * shift column position to the right
     C                   when      *inku                                        F20=column right
     C                   eval      ColumnShift=ColumnShift+Shift
 B03 C                   if        ColumnShift >= qMsgLength
     C                   eval      ColumnShift =  qMsgLength - 1
 E03 C                   endif
     C                   eval      vdspPos=ColumnShift
 E02 C                   endsl
      *
      *   ---------------------------------------------------------------
      *   Determine which screen the user wants to display.
      *   ---------------------------------------------------------------
 B02 C                   if        vdspNum = 0                                  screen field=0
 B03 C                   if        bgrrn=0
     C                   eval      bgrrn=1
 E03 C                   endif
     C                   eval      vsrecNum = bgrrn
 X02 C                   else
     C                   eval      torecNum = vdspNum * sflDspPag
 B03 C                   if        torecNum < rrn1                              NOT PAST EOF
     C                   eval      vsrecNum      = torecNum
 X03 C                   else
     C                   eval      vsrecNum      = rrn1                         PAST EOF SELCTD
 E03 C                   endif
 E02 C                   endif
      *
      *   ---------------------------------------------------------------
      *   Determine the column offset the user wants to display.
      *   ---------------------------------------------------------------
 B02 C                   if        vdspPos > 0
     C                   eval      ofs = vdspPos - 1
 B03 C                   if        ofs < 0
     C                   eval      ofs = 0
 E03 C                   endif
 B03 C                   if        ofs >= qMsgLength
     C                   eval      ofs = qMsgLength - 1
 E03 C                   endif
     C                   exsr      srUpdSfl
     C                   eval      vpos    = ofs + 1
     C                   eval      vdspPos = 0
 E02 C                   endif
      *
     C                   clear                   vdspNum                        REINIT
     C                   clear                   torecNum
 E01 C                   enddo
     C     outtag        endsr
      *
      *----------------------------------------------------------------
      * Decode the Date-Time_Stamp into MM/DD/YY and HH:MM:SS
      *----------------------------------------------------------------
     C     DecodeDate    begsr
     C                   callp     QWCCVTDT(                                    API DATE CONVRT
     C                             '*DTS    ':                                  FROM FORMAT
     C                             vDateTime :                                  TO BE CONVERTED
     C                             '*MDY    ':                                  TO FORMAT
     C                             dtDS  :                                      CONVERTED DATE
     C                             vApiErrDs)
     C                   eval      qudate=%subst(dtMDY:1:2) + '/' +
     C                             %subst(dtMDY:3:2) +'/'+ %subst(dtMDY:5:2)
     C                   eval      qutime=%subst(dtTIME:1:2) + ':' +
     C                             %subst(dtTIME:3:2) +':'+ %subst(dtTIME:5:2)
     C                   endsr
      *
      *----------------------------------------------------------------
      * Update Subfile.
      *----------------------------------------------------------------
     C     srUpdSfl      begsr
     C                   eval      vListPtr=uHeadPtr  + vOffset1stEnt           1st offset
 B01 C     1             do        vqentNum      x
     C     x             chain     data1
     C                   exsr      srTempqDS
     C                   exsr      srDataToDsp
     C                   update    data1
     C                   eval      vListPtr=uHeadPtr  + vNextEntry
 E01 C                   enddo
     C                   endsr
      *
      *----------------------------------------------------------------
      * Fill TempqDS from User Space Data.
      * Note: If Keyed data queue, then there is an unexplained 5 bytes at the beginning of
      * each key...  not sure if this a bug or an undocumented feature.
      * Also the size of the message entry could be larger than the message variable
      * allowed..  qTrimLen is used to make sure this doesn't blow up here|
      *----------------------------------------------------------------
     C     srTempqDS     begsr
     C                   eval      qTrimLen      = qMsgLength - ofs
 B01 C                   if        qAccessTyp ='K'                              keyed
 B02 C                   If        (5+qKeyLength)+qMsgLength > %size(vMsgVar)
     C                   eval      qTrimLen=%size(vmsgvar)-(5+qKeyLength)
 E02 C                   endif
 B02 C                   if        qTrimLen > %len(ViewqDS)
     C                   eval      qTrimLen = %len(ViewqDS)
 E02 C                   endif
     C                   eval      TempqDS =                                      extract message
     C                             %subst(vmsgvar:5+qKeyLength+ofs:qTrimLen)
 X01 C                   else
 B02 C                   If        qMsgLength > %size(vMsgVar)
     C                   eval      qTrimLen=%size(vmsgvar)
 E02 C                   endif
 B02 C                   if        qTrimLen > %len(ViewqDS)
     C                   eval      qTrimLen = %len(ViewqDS)
 E02 C                   endif
     C                   eval      TempqDS  = %subst(vmsgvar:1+ofs:qTrimLen)      extract message
 E01 C                   endif
     C                   endsr
      *----------------------------------------------------------------
      * Move Data to Display Field.
      *----------------------------------------------------------------
     C     srDataToDsp   begsr
 B01 C                   if        isHexMode
     C                   eval      ViewqDS = ''
     C                   callp     cvthc(%addr(ViewqDS)       :
     C                                   %addr(TempqDS)       :
     C                                   qTrimLen * 2         )
 X01 C                   else
     C                   eval      ViewqDS = %subst(TempqDS: 1      )
      *    -----------------------------------------------------------------------------------
      *    Drop anything below hex 40 before sending it to the screen.
      *    -----------------------------------------------------------------------------------
     C                   eval      ff= qTrimLen
 B02 C                   do        ff            aa
 B03 C                   if        %subst(ViewqDS:aa:1)<Hex40
     C                   eval      %subst(ViewqDS:aa:1)=' '
 E03 C                   endif
 E02 C                   enddo
 E01 C                   endif
     C                   endsr
