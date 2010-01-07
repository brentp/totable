#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
TODO
=====
* docstrings.
* allow specifying which columns are ints/floats.
* DONE: fix contains()
* DONE: indexes tctdbsetindex
* DONE: document between
* DONE: tune/optimize.
* DONE: document tuning params.
* DONE: __iter__ tctdbiternext.
* tctdbmetasearch
* see: tctdbqryproc for callbacks on queries.
* benchmark.
"""

cimport python_string as ps
cimport python_list as pl

DEF DEFAULT_OPTS = 0
TDBTLARGE = 1
TDBTDEFLATE = 1 << 1
TDBTBZIP = 1 << 2
TDBTTCBS = 1 << 3
TDBTEXCODEC = 1 << 4


tokyo_cabinet_version = c_tcversion
__version__ = '0.1.1'

class TCException(Exception):
    '''An error communicating with the Tokyo Cabinet database.'''

cdef class ToTable(object):
    """A Tokyo Cabinet table database.
    
    `path` is the path to the database file to be opened.
    `mode` either 'w' for write or 'r' for read.
    """
    cdef TCTDB* _state
    cdef readonly object path
    cdef readonly object mode

    def __repr__(self):
        c = self.__class__.__name__
        return "%s('%s')" % (c, self.path)
    
    def _throw(self, message='Error.'):
        '''Raises a TCException, appending to *message* the last error message
        from the table database.
        '''
        raise TCException(message + self._msg())
    
    cpdef _msg(ToTable self):
        '''Composes an error message for an exception, appending to the value
        of *message* the last error message from the table database.
        '''
        cdef int errorcode = tctdbecode(self._state)
        return tctdberrmsg(errorcode)


    def optimize(self, int64_t bnum=-1, int8_t apow=-1, int8_t fpow=-1, 
                 uint8_t opts=DEFAULT_OPTS):
        if self.mode != 'w':
            raise TCException('Unable optimize unless open with mode="w"')

        cdef bint success = tctdboptimize(self._state, bnum, apow, fpow, opts)
        if not success:
            self._throw('Unable to optimize {0}.'.format(self.path))
        return success

    def clear(self):
        cdef bint success = tctdbvanish(self._state)
        if not success:
            self._throw('Unable clear {0}'.format(self.path))
    
    def __cinit__(self, path, mode='r',
                 # tune params.
                 int64_t bnum=-1, int8_t apow=-1, 
                 int8_t fpow=-1, uint8_t opts=DEFAULT_OPTS,
                 #mmap (setxmsiz params
                 int64_t mmap_size=-1,
                 # cache params:
                 int32_t rcnum=-1, int32_t lcnum=-1, int32_t ncnum=-1):
        """
        'bnum' specifies the number of elements of the bucket array. If it is not more than 0, the default value is specified. The default value is 131071. Suggested size of the bucket array is about from 0.5 to 4 times of the number of all records to be stored.
        'apow' specifies the size of record alignment by power of 2. If it is negative, the default value is specified. The default value is 4 standing for 2^4=16.
        'fpow' specifies the maximum number of elements of the free block pool by power of 2. If it is negative, the default value is specified. The default value is 10 standing for 2^10=1024.
        'opts' specifies options by bitwise-or: `TDBTLARGE' specifies that the size of the database can be larger than 2GB by using 64-bit bucket array, `TDBTDEFLATE' specifies that each record is compressed with Deflate encoding, `TDBTBZIP' specifies that each record is compressed with BZIP2 encoding, `TDBTTCBS' specifies that each record is compressed with TCBS encoding.
        'mmap_size' is the size of mapped memory. default is 67,108,864 (64MB)
        'rcnum' is the max number of records to be cached. default is 0
        'lcnum' is the max number of leaf-nodes to be cached. default is 4096
        'ncnum' is the max number of non-leaf nodes cached. default is 512
        """
        self.path = path
        self.mode = mode
        cdef bint success
        self._state = tctdbnew()
        if bnum != -1 or apow != -1 or fpow != -1 or opts != DEFAULT_OPTS:
            success = tctdbtune(self._state, bnum, apow, fpow, opts)
            if not success:
                self._throw('Unable to tune {0}.'.format(str(path)))
        if mmap_size != -1:
            success = tctdbsetxmsiz(self._state, mmap_size)
            if not success:
                self._throw('Unable to set mmap size {0}.'.format(path))
        if rcnum > -1 or lcnum > -1 or ncnum > -1: 
            success = tctdbsetcache(self._state, rcnum, lcnum, ncnum)
            if not success:
                self._throw('Unable to setcache {0}.'.format(self.path))

        success = tctdbopen(self._state, path, 6 if mode=='w' else 1)
        if not success:
            self._throw('Unable to open %s' % (str(path), ))
    
    def close(self):
        '''Closes the database file and cleans memory, rendering this
        object useless.
        '''
        if not self._state == NULL:
            tctdbdel(self._state)
            self._state = NULL

    cdef TCMAP* _dict_to_tcmap(self, dict d):
        """INTERNAL: take a dict and return the tcmap which must
        be deleted with tcmapdel(tcmap)
        """
        cdef char *kbuf, *vbuf
        cdef Py_ssize_t ksiz, vsiz
        cdef TCMAP *tcmap
        cdef int ld = len(d)
        tcmap = tcmapnew2(ld)

        for key, val in d.items():
            ps.PyString_AsStringAndSize(key, &kbuf, &ksiz)
            ps.PyString_AsStringAndSize(val, &vbuf, &vsiz)
            tcmapput(tcmap, kbuf, ksiz, vbuf, vsiz)
        return tcmap

    def optimize_index(self, colname): 
        return self.create_index(colname, 'o')
    def delete_index(self, colname):
        return self.create_index(colname, 'v')

    cpdef bint create_index(ToTable self, char* colname, idx_type):
        """
        idx_type is one of:
           's' for index on a string
        or 'd' for index on a decimal number.
        """
        idx_lookup = {'s': TDBITLEXICAL, 'd': TDBITDECIMAL, 
                      'o': TDBITOPT, 'v': TDBITVOID }
        cdef int type = idx_lookup[idx_type]
        return tctdbsetindex(self._state, colname, type)

    def put(ToTable self, k, dict d, mode='p'):
        """ mode is one of p, k, c
        'c' is put cat, which adds items to an existing dict.
        'p' is put just writes to the key without regard for what's there
        'k' will only put the new data if there is nothing currently at
            that key.
        """

        cdef TCMAP * tcmap = self._dict_to_tcmap(d)
        cdef char *kbuf
        cdef Py_ssize_t ksiz
        cdef bint success 
        ps.PyString_AsStringAndSize(k, &kbuf, &ksiz)
        if mode == 'c':
            success = tctdbputcat(self._state, kbuf, <int>ksiz, tcmap)
            if not success:
                if not k in d:
                    self._throw('Error: attempting to add to '\
                            'non-existing key: %s' % k)
        elif mode == 'p':
            success = tctdbput(self._state, kbuf, <int>ksiz, tcmap)
            if not success:
                self._throw('error in put ' + k + ' ' + str(d))
        elif mode == 'k':
            success = tctdbputkeep(self._state, kbuf, ksiz, tcmap)
            return self._put_keep_code(success, k)
        else:
            raise TCException('mode must be one of p/k/c')

    
    def __setitem__(self, k, d):
        cdef TCMAP * tcmap = self._dict_to_tcmap(d)
        cdef char *kbuf
        cdef Py_ssize_t ksiz
        cdef bint success
        ps.PyString_AsStringAndSize(k, &kbuf, &ksiz)
        success = tctdbput(self._state, kbuf, ksiz, tcmap)
        tcmapdel(tcmap)

        if not success:
            self._throw('Unable to write to '+ str(k))

    cdef dict _tcmap_to_dict(ToTable self, TCMAP *tcmap):
        cdef dict d = {}
        tcmapiterinit(tcmap)
        cdef int ksiz, vsiz

        cdef char *vptr, *kptr = <char *>tcmapiternext(tcmap, &ksiz)
        while kptr != NULL:
            vptr = <char *>tcmapget(tcmap, <void *>kptr, ksiz, &vsiz)

            pykey = ps.PyString_FromStringAndSize(kptr, <Py_ssize_t>ksiz)
            pyval = ps.PyString_FromStringAndSize(vptr, <Py_ssize_t>vsiz)
            d[pykey] = pyval

            kptr = <char *>tcmapiternext(tcmap, &ksiz)

        return d


    cdef dict _key_to_dict(ToTable self, key):
        """INTERNAL: take the database key and return
        the dicitonary associated with that key"""
        cdef char *kbuf
        cdef Py_ssize_t ksiz
        ps.PyString_AsStringAndSize(key, &kbuf, &ksiz)
        cdef TCMAP *tcmap = tctdbget(self._state, kbuf, <int>ksiz)
        if tcmap == NULL:
            raise KeyError('Lookup failed: ' + str(key))

        cdef dict d = self._tcmap_to_dict(tcmap)
        tcmapdel(tcmap)
        return d

    cdef inline dict _ckey_to_dict(ToTable self, char *kbuf, int ksiz):
        cdef TCMAP *tcmap = tctdbget(self._state, kbuf, <int>ksiz)
        if tcmap == NULL:
            raise KeyError('Lookup failed: ' + str(kbuf))
        cdef dict d = self._tcmap_to_dict(tcmap)
        tcmapdel(tcmap)
        return d

    def __iter__(self):
        tctdbiterinit(self._state)
        return self

    def __next__(self):
        cdef TCMAP *tcmap = tctdbiternext3(self._state)
        if tcmap == NULL:
            raise StopIteration
        cdef dict d = self._tcmap_to_dict(tcmap)
        tcmapdel(tcmap)
        # the key is stored in the tcmap with its key as ''
        return d.pop(''), d


    def keep_or_put(self, k, d):
        '''Takes as arguments a key (string) and a value (dict).
        If the key already exists in the table, nothing is done
        and the string 'keep' is returned.
        Otherwise, the value is stored at the key and 'put' is returned.
        '''
        cdef char *kbuf
        cdef Py_ssize_t ksiz
        ps.PyString_AsStringAndSize(k, &kbuf, &ksiz)
        cdef TCMAP * tcmap = self._dict_to_tcmap(d)
        cdef bint success = tctdbputkeep(self._state, <void *>kbuf, 
                                          <int>ksiz, tcmap)

        tcmapdel(tcmap)
        return self._put_keep_code(success, k)

    cdef _put_keep_code(self, bint success, key):
        cdef int errorcode
        if not success:
            errorcode = tctdbecode(self._state)
            if errorcode == 21: # 'existing record'
                return 'keep'
            else:
                self._throw('Unable to write key "{0}".'.format(key))
        return 'put'
    
    def setdefault(self, k, d):
        '''Writes a record -- d[k] = d -- if k not in d.
        Then returns d[k].
        '''
        if self.keep_or_put(k, d) == 'keep':
            return self.get(k, d)
        else:
            return d # which certainly has just been put
    
    def __getitem__(self, key):
        '''Returns a record (as a dict) or raises KeyError.'''
        return self._key_to_dict(key)
    
    cpdef get(self, key, default=None):
        try:
            v = self._key_to_dict(key)
            return v or default
        except KeyError:
            return default
    
    def __delitem__(self, key):
        cdef char *kbuf
        cdef Py_ssize_t ksiz
        ps.PyString_AsStringAndSize(key, &kbuf, &ksiz)
        cdef bint success = tctdbout(self._state, kbuf, ksiz)
        if not success:
            raise KeyError(self._msg())
    
    def pop(self, k, d=None):
        '''D.pop(k[,d]) -> v, remove specified key and return the
        corresponding value. If key is not found, d is returned if given,
        otherwise KeyError is raised.
        '''
        adict = self.get(k)
        if adict is None:
            if d is None:
                raise KeyError('Key not found: "{0}"'.format(k))
            else:
                return d
        else:
            del self.k
            return adict
    
    cpdef int size_of(self, key):
        '''Returns the size of the value stored at the passed *id*,
        or -1 if the id does not exist in the table database.
        
        I don't know why this would be useful... the returned number is
        a little higher than the amount of characters persisted.
        '''
        cdef char *kbuf
        cdef Py_ssize_t   ksiz
        ps.PyString_AsStringAndSize(key, &kbuf, &ksiz)
        return tctdbvsiz(self._state, kbuf, <int>ksiz)
    
    def __contains__(self, key):
        '''True if D has a key *key*, else False.
        But know that calling D.get(id, defaultdict) is cheaper than
            d = D[id] if id in D else defaultdict
        '''
        return self.size_of(key) > -1
    
    def flush(self):
        '''Forces changes to be written to disk. Returns a success code.'''
        cdef bint success = tctdbsync(self._state)
        return success
    
    def __len__(self):
        return tctdbrnum(self._state)

    cdef void _set_limit(ToTable self, TDBQRY* query_state, dict kwargs):
        limit = kwargs.pop('limit', None) 
        offset = kwargs.pop('offset', None)
        if (limit is None and offset is None): return
        if limit is None: limit = -1
        if offset is None: offset = 0
        tctdbqrysetlimit(query_state, <int>limit, <int>offset)

    cdef void _set_callback(ToTable self, TDBQRY *query_state, dict kwargs):
        if not 'callback' in kwargs: return 
        pycallback = kwargs['callback']
        """
        def pycallback(key, value):
            return key, value
        """
        tctdbqryproc(query_state, self.get_proc(<void *>pycallback), NULL)

    cdef TDBQRYPROC get_proc(self, void * pycallback):
        # shrug.
        # cython/Demos/callback/cheese.pyx
        pass

    cdef void _set_order(ToTable self, TDBQRY* query_state, dict kwargs):
        if not 'order' in kwargs: return
        # TODO: handle nums. NUMASC, NUMDESC how?
        #"order='+name' or order='-name'
        col = kwargs['order']
        if col[0] not in ('+', '-'):
            direction = TDBQOSTRASC
        else:
            direction = TDBQOSTRASC if col[0] == '+' else TDBQOSTRDESC
            col = col[1:]
        tctdbqrysetorder(query_state, col, direction)

    def count(self, *args, **kwargs):
        kwargs['count'] = True
        return self.select(*args, **kwargs)

    def delete(self, *args, **kwargs):
        kwargs['delete'] = True
        return self.select(*args, **kwargs)

    def select(self, *args, bint values_only=False, **kwargs):
        # cool. mixing *args and a single kwarg with kwargs
        # not allowed in python 2.XX

        cdef TCQuery q = make_query(self._state)
        #cdef TDBQRY* query_state = tctdbqrynew(self._state)
        cdef TCLIST *tclist
        cdef list li = []
        cdef int count

        kwskip = ('delete', 'order', 'count', 'limit', 'offset', 'values_only', 'callback')

        # tbl.select(name='fred', age=22)
        # convert age=22 to Col('age') == 22
        args = list(args)
        for colname, other in kwargs.items():
            if colname in kwskip: continue
            args.append(Col(colname) == other)

        for col in args:
            # separate these out rather than |'ing here because
            # they may reuse the Col object.
            if col.invert:
                tctdbqryaddcond(q._state, <char *>col.colname, 
                                <int>(col.op | TDBQCNEGATE), <char *>col.other)
            else:
                tctdbqryaddcond(q._state, <char *>col.colname, <int>col.op, 
                                <char *>col.other)

        self._set_limit(q._state, kwargs)
        self._set_order(q._state, kwargs)
        self._set_callback(q._state, kwargs)
            
        if 'delete' in kwargs:
            return tctdbqrysearchout(q._state)

        tclist = tctdbqrysearch(q._state)
        # number of elements in the list
        count = tclistnum(tclist) 

        if 'count' in kwargs:
            tclistdel(tclist)
            return count

        li = self._tclist_to_list(tclist, count, values_only)
        tclistdel(tclist)
        return li


    cdef list _tclist_to_list(ToTable self, TCLIST *tclist, int count, 
                              bint values_only):
        # INTERNAL: the calling function is still responsible for deleting
        # tclist.
        cdef list li = []
        cdef char *kbuf
        cdef int ksiz, i
        cdef dict d
        for i in range(count):
            kbuf = <char *>tclistval(tclist, i, &ksiz)
            d = self._ckey_to_dict(kbuf, ksiz)
            if values_only:
                li.append(d)
            else:
                key = ps.PyString_FromStringAndSize(kbuf, <Py_ssize_t>ksiz)
                li.append((key, d))
        return li

cdef class Col(object):
    """
    TODO:
    tdb.query(Col('name') == 'Fred' & Col('age') > 22)
        or
    tdb.select(Q(name__in=['Fred', 'Wilma']), Q(name__contains="at2g"))
    """
    cdef readonly object colname
    cdef public int op
    cdef public object other
    cdef readonly dict num_lookups
    cdef readonly bint invert

    def __cinit__(self, colname):
        self.invert = False
        self.num_lookups= {
                0: TDBQCNUMLT, # <
                1: TDBQCNUMLE, # <=
                2: TDBQCNUMEQ, # ==
                3: TDBQCNUMEQ | TDBQCNEGATE, # !=. # TODO test.
                4: TDBQCNUMGT, # >
                5: TDBQCNUMGE  # >=
            } 
        self.colname = colname
    """
    void tctdbqryaddcond(TDBQRY *qry, const char *name, int op, const char *expr);
    `qry' specifies the query object.
    `name' specifies the name of a column. An empty string means the primary key.
    `op' specifies an operation type: 
    # the below are unimplemented.        
    `TDBQCSTRAND' for string which includes all tokens in the expression, 
    `TDBQCSTROR' for string which includes at least one token in the expression, 
    `TDBQCFTSPH' for full-text search with the phrase of the expression, 
    `TDBQCFTSAND' for full-text search with all tokens in the expression, 
    `TDBQCFTSOR' for full-text search with at least one token in the expression, 
    `TDBQCFTSEX' for full-text search with the compound expression. 
    """
    # http://docs.cython.org/docs/special_methods.html
    # < 0 | <= 1 | == 2 | != 3 |  > 4 | >= 5
    def __richcmp__(self, other, op):
        self.other = unicode(other)
        if isinstance(other, (int, long, float)):
            self.op = self.num_lookups[op]
        else:
            str_lookups= {
                2: TDBQCSTREQ, # ==
                3: TDBQCSTREQ | TDBQCNEGATE # not equal.
            } 
            self.op = str_lookups[op]
        return self

    def __invert__(self):
        # ~Col('age') == 180
        self.invert = not self.invert
        return self

    def matches(self, pattern):
        self.op = TDBQCSTRRX
        self.other = pattern
        return self

    def in_list(self, li):
        if isinstance(li[0], basestring):
            self.op = TDBQCSTROREQ if len(li) > 1 else TDBQCSTREQ
        else:
            self.op = TDBQCNUMOREQ if len(li) > 1 else TDBQCNUMEQ
            li = map(str, li)
        self.other = ' '.join(li)
        return self

    def like(self, other):
        assert isinstance(other, basestring)
        self.op = TDBQCSTRINC
        self.other = other
        return self

    def startswith(self, other):
        self.other = other
        self.op = TDBQCSTRBW
        return self

    def endswith(self, other):
        self.other = other
        self.op = TDBQCSTREW
        return self

    def between(self, low, high):
        self.other = str(low) + ' ' + str(high)
        self.op = TDBQCNUMBT
        return self

cdef class transaction(object):
    cdef ToTable table
    def __init__(self, ToTable t):
        self.table = t

    def __enter__(self):
        cdef bint success = tctdbtranbegin(self.table._state)
        if not success:
            self.table._throw()
    
    def __exit__(self, type, value, exc):
        cdef bint success
        if exc is None:
            success = tctdbtrancommit(self.table._state)
        else:
            success = tctdbtranabort(self.table._state)


cdef class TCMap(object):
    cdef TCMAP* _state
    def __del__(self):
        tcmapdel(self._state)

cdef TCMap make_tcmap():
    pass

# this class just useful as it cleans itself up.
# would be nicer to have this for tcmap...
cdef class TCQuery(object):
    cdef TDBQRY* _state
    def __dealloc__(self):
        tctdbqrydel(self._state)

cdef TCQuery make_query(TCTDB* tctdb):
    cdef TCQuery query = TCQuery()
    query._state = tctdbqrynew(tctdb)
    return query

