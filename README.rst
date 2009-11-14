+++++++
TCTable
+++++++

.. contents ::

About
-----

Pythonic access to `tokyo cabinet`_ table database api. most of the `cython`_ 
code for this is stolen from `pykesto`_.
This library builds on that by adding the Col() query interface. e.g.
::

    tbl.select(Col('age') > 18, Col('name').startswith('T'))

to allow querying columns with numbers and letters transparently.
Also adds a few more niceties, see below.

Install
-------
first, install Tokyo-Cabinet `source`_, then,
from a the directory containing this file:
::


    # requires cython for now.
    $ cython src/ctctable.pyx
    $ python setup.py build_ext -i

    # test 
    $ PYTHONPATH=. python tctable/tests/test_tctable.py

    # install
    $ sudo python setup.py install


Example Use
-----------
::

    >>> from tctable import TCTable, Col
    >>> tbl = TCTable('doctest.tct', 'w')
    >>> tbl, len(tbl)
    (TCTable('doctest.tct'), 0)

    >>> fnames = ['fred', 'jane', 'john', 'mark', 'bill', 'ted', 'ann']
    >>> lnames = ['smith', 'cox', 'kit', 'ttt', 'zzz', 'ark', 'ddk']
    >>> for i in range(len(fnames)):
    ...     tbl[str(i)] = {'fname': fnames[i], 'lname': lnames[i],
    ...                    'age': str((10 + i) * 2)}
    ...     tbl[str(i + len(fnames))] = {'fname': fnames[i],
    ...                                  'lname': lnames[len(lnames) - i - 1],
    ...                                   'age': str((30 + i) * 2)}

    >>> len(tbl)
    14

Col
===

`Col`_ as sent to the select method makes it easy to do queries on a database
the format is Col(colname) == 'Fred' where colname is one of the keys in the
dictionary items in the database. or can use kwargs to select()
::

    >>> tbl.select(lname='cox')
    [('1', {'lname': 'cox', 'age': '22', 'fname': 'jane'}), ('12', {'lname': 'cox', 'age': '70', 'fname': 'ted'})]

though using Col gives more power

startswith
**********
::

    >>> results = tbl.select(Col('fname').startswith('j'))
    >>> [d['fname'] + ' ' + d['lname'] for k, d in results]
    ['jane cox', 'jane ark', 'john kit', 'john zzz']

endswith
********
::

    #and combine queries by sending them in together.
    >>> results = tbl.select(Col('fname').startswith('j'), Col('lname').endswith('k'))
    >>> [d['fname'] + ' ' + d['lname'] for k, d in results]
    ['jane ark']

contains
********
this is still in flux (can takes lists of numbers or strings as well)
::

    >> results = tbl.select(Col('fname').contains('e'))
    ['fred', 'ted']

between
*******
use for number querying between a min and max. includes the endpoints.
::

    >>> r = tbl.select(Col('age').between(68, 70))
    >>> [v['age'] for k, v in r]
    ['68', '70']

numeric queries (richcmp)
*************************

in TC, everything is stored as strings, but you can force
number based comparisons by using (you guessed it) a number.
Or using a string for non-numeric comparisons.

::

    >>> results = tbl.select(Col('age') > 68)
    >>> [d['age'] for k, d in results]
    ['70', '72']

combining queries
*****************

just add multiple Col() arguments to the select() call
and they will be essentially *and*'ed together.

::

    >>> results = tbl.select(Col('age') > 68, Col('age') < 72)
    >>> [d['age'] for k, d in results]
    ['70']

Negate(~)
*********

for example get everything that's not a given value...

::

    >>> results = tbl.select(~Col('age') <= 68)
    >>> [d['age'] for k, d in results]
    ['70', '72']

    #all rows where fname is not 'jane' 
    >>> results = tbl.select(~Col('fname') != 'jane')
    >>> 'jane' in [d['fname'] for k, d in results]
    False

Regular Expression Matching
***************************
supports normal regular expression characters "[ $ ^ | " , etc.

::

    >>> results = tbl.select(Col('fname').matches("a"))
    >>> sorted(set([d['fname'] for k, d in results]))
    ['ann', 'jane', 'mark']

    >>> results = tbl.select(Col('fname').matches("^a"))
    >>> sorted(set([d['fname'] for k, d in results]))
    ['ann']


Offset/Limit
============
just like SQL, yo.

::

    >>> results = tbl.select(Col('age') < 68, limit=1)
    >>> len(results)
    1

order
=====
currently only works for string keys. use '-' for descending and 
'+' for ascending

