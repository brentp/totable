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

    tbl.query(Col('age') > 18, Col('name').startswith('T'))

to allow querying columns with numbers and letters transparently.
Also adds a few more niceties, see below.

Install
-------
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

    >>> tbl.select(lname='cox')
    [('1', {'lname': 'cox', 'age': '22', 'fname': 'jane'}), ('12', {'lname': 'cox', 'age': '70', 'fname': 'ted'})]


order by
========
::

    >>> [v['fname'] for k, v in tbl.select(lname='cox', order='-fname')]
    ['ted', 'jane']

    # ascending
    >>> [v['fname'] for k, v in tbl.select(lname='cox', order='+fname')]
    ['jane', 'ted']

Col
===

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

numeric queries (richcmp)
*************************
::

    #do number based queries by using (you guessed it) a number
    >>> results = tbl.select(Col('age') > 68)
    >>> [d['age'] for k, d in results]
    ['70', '72']

combining queries
*****************
::

    #combine queries
    >>> results = tbl.select(Col('age') > 68, Col('age') < 72)
    >>> [d['age'] for k, d in results]
    ['70']

Negate(~)
*********
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
::

    >>> results = tbl.select(Col('fname').matches("a"))
    >>> sorted(set([d['fname'] for k, d in results]))
    ['ann', 'jane', 'mark']

    >>> results = tbl.select(Col('fname').matches("^a"))
    >>> sorted(set([d['fname'] for k, d in results]))
    ['ann']


Offset/Limit
============
::

    >>> results = tbl.select(Col('age') < 68, limit=1)
    >>> len(results)
    1

Schemaless
==========
::

    #since it's schemaless, you can add anything
    >>> tbl['weird'] = {"val": "hello"}
    >>> tbl['weird']
    {'val': 'hello'}

Delete
======
::

    #delete as expected
    >>> del tbl['weird']
    >>> print tbl.get('weird')
    None

See Also
--------

    * `tc`_ nice c-python bindings for all of the `tokyo cabinet`_ db types
      including the table

    * `pykesto`_ the project from which this library is taken. aims to provide
      transactions on top of `tokyo cabinet`_ .

    

.. _`pykesto`: http://code.google.com/p/pykesto/
.. _`tokyo cabinet`: http://1978th.net/tokyocabinet/
.. _`tc`: http://github.com/rsms/tc
.. _`cython`: http://cython.org/

