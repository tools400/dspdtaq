**free
//----------------------------------------------------------------
// DSPDQER  - Display Data Queue Entries                     v4r2
// Copyright (C) 06/11/1993  Craig Rutledge   <craig_rutledge@mohawkind.com>
// This program is free software, you can redistribute it and/or modify it under the terms
// of the GNU General Public License as published by the Free Software Foundation.
// --------
//
// 5/7/2001 V2 - rewrite.  Replace DMPOBJ logic with API to do
// non-destructive display of dataq entries as messages.
//
// Thanks to Dennis Lovelady (www.lovelady.com) this program now uses
// a user space as a retrieve variable.  Not quite a documented
// feature, but it works| Now you can retrieve up to 12Meg of entries.
// If this technique causes anyone problems, please advise me.
//
// I do NOT understand 1) why IBM made this API so radically different
// than the normal qrcvdatq call.  2) why in heck they didn't make
// this a user space api or at least give a continuation handle so
// I could get all entries.  Almost makes you want to learn Unix.
// 6/25/2001 - scan through entries before they are sent to screen to make sure no
// hex data less than x'40' is embedded.
// 11/09/2001 - Thomas Raddatz: Changed F4 to F11 to unfold/fold subfile.
//                              Added hexadecimal display mode.
//                              Added data column offset.
// 12/05/2001 - Craig Rutledge: Subfile remains on same screen during Fkeys.
//                              Added F19-column shift left
//                              Added F20-column shift right
// PTF note:  Api qmhrdqm requires PTF
// sf63313 v4r2, sf63312 v4r3, sf62994 v4r4, sf63182 v5r1
// be installed on your system to view keyed data queue entrys.
//----------------------------------------------------------------
// Program Summary:
// Call API to retrieve data queue object description
// Extract entries and load to subfile
// Display subfile
//----------------------------------------------------------------
// API (application program interfaces) used:
// QMHQRDQD  display data queue object description
// QMHRDQM   retrieve dataq entries
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
ctl-opt bnddir('QC2LE') expropts(*resdecpos);
ctl-opt datfmt(*iso) timfmt(*iso) option(*nodebugio);
/copy QDSPDTAQ,COPYRIGHT

dcl-f dspdtaqd workstn(*ext) usage(*input: *output) sfile(data1: rrn1) infds(dsinf);
//----------------------------------------------------------------
//  allow subfile to stay on current screen
dcl-ds dsinf;
  bgrrn int(5) pos(378);
end-ds;
dcl-s bgrrnsav like(bgrrn);

dcl-s rrn1 uns(5);
dcl-s torecNum uns(5);
dcl-s aa uns(5) inz;
dcl-s ff uns(5) inz;
dcl-s mvr uns(5) inz;
dcl-s Shift uns(5) inz(58);
dcl-s hex40 char(1) inz(x'40');
dcl-c cSflPag 7;
dcl-s sflDspPag int(10);

//----------------------------------------------------------------
// Define parms for QMHQRDQD retrieve dataq description.
//----------------------------------------------------------------
dcl-ds qrcvar inz;
  qMsgLength int(10) pos(9);
  qKeyLength int(10) pos(13);
  qAccessTyp char(1) pos(17);
  qText      char(50) pos(20);
  qTrimLen   int(10) inz;
end-ds;
dcl-s v0200len int(10);
dcl-s ExitPgmFlg char(1) inz(*off);

//----------------------------------------------------------------
// Define parms for QMHRDQM retrieve dataq entries
//----------------------------------------------------------------
dcl-ds vrcvar based(uheadptr);
  vBytesReturned int(10) pos(1);
  vBytesAvail    int(10) pos(5);
  vNumMsgRtn     int(10) pos(9);
  vNumMsgAvl     int(10) pos(13); //
  vKeyLenRtn     int(10) pos(17);
  vKeyLenAvl     int(10) pos(21);
  vMsgTxtRtn     int(10) pos(25);
  vMsgTxtAvl     int(10) pos(29);
  vEntryLenRtn   int(10) pos(33);
  vEntryLenAvl   int(10) pos(37);
  vOffset1stEnt  int(10) pos(41);
  vQLib          char(10) pos(45);
  vMessageData   varchar(32767);
end-ds;
dcl-s uheadptr pointer inz(*null);