::

    >>> [v['fname'] for k, v in tbl.select(lname='cox', order='-fname')]
    ['ted', 'jane']

    # ascending
    >>> [v['fname'] for k, v in tbl.select(lname='cox', order='+fname')]
    ['jane', 'ted']


values
======
TC is a key-value store, but it also acts as a table. it may be
convenient to get just the values as you'd expect from a database
table. Note in all examples above, the 'k'ey is not used, only 
the value dictionary. This can be made simpler with 'values_only'.
When 'values_only' is True, some python call overhead is removed
as well.

::
    >>> tbl.select(Col('fname').matches("^a"), values_only=True)
    [{'lname': 'ddk', 'age': '32', 'fname': 'ann'}, {'lname': 'smith', 'age': '72', 'fname': 'ann'}]
    

Schemaless
==========
since it's schemaless, you can add anything

::

    >>> tbl['weird'] = {"val": "hello"}
    >>> tbl['weird']
    {'val': 'hello'}

delete
======
delete as expected for a dictionary interface.

::

    >>> del tbl['weird']
    >>> print tbl.get('weird')
    None

Performance Tuning
==================
Tokyo Cabinet allows you to `tune` or `optimize` a table. the available parameters are:

        * `bnum` specifies the number of elements of the bucket array.
          Suggested size of 'bnum' is about from 0.5 to 4 times of the number
          of all records to be stored. default is about 132K.

        * `apow` specifies the size of record alignment by power of 2.
           The default value is 4 standing for 2^4=16.

        * `fpow` specifies the maximum number of elements of the free block
          pool by power of 2. The default value is 10 standing for 2^10=1024.

        * `opts` specifies options by bitwise-or (|):
          + 'TDBTLARGE' must be specified to use a database larger than 2GB.
          + 'TDBTDEFLATE' use Deflate encoding.
          + 'TDBTBZIP' use BZIP2 encoding.
          + 'TDBTTCBS' use TCBS encoding.

The other parameters: `cache`_ and `mmap_size`_ are explained below.

tune
****
The arguments can be sent to the constructor.
::

    >>> import tctable
    >>> t = TCTable("some.tct", 'w', bnum=1234, fpow=6, \
    ...                    opts=tctable.TDBTLARGE | tctable.TDBTBZIP)

    >>> t.close()

optimize
********
optimize is called on an database opened with mode='w'. if no arguments are
specified, it will automatically adjust 'bnum' (only) according to the number
of elements in the table.
::

    >>> t = TCTable("some.tct", 'w')

    # ... add some records ...
    >>> t.optimize()
    True

mmap_size
*********
`mmap_size` is the size of mapped memory. default is 67,108,864 (64MB)
set in the constructor. this is `xmsiz` in TC parlance.
::

    >>> t.close()
    >>> t = TCTable("some.tct", 'w', mmap_size=128 * 1e6) # ~128MB.

cache
*****
TC also allows setting various caching parameters.
* `rcnum` is the max number of records to be cached. default is 0
* `lcnum` is the max number of leaf-nodes to be cached. default is 4096
* `ncnum` is the max number of non-leaf nodes cached. default is 512
these also must be set in the constructor.
::

    >>> t.close()
    >>> t = TCTable("some.tct", 'w', rcnum=1e7, lcnum=32768)


index
*****
create or delete a 's'tring or 'd'ecimal index on a column for faster queries.
::    

    # create a decimal index on the number column 'age'.
    >>> tbl.create_index('age', 'd')
    True

    # create a 'string index on the string column 'fname'.
    >>> tbl.create_index('fname', 's')
    True

    # remove the index.
    >>> tbl.delete_index('fname')
    True

    # optimize the index
    >>> tbl.optimize_index('age')
    True


See Also
--------

    * `tc`_ nice c-python bindings for all of the `tokyo cabinet`_ db types
      including the table

    * `pykesto`_ the project from which this library is taken. aims to provide
      transactions on top of `tokyo cabinet`_ .

    * to help out, see TODO list at top of `ctcable.pyx`_

    * tokyo cabinet database api http://1978th.net/tokyocabinet/spex-en.html#tctdbapi

    

.. _`pykesto`: http://code.google.com/p/pykesto/
.. _`tokyo cabinet`: http://1978th.net/tokyocabinet/
.. _`tc`: http://github.com/rsms/tc
.. _`cython`: http://cython.org/
.. _`ctcable.pyx`: http://github.com/brentp/tctable/blob/master/src/ctctable.pyx
.. _`source`: http://sourceforge.net/projects/tokyocabinet/files/

