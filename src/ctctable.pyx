#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
TODO
=====
* docstrings.
* document tuning params.
* document between
* indexes tctdbsetindex
* allow specifying which columns are ints/floats.
* DONE: tune/optimize.
* STARTED: make a class for tcmap
* tctdbcopy (backup).
* benchmark.
"""

cimport python_string as ps
DEF DEFAULT_OPTS = 0

tokyo_cabinet_version = c_tcversion
__version__ = '0.1.1'

class TCException(Exception):
    '''An error communicating with the Tokyo Cabinet database.'''

cdef class TCTable(object):
    """A Tokyo Cabinet table database.
    
    `path` is the path to the database file to be opened.
    `mode` either 'w' for write or 'r' for read.
    """
    cdef TCTDB* _state
    cdef readonly object path
    cdef readonly object mode
    cdef bint is_open

    def __repr__(self):
        c = self.__class__.__name__
        return "%s('%s')" % (c, self.path)
    
    def _throw(self, message='Error.'):
        '''Raises a TCException, appending to *message* the last error message
        from the table database.
        '''
        raise TCException(self._msg(message))
    
    def _msg(self, message='Error.'):
        '''Composes an error message for an exception, appending to the value
        of *message* the last error message from the table database.
        '''
        cdef int errorcode = tctdbecode(self._state)
        msg = <char*>tctdberrmsg(errorcode)
        return message + ' ' + msg.capitalize()

    def optimize(self, int64_t bnum=-1, int8_t apow=-1, int8_t fpow=-1, uint8_t opts=DEFAULT_OPTS):
        if self.mode != 'w':
            raise TCException('Unable optimize unless open with mode="w"')

        cdef bint success = tctdboptimize(self._state, bnum, apow, fpow, opts)
        if not success:
            self._throw('Unable to optimize {0}.'.format(str(self.path)))
        return success
    
    def __init__(self, path, mode='r', int64_t bnum=-1, int8_t apow=-1, int8_t fpow=-1, uint8_t opts=DEFAULT_OPTS):
        """
        'bnum' specifies the number of elements of the bucket array. If it is not more than 0, the default value is specified. The default value is 131071. Suggested size of the bucket array is about from 0.5 to 4 times of the number of all records to be stored.
        'apow' specifies the size of record alignment by power of 2. If it is negative, the default value is specified. The default value is 4 standing for 2^4=16.
        'fpow' specifies the maximum number of elements of the free block pool by power of 2. If it is negative, the default value is specified. The default value is 10 standing for 2^10=1024.
        'opts' specifies options by bitwise-or: `TDBTLARGE' specifies that the size of the database can be larger than 2GB by using 64-bit bucket array, `TDBTDEFLATE' specifies that each record is compressed with Deflate encoding, `TDBTBZIP' specifies that each record is compressed with BZIP2 encoding, `TDBTTCBS' specifies that each record is compressed with TCBS encoding.
        """
        self.path = path
        self.mode = mode
        cdef bint success
        self._state = tctdbnew()
        if bnum != -1 or apow != -1 or fpow != -1 or opts != DEFAULT_OPTS:
            success = tctdbtune(self._state, bnum, apow, fpow, opts)
            if not success:
                self._throw('Unable to tune {0} for {1}.'.format 
                (str(path), 'writing' if mode == 'w' else 'reading'))

        success = tctdbopen(self._state, path, 6 if mode=='w' else 1)
        if not success:
            self._throw('Unable to open {0} for {1}.'.format \
                (str(path), 'writing' if mode == 'w' else 'reading'))
        self.is_open = True
    
    def close(self):
        '''Closes the database file and cleans memory, rendering this
        object useless.
        '''
        if self.is_open:
            self.is_open = False
            tctdbdel(self._state)

    cdef TCMAP* _dict_to_tcmap(self, dict dic):
        """INTERNAL: take a dict and return the tcmap which must
        be deleted with tcmapdel(tcmap)
        """
        cdef char *kbuf, *vbuf
        cdef Py_ssize_t ksiz, vsiz
        cdef TCMAP *tcmap
        cdef int ld = len(dic)
        tcmap = tcmapnew2(ld)

        for key, val in dic.items():
            ps.PyString_AsStringAndSize(key, &kbuf, &ksiz)
            ps.PyString_AsStringAndSize(val, &vbuf, &vsiz)
            tcmapput(tcmap, kbuf, ksiz, vbuf, vsiz)
        return tcmap

    
    def __setitem__(self, k, dic):
        cdef TCMAP * tcmap = self._dict_to_tcmap(dic)
        cdef char *kbuf
        cdef Py_ssize_t ksiz
        cdef bint success
        ps.PyString_AsStringAndSize(k, &kbuf, &ksiz)
        success = tctdbput(self._state, kbuf, ksiz, tcmap)
        tcmapdel(tcmap)

        if not success:
            self._throw('Unable to write to database '+ str(k))

    cdef dict _tcmap_to_dict(self, TCMAP *tcmap):
        cdef dict dic = {} 
        tcmapiterinit(tcmap) # Initialize the map iterator
        cdef char *kptr, *vptr
        cdef int ksiz, vsiz
        while True:
            kptr = <char *>tcmapiternext(tcmap, &ksiz) # Get one column
            if kptr == NULL: break

            vptr = <char *>tcmapget(tcmap, <void *>kptr, ksiz, &vsiz)

            pykey = ps.PyString_FromStringAndSize(kptr, <Py_ssize_t>ksiz)
            pyval = ps.PyString_FromStringAndSize(vptr, <Py_ssize_t>vsiz)
            dic[pykey] = pyval

        return dic


    def _key_to_dict(self, key):
        """INTERNAL: take the database key and return
        the dicitonary associated with that key"""
        cdef char *kbuf
        cdef Py_ssize_t ksiz
        ps.PyString_AsStringAndSize(key, &kbuf, &ksiz)
        cdef TCMAP *tcmap = tctdbget(self._state, kbuf, <int>ksiz)
        if tcmap == NULL:
            raise KeyError('Lookup failed: ' + str(key))

        cdef dict dic = self._tcmap_to_dict(tcmap)
        tcmapdel(tcmap)
        return dic

    def keep_or_put(self, k, dic):
        '''Takes as arguments a key (string) and a value (dict).
        If the key already exists in the table, nothing is done
        and the string 'keep' is returned.
        Otherwise, the value is stored at the key and 'put' is returned.
        '''
        cdef char *kbuf
        cdef Py_ssize_t ksiz
        ps.PyString_AsStringAndSize(k, &kbuf, &ksiz)
        cdef TCMAP * tcmap = self._dict_to_tcmap(dic)
        cdef bint success = tctdbputkeep(self._state, <void *>kbuf, 
                                          <int>ksiz, tcmap)

        tcmapdel(tcmap)
        # according to http://1978th.net/tokyocabinet/spex-en.html
        cdef int errorcode
        if not success:
            errorcode = tctdbecode(self._state)
            if errorcode == 21: # 'existing record'
                return 'keep'
            else:
                self._throw('Unable to write key "{0}".'.format(str(k)))
        return 'put'
    
    def setdefault(self, k, dic):
        '''Writes a record -- d[k] = dic -- if k not in d.
        Then returns d[k].
        '''
        if self.keep_or_put(k, dic) == 'keep':
            return self.get(k, dic)
        else:
            return dic # which certainly has just been put
    
    def __getitem__(self, key):
        '''Returns a record (as a dict) or raises KeyError.'''
        return self._key_to_dict(key)
    
    def get(self, id, default=None):
        try:
            v = self[id]
            if not v: return default
            return v
        except KeyError:
            return default
    
    def __delitem__(self, key):
        cdef char *kbuf
        cdef Py_ssize_t ksiz
        ps.PyString_AsStringAndSize(key, &kbuf, &ksiz)
        cdef bint success = tctdbout(self._state, kbuf, ksiz)
        if not success:
            raise KeyError(self._msg('Could not delete row "{0}".' \
                                     .format(str(key))))
    
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
            dic = D[id] if id in D else defaultdict
        '''
        return self.size_of(key) > -1
    
    def flush(self):
        '''Forces changes to be written to disk. Returns a success code.'''
        cdef bint success = tctdbsync(self._state)
        return success
    
    def __len__(self):
        cdef uint64_t number = tctdbrnum(self._state)
        return number

    cdef void _set_limit(TCTable self, TDBQRY* query_state, dict kwargs):
        limit = kwargs.pop('limit', None) 
        offset = kwargs.pop('offset', None)
        if (limit is None and offset is None): return
        if limit is None: limit = -1
        if offset is None: offset = 0
        tctdbqrysetlimit(query_state, <int>limit, <int>offset)

    cdef void _set_order(TCTable self, TDBQRY* query_state, dict kwargs):
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

    def select(self, *args, **kwargs):

        cdef TCQuery q = make_query(self._state)
        #cdef TDBQRY* query_state = tctdbqrynew(self._state)
        cdef TCLIST *tclist
        cdef list li = []
        cdef int count
        cdef int i

        kwskip = ('delete', 'order', 'count', 'limit', 'offset')

        # tbl.select(name='fred', age=22)
        # convert age=22 to Col('age') == 22
        args = list(args)
        for colname, other in kwargs.items():
            if colname in kwskip: continue
            args.append(Col(colname) == other)

        

        for col in args:
            if col.invert:
                col.op = col.op | TDBQCNEGATE
            tctdbqryaddcond(q._state, <char *>col.colname, <int>col.op, <char *>col.other)


        # NOTE: this pops limit, offset from kwargs.
        self._set_limit(q._state, kwargs)
        self._set_order(q._state, kwargs)
            
        if 'delete' in kwargs:
            return tctdbqrysearchout(q._state)

        tclist = tctdbqrysearch(q._state)
        count = tclistnum(tclist) # number of elements in the list

        if 'count' in kwargs:
            tclistdel(tclist)
            return count


        li = self._tclist_to_list(tclist, count)
        tclistdel(tclist)
        return li

    cdef list _tclist_to_list(self, TCLIST *tclist, int count):
        # INTERNAL: the calling function is still responsible for deleting tclist.
        cdef list li = []
        cdef char *kbuf
        cdef int ksiz
        for i in range(count):
            kbuf = <char *>tclistval(tclist, i, &ksiz)
            key = ps.PyString_FromStringAndSize(kbuf, <Py_ssize_t>ksiz)
            li.append((key, self.get(key)))
        return li

cdef class Col(object):
    """
    tdb.query(Col('name') == 'Fred' & Col('age') > 22)
        or
    tdb.select(Q(name__in=['Fred', 'Wilma']), Q(name__contains="at2g"))
    """
    cdef public object colname
    cdef public int op
    cdef public object other
    cdef public dict num_lookups
    cdef public bint invert

    def __init__(self, colname):
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
                3: TDBQCSTREQ | TDBQCNEGATE # not equal. # TODO test.
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

    def contains(self, other):
        """
        if other is a list and any is True
        it will return all cases where the column is
        one of those values. if any is False, it will return
        only columns that match all the values in the list.
        """

        if hasattr(other, '__iter__'):
            other = list(other)
            if isinstance(other[0], basestring):
                self.op = TDBQCSTROREQ # TDBQCSTRAND 
                self.other  = ' '.join(other)
                return self
            else: 
                self.op = TDBQCNUMOREQ
                self.other  = ' '.join(map(str, other))


        if isinstance(other, basestring):
            # so see if the column contains string.
            self.op = TDBQCSTRINC
            self.other = other
            return self

        # it's a number. so extract columns with this value.
        self.other = unicode(self.other)
        self.op = self.num_lookups[2] # ==
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



cdef class TCMap(object):
    cdef TCMAP* _map
    def __del__(self):
        tcmapdel(self._map)

cdef TCMap make_tcmap():
    pass

# this class just useful as it cleans itself up.
# would be nicer to have this for tcmap...
cdef class TCQuery(object):
    cdef TDBQRY* _state
    def __del__(self):
        tctdbqrydel(self._state)
cdef TCQuery make_query(TCTDB* tctdb):
    cdef TCQuery query = TCQuery()
    query._state = tctdbqrynew(tctdb)
    return query