//      -------------------------------------------------------------------------------------
//      Move pointer through message entries
//      -------------------------------------------------------------------------------------
dcl-ds vListEntry based(vListPtr);
  vNextEntry int(10);
  vDateTime  char(8); // TOD format
  vMsgVar    char(32767); // variable text
end-ds;

//      -------------------------------------------------------------------------------------
//      Message selection info - RDQS0100 nonkeyed queues  RDQS0200 Keyed data queues
//      -------------------------------------------------------------------------------------
dcl-ds vRDQS0100;
  v1Selection  char(1) inz('A'); // all
  v1Reserved   char(3);
  v1MsgByteRtv int(10) inz pos(5); // message bytes to
end-ds;

dcl-ds vRDQS0200;
  v2Selection  char(1) inz('K'); // Keyed
  v2KeyOrder   char(2) inz('GE');
  v2MsgByteRtv int(10) inz pos(5); // message bytes to
  v2KeyByteRtv int(10) inz pos(9); // keys bytes to rtv
  v2KeyLen     int(10) inz pos(13); // key length
  v2Key        char(256) pos(17); // key value
end-ds;

//----------------------------------------------------------------
// get entry date and time from API
//----------------------------------------------------------------
dcl-ds dtDS len(16); // extract C YYMMDD
  dtFiller char(1);
  dtMDY    char(6);
  dtTIME   char(6);
end-ds;

//----------------------------------------------------------------
// Divide entry up into subfile fields
//----------------------------------------------------------------
dcl-ds ViewqDS;
  Viewq1;
  Viewq2;
end-ds;
dcl-s TempqDS char(116);
dcl-s isHexMode ind inz(*off);
dcl-s ofs int(10) inz;
dcl-s ColumnShift int(10) inz;
dcl-s x int(10) inz;

//@formatter:off
dcl-c cRuler1 '....+....1....+....2....+....3....+....4....+....5....+....+
              6....+....7....+....8....+....9....+....0....+....1....+....+
              2....+....3....+....4....+....5....+....6....+....7....+....+
              8....+....9....+....0....+....1....+....2';

dcl-c cRuler2 '. . . . + . . . . 1 . . . . + . . . . 2 . . . . + . . . . +
             3 . . . . + . . . . 4 . . . . + . . . . 5 . . . . + . . . . +
             6 . . . . + . . . . 7 . . . . + . . . . 8 . . . . + . . . . +
             9 . . . . + . . . . 0 . . . . + . . . . 1 . . . . + . . . . +
             2 . . . . + . . . . 3 . . . . + . . . . 4 . . . . + . . . . +
             5 . . . . + . . . . 6 . . . . + . . . . 7 . . . . + . . . . +
             8 . . . . + . . . . 9 . . . . + . . . . 0 ';
//@formatter:on

//----------------------------------------------------------------
// Error return code parm for APIs.
//----------------------------------------------------------------
dcl-ds vApiErrDs;
  vbytpv  int(10) inz(%size(vApiErrDs)); // bytes provided
  vbytav  int(10) inz(0); // bytes returned
  vmsgid  char(7); // error msgid
  vresvd  char(1); // reserved
  vrpldta char(50); // replacement data
end-ds;

//-------------------------------------------------------------------------------------------
// Create Prototypes for calls
//-------------------------------------------------------------------------------------------
dcl-pr qwccvtdt extpgm('QWCCVTDT'); // api date converte
  *n char(10) const; // FROM FORMAT
  *n char(8); // API DATE STAMP
  *n char(10) const; // TO FORMAT
  *n like(dtDS); // TO DATE
  *n like(vApiErrDS); // error parm
end-pr;
//    -------------------------------------------------------------
dcl-pr qmhqrdqd extpgm('QMHQRDQD'); // data q descriptio
  *n like(qrcvar); // RECIEVER
  *n int(10) const; // LENGTH
  *n char(8) const; // FORMAT
  *n char(20); // Q NAME & LIB
end-pr;
//    -------------------------------------------------------------
dcl-pr qmhrdqm extpgm('QMHRDQM '); // get q entry
  *n like(vrcvar); // RECIEVER Options(*varsize)
  *n int(10) const; // LENGTH
  *n char(8) const; // FORMAT
  *n char(20); // Q NAME & LIB
  *n like(vRDQS0200) options(*varsize); // KEY INFORMATION const
  *n int(10) const; // KEY INFO LENGTH
  *n char(8) const; // INFORMATION
  *n like(vApiErrDS) options(*varsize); // error data struct
