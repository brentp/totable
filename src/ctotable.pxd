cdef extern from "tctdb.h":
    char *c_tcversion "tcversion"
    ctypedef unsigned char uint8_t
    ctypedef unsigned char  int8_t
    ctypedef int           int32_t
    ctypedef int          uint32_t
    ctypedef int           int64_t
    ctypedef int          uint64_t
    ctypedef struct TDBIDX:
        pass
    ctypedef struct TCTDB:
        pass


    cdef enum:
        TDBITLEXICAL # 's'
        TDBITDECIMAL # 'd'
        # TODO qgram stuff for FTS
        TDBITOPT = 9998 # 'o'
        TDBITVOID = 9999 # 'v'

    ctypedef struct TDBQRY:
        pass
    cdef enum:                 # Query conditions
        TDBQCSTREQ             # string is equal to */
        TDBQCSTRINC            # string is included in */
        TDBQCSTRBW             # string begins with */
        TDBQCSTREW             # string ends with */
        TDBQCSTRAND            # string includes all tokens in */
        TDBQCSTROR             # string includes at least one token in */
        TDBQCSTROREQ           # string is equal to at least one token in */
        TDBQCSTRRX             # string matches regular expressions of */
        TDBQCNUMEQ             # number is equal to */
        TDBQCNUMGT             # number is greater than */
        TDBQCNUMGE             # number is greater than or equal to */
        TDBQCNUMLT             # number is less than */
        TDBQCNUMLE             # number is less than or equal to */
        TDBQCNUMBT             # number is between two tokens of */
        TDBQCNUMOREQ           # number is equal to at least one token in */
        TDBQCNEGATE = 1 << 24  # negation flag */
        TDBQCNOIDX = 1 << 25   # no index flag */
    cdef enum:                 # Query order
        TDBQOSTRASC
        TDBQOSTRDESC
        TDBQONUMASC
        TDBQONUMDESC
    ctypedef struct TCLISTDATUM: # type of structure for an element of a list */
        pass
    ctypedef struct TCLIST: # type of structure for an array list */
        pass
    ctypedef struct TCMAPREC:       # an element of a map
        pass
    ctypedef struct TCMAP: # represents a table row
        pass

    int tctdbstrtoindextype(char *str)
    char *tctdberrmsg      (int ecode)
    TCTDB *tctdbnew    ()
    void tctdbdel      (TCTDB *tdb)
    int tctdbecode     (TCTDB *tdb)
    bint tctdbsetmutex(TCTDB *tdb)

    bint tctdbtune(TCTDB *tdb, int64_t bnum, int8_t apow, int8_t fpow, uint8_t opts)
    bint tctdboptimize(TCTDB *tdb, int64_t bnum, int8_t apow, int8_t fpow, uint8_t opts)
    bint tctdbsetindex(TCTDB *tdb, char *name, int type)
    bint tctdbsetcache(TCTDB *tdb, int32_t rcnum, int32_t lcnum, int32_t ncnum)
    bint tctdbsetxmsiz(TCTDB *tdb, int64_t xmsiz)

    bint tctdbsetcache(TCTDB *tdb, int32_t rcnum, int32_t lcnum, int32_t ncnum)
    bint tctdbsetxmsiz(TCTDB *tdb, int64_t xmsiz)
    bint tctdbopen    (TCTDB *tdb, char *path, int omode)
    bint tctdbclose   (TCTDB *tdb)
    bint tctdbsync    (TCTDB *tdb) # flush
    bint  tctdbput    (TCTDB *tdb, void *pkbuf, int pksiz, TCMAP *cols)
    bint  tctdbputcat (TCTDB *tdb, void *pkbuf, int pksiz, TCMAP *cols)
    bint  tctdbout    (TCTDB *tdb, void *pkbuf, int pksiz) # deletes a row
    int   tctdbvsiz    (TCTDB *tdb, void *pkbuf, int pksiz) # row size
    uint64_t tctdbrnum (TCTDB *tdb)    # number of records in table
    bint tctdbputkeep (TCTDB *tdb, void *pkbuf, int pksiz, TCMAP *cols)
    bint tctdbiterinit(TCTDB *tdb)
    TCMAP *tctdbiternext3(TCTDB *tdb)
    bint tctdbtranbegin(TCTDB *tdb)
    bint tctdbtrancommit(TCTDB *tdb)
    bint tctdbtranabort(TCTDB *tdb)
    

    bint tctdbvanish(TCTDB *tdb)
    # Maps
    TCMAP *tctdbget    (TCTDB *tdb, void *pkbuf, int pksiz)
    char *tctdbget3(TCTDB *tdb, char *pkstr)

    TCMAP *tcmapnew2(uint32_t bnum)
    TCMAP *tcmapnew3(char *str, ...)
    void tcmapdel      (TCMAP *map)
    void tcmapput      (TCMAP *map, void *kbuf, int ksiz, void *vbuf, int vsiz)
    void tcmapiterinit (TCMAP *map)
    void *tcmapiternext(TCMAP *map, int *sp)
    char *tcmapiternext2(TCMAP *map)
    void *tcmapget     (TCMAP *map, void *kbuf, int ksiz, int *sp)
    char *tcmapget2    (TCMAP *map, char *kstr)
    # Queries
    TDBQRY *tctdbqrynew    (TCTDB *tdb) # create query
    void tctdbqrydel       (TDBQRY *qry)   # release query
    TCLIST *tctdbqrysearch (TDBQRY *qry)   # execute
    bint tctdbqrysearchout(TDBQRY *qry)   # execute deleting all matches
    void tctdbqryaddcond   (TDBQRY *qry, char *name, int op, char *expr)
    void tctdbqrysetorder  (TDBQRY *qry, char *name, int type)
    void tctdbqrysetlimit  (TDBQRY *qry, int max, int skip)
    void tclistdel  (TCLIST *list)
    int  tclistnum  (TCLIST *list)
    void *tclistval (TCLIST *list, int index, int *sp)
    char *tclistval2(TCLIST *list, int index)

    # callbacks:
    #ctypedef struct TDBQRYPROC:
        #pass
    ctypedef int (*TDBQRYPROC)(void *pkbuf, int pksiz, TCMAP *cols, void *op)
    bint tctdbqryproc(TDBQRY *qry, TDBQRYPROC proc, void *op)
    #type of the pointer to a iterator function for each table record.
    #`pkbuf' specifies the pointer to the region of the primary key.
    #`pksiz' specifies the size of the region of the primary key.
    #`cols' specifies a map object containing columns.
    #`op' specifies the pointer to the optional opaque object.
    #The return value is flags of the post treatment by bitwise-or: `TDBQPPUT' to modify the
    #record, `TDBQPOUT' to remove the record, `TDBQPSTOP' to stop the iteration. */
    

