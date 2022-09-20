DSPDTAQ - A Craig Rutledge and Tools/400 Utility
------------------------------------------------

DSPDTAQ is a simple utility for displaying the content of a given
data queue. The utility does not change or even remove queue entries.

Dependencies: *NONE

Compile members with the following PDM option:

   STRPREPRC USESRCFILE(&L/&F) USESRCMBR(&N) OPTION(*EVENTF) CHGOBJD(*NO)
     LIB(&O) OBJ(&N) SRCLIB(&L) SRCFILE(&F) SRCMBR(&N) USER0(&X)
     USER1(*LIST) USER2(*FULL)

Members of type MAKPGM or BND are used for linking programs (MAKPGM)
and service programs (BND).

2022, Thomas Raddatz