end-pr;
//    -------------------------------------------------------------
dcl-pr quscrtus extpgm('QUSCRTUS'); // create user space
  *n char(20); // Space Name
  *n char(10) const; // Extended Attrb
  *n int(10) const; // length of space
  *n char(1) const; // Hex0Init
  *n char(10) const; // Use Authority
  *n char(50) const; // text
  *n char(10) const; // replace object
  *n like(vApiErrDS); // error parm
end-pr;
//    -------------------------------------------------------------
dcl-s uSpaceName char(20) inz('JCRCMDS   QTEMP     ');
dcl-pr qusptrus extpgm('QUSPTRUS'); // retrieve pointer
  *n char(20); // Space Name
  *n pointer; // pointer
  *n like(vApiErrDS); // error parm
end-pr;
//    -------------------------------------------------------------
dcl-pr cvthc extproc('cvthc'); // Cvt. Hex to Char
  i_receiver  pointer value;
  i_source    pointer value;
  i_numSrcNib int(10) value;
end-pr;
//    -------------------------------------------------------------
dcl-pr main extpgm('DSPDQER ');
  i_qnamlib char(20); // NAME LIB 20
  i_qobjtyp char(10);
end-pr;
//    -------------------------------------------------------------
dcl-pi main;
  i_qnamlib char(20);
  i_qobjtyp char(10);
end-pi;
// --------------------------------------------------------------------
// Stand Alone Fields - TOP
// --------------------------------------------------------------------
dcl-s do_x1 packed(7);
// --------------------------------------------------------------------
// Stand Alone Fields - BOTTOM
// --------------------------------------------------------------------
//-------------------------------------------------------------------------------------------
vqname=%subst(i_qnamlib:1:10);
vSflMode = *on;
*in03    = vSflMode;                                                     // subfile mode
vpos     = 1;

// create object list user space
QUSCRTUS(                                                                // CREATE USER SPC
uSpaceName:                                                              // CREATE USER SPC
'TEST':                                                                  // EXTENDED ATRIB
13000000:                                                                // SIZE IN BYTES
x'00':                                                                   // INITIAL VALUE
'*ALL':                                                                  // AUTHORITY
'List Objects  ':                                                        // TEXT
'*NO ':                                                                  // REPLACE OBJ
vApiErrDs);                                                              // ERROR

// Get pointer to object list user spaces
QUSPTRUS(                                                                // GET POINTER TO SP
uSpaceName:                                                              // SPACE    LIB
uHeadPtr:                                                                // pointer to header
vApiErrDs);                                                              // error

// Call API to retrieve data queue description.
QMHQRDQD(
qrcvar:                                                                  // DATA STRUCT
%size(qrcvar):                                                           // SIZE
'RDQD0100':                                                              // TYPE FORMAT
i_qnamlib);                                                              // NAME LIB

// Setup a looping subroutine so user can refresh screen
dou ExitPgmFlg=*on;
  exsr RefreshScreen;
enddo;
*inlr = *on;                                                             // PROGRAM END
return;

