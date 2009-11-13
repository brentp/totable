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

    >>> results = tbl.select(Col('fname').contains('e'))
    ['fred', 'ted']

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

order by
========
currently only works for string keys. use '-' for descending and 
'+' for ascending

::

    >>> [v['fname'] for k, v in tbl.select(lname='cox', order='-fname')]
    ['ted', 'jane']

    # ascending
    >>> [v['fname'] for k, v in tbl.select(lname='cox', order='+fname')]
    ['jane', 'ted']

Schemaless
==========
since it's schemaless, you can add anything

::

    >>> tbl['weird'] = {"val": "hello"}
    >>> tbl['weird']
    {'val': 'hello'}

Delete
======
delete as expected for a dictionary interface.

::

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