//----------------------------------------------------------------
// Call API to retrieve data queue entries
//   Different type dataqs require a different parm list to the API.
//----------------------------------------------------------------
begsr RefreshScreen;
  if qAccessTyp ='K';                                                   // keyed
    vacsType = '*KEYED';
    v2MsgByteRtv = qMsgLength;                                         // message bytes to
    v2KeyByteRtv = qKeyLength;                                         // keys bytes to rtv
    v2KeyLen = qKeyLength;                                             // keys length to rt
    v0200Len=16+qKeyLength;                                            // len of info
    QMHRDQM(
    vrcvar:                                                            // return variable
    12000000:                                                          // len of return var
    'RDQM0200':                                                        // return format
    i_qnamlib:                                                         // NAME LIB
    vRDQS0200:                                                         // key information
    v0200Len:                                                          // key information l
    'RDQS0200':                                                        // information forma
    vApiErrDS);                                                        // error data struct
  else;
    //  non keyed
    vacsType = '*NON-KEYED';
    v1MsgByteRtv = qMsgLength;                                         // message bytes to
    QMHRDQM(
    vrcvar:                                                            // return variable
    12000000:                                                          // len of return var
    'RDQM0100':                                                        // return format
    i_qnamlib:                                                         // NAME LIB
    vRDQS0100:                                                         // key information
    %size(vRDQS0100):                                                  // key information l
    'RDQS0100':                                                        // information forma
    vApiErrDS);                                                        // error data struct
  endif;

  //-------------------------------------------------------------------------------------------
  // Spin through the dataq entries.
  //   Convert API date/time stamp to human-readable.
  //     Load to subfile.
  //-------------------------------------------------------------------------------------------
  clear rrn1;
  if vNumMsgRtn >  0;                                                   // there are entries

    //      -----------------------------------------------------------------
    //      Move pointer through message entries
    //      -----------------------------------------------------------------
    vListPtr=uHeadPtr  + vOffset1stEnt;                                // 1st offset
    for do_x1 = 1 to vNumMsgRtn;
      exsr DecodeDate;
      exsr srTempqDS;
      exsr srDataToDsp;
      rrn1=rrn1+1;
      write data1;
      if rrn1=9999;                                                   // subfile full
        leave;
      endif;
      vListPtr=uHeadPtr  + vNextEntry;
    endfor;
  endif;

  //----------------------------------------------------------------
  // Display subfile.  Calc number of screens in subfile.
  //----------------------------------------------------------------
  vSrecNum=1;
  ColumnShift=0;
  vlen          = qMsgLength;
  vqTotCnt      = vNumMsgAvl;                                           // total number of e
  dou 1=2;

    x = ofs + 1;
    dow x > 100;
      x = x - 100;
    enddo;

    if isHexMode;
      vRuler = %subst(cRuler2: (x*2)-1);
    else;
      vRuler = %subst(cRuler1: x);
    endif;

    if ofs = 0;
      %subst(vRuler: 1: 1) = '*';
    endif;

    if vSflMode = *on;
      sflDspPag = cSflPag * 2;
    else;
      sflDspPag = cSflPag;
    endif;

    vqentNum = rrn1;                                                   // # Q ENTRIES
    //    C     rrn1          div       sflDspPag     vScrnNum               // # OF SCREENS
    //    C                   mvr                     mvr
    vScrnNum = %div(rrn1 : sflDspPag);
    mvr = %rem(rrn1 : sflDspPag);
    if mvr>0;                                                          // OVERFLOW SCREENS
      vScrnNum =  vScrnNum+1;
    endif;

    *in20=(rrn1>sflDspPag);                                            // more
    *in01=(rrn1>0);                                                    // SFLDSP
    *in02 = *on;                                                       // SFLDSPCTL

    write header;                                                      //  DISPLAY
    exfmt contrl1;                                                     //  SCREENS
    *in03 = vSflMode;
    // exit / cancel
    select;
    when *inkc or *inkl;
      ExitPgmFlg=*on;
      // v4r4---          leavesr
      leavesr;                                                        // F3=exit    v4r2

    // refresh
    when *inke;                                                        // F5=refresh
      rrn1=0;
      *in01=*off;
      *in02=*off;
      write contrl1;                                                  // clear
      // v4r4---          leavesr                                                F5=REFRESH
      leavesr;                                                        // F5=REFRESH v4r2

    // change display mode
    when *inkj;                                                        // F10=Hex
      if isHexMode;
        isHexMode = *off;
        Shift=58;
      else;
        isHexMode = *on;
        Shift=25;
      endif;
      bgrrnSav=bgrrn;
      exsr srUpdSfl;
      bgrrn=bgrrnSav;
    // fold/unfold
    when *inkk;                                                        // F11=Fold/Unfold
      if vSflMode = *on;
        vSflMode = *off;
      else;
        vSflMode = *on;
      endif;
      *in03 = vSflMode;

    // shift column position to the left
    when *inkt;                                                        // F19=column left
      ColumnShift=ColumnShift-Shift;
      if ColumnShift<0;
        ColumnShift=1;
      endif;
      vdspPos=ColumnShift;

    // shift column position to the right
    when *inku;                                                        // F20=column right
      ColumnShift=ColumnShift+Shift;
      if ColumnShift >= qMsgLength;
        ColumnShift =  qMsgLength - 1;
      endif;
      vdspPos=ColumnShift;
    endsl;

    //   ---------------------------------------------------------------
    //   Determine which screen the user wants to display.
    //   ---------------------------------------------------------------
    if vdspNum = 0;                                                    // screen field=0
      if bgrrn=0;
        bgrrn=1;
      endif;
      vsrecNum = bgrrn;
    else;
      torecNum = vdspNum * sflDspPag;
      if torecNum < rrn1;                                             // NOT PAST EOF
        vsrecNum      = torecNum;
      else;
        vsrecNum      = rrn1;                                        // PAST EOF SELCTD
      endif;
    endif;

    //   ---------------------------------------------------------------
    //   Determine the column offset the user wants to display.
    //   ---------------------------------------------------------------
    if vdspPos > 0;
      ofs = vdspPos - 1;
      if ofs < 0;
        ofs = 0;
      endif;
      if ofs >= qMsgLength;
        ofs = qMsgLength - 1;
      endif;
      exsr srUpdSfl;
      vpos    = ofs + 1;
      vdspPos = 0;
    endif;

    clear vdspNum;                                                     // REINIT
    clear torecNum;
  enddo;
endsr;

//----------------------------------------------------------------
// Decode the Date-Time_Stamp into MM/DD/YY and HH:MM:SS
//----------------------------------------------------------------
begsr DecodeDate;
  QWCCVTDT(                                                             // API DATE CONVRT
  '*DTS    ':                                                           // FROM FORMAT
  vDateTime :                                                           // TO BE CONVERTED
  '*MDY    ':                                                           // TO FORMAT
  dtDS  :                                                               // CONVERTED DATE
  vApiErrDs);
  qudate=%subst(dtMDY:1:2) + '/' +
  %subst(dtMDY:3:2) +'/'+ %subst(dtMDY:5:2);
  qutime=%subst(dtTIME:1:2) + ':' +
  %subst(dtTIME:3:2) +':'+ %subst(dtTIME:5:2);
endsr;

//----------------------------------------------------------------
// Update Subfile.
//----------------------------------------------------------------
begsr srUpdSfl;
  vListPtr=uHeadPtr  + vOffset1stEnt;                                   // 1st offset
  for x = 1 to vqentNum;
    chain x data1;
    exsr srTempqDS;
    exsr srDataToDsp;
    update data1;
    vListPtr=uHeadPtr  + vNextEntry;
  endfor;
endsr;

//----------------------------------------------------------------
// Fill TempqDS from User Space Data.
// Note: If Keyed data queue, then there is an unexplained 5 bytes at the beginning of
// each key...  not sure if this a bug or an undocumented feature.
// Also the size of the message entry could be larger than the message variable
// allowed..  qTrimLen is used to make sure this doesn't blow up here|
//----------------------------------------------------------------
begsr srTempqDS;
  qTrimLen      = qMsgLength - ofs;
  if qAccessTyp ='K';                                                   // keyed
    If (5+qKeyLength)+qMsgLength > %size(vMsgVar);
      qTrimLen=%size(vmsgvar)-(5+qKeyLength);
    endif;
    if qTrimLen > %len(ViewqDS);
      qTrimLen = %len(ViewqDS);
    endif;
    TempqDS =                                                          //   extract message
    %subst(vmsgvar:5+qKeyLength+ofs:qTrimLen);
  else;
    If qMsgLength > %size(vMsgVar);
      qTrimLen=%size(vmsgvar);
    endif;
    if qTrimLen > %len(ViewqDS);
      qTrimLen = %len(ViewqDS);
    endif;
    TempqDS  = %subst(vmsgvar:1+ofs:qTrimLen);                         //   extract message
  endif;
endsr;
//----------------------------------------------------------------
// Move Data to Display Field.
//----------------------------------------------------------------
begsr srDataToDsp;
  if isHexMode;
    ViewqDS = '';
    cvthc(%addr(ViewqDS)       :
         %addr(TempqDS)       :
         qTrimLen * 2         );
  else;
    ViewqDS = %subst(TempqDS: 1      );
    //    -------------------------------------------------------------------
    //    Drop anything below hex 40 before sending it to the screen.
    //    -------------------------------------------------------------------
    ff= qTrimLen;
    for aa = 1 to ff;
      if %subst(ViewqDS:aa:1)<Hex40;
        %subst(ViewqDS:aa:1)=' ';
      endif;
    endfor;
  endif;
endsr;
