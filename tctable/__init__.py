"""
    >>> from tctable import TCTable, Col
    >>> tbl = TCTable('doctest.tct', 'w')
    >>> tbl, len(tbl)
    (TCTable('doctest.tct'), 0)

make some fake data
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

# order by fname descending
    >>> [v['fname'] for k, v in tbl.select(lname='cox', order='-fname')]
    ['ted', 'jane']

#ascending
    >>> [v['fname'] for k, v in tbl.select(lname='cox', order='+fname')]
    ['jane', 'ted']

# do more advanced queries with Col
    >>> results = tbl.select(Col('fname').startswith('j'))
    >>> [d['fname'] + ' ' + d['lname'] for k, d in results]
    ['jane cox', 'jane ark', 'john kit', 'john zzz']

# combine queries
    >>> results = tbl.select(Col('fname').startswith('j'), Col('lname').endswith('k'))
    >>> [d['fname'] + ' ' + d['lname'] for k, d in results]
    ['jane ark']

# do number based queries by using a number:

    >>> results = tbl.select(Col('age') > 68)
    >>> [d['age'] for k, d in results]
    ['70', '72']

# combine queries
    >>> results = tbl.select(Col('age') > 68, Col('age') < 72)
    >>> [d['age'] for k, d in results]
    ['70']

# negate queries... get all rows where age is > 68
    >>> results = tbl.select(~Col('age') <= 68)
    >>> [d['age'] for k, d in results]
    ['70', '72']

# all rows where fname is not 'jane'
    >>> results = tbl.select(~Col('fname') != 'jane')
    >>> 'jane' in [d['fname'] for k, d in results]
    False

# check for with regexp:
    >>> results = tbl.select(Col('fname').matches("a"))
    >>> sorted(set([d['fname'] for k, d in results]))
    ['ann', 'jane', 'mark']

    >>> results = tbl.select(Col('fname').matches("^a"))
    >>> sorted(set([d['fname'] for k, d in results]))
    ['ann']


# there are also limit, offset kwargs..
    >>> results = tbl.select(Col('age') < 68, limit=1)
    >>> len(results)
    1

since it's schemaless, you can add anything:

    >>> tbl['weird'] = {"val": "hello"}
    >>> tbl['weird']
    {'val': 'hello'}


# keep or put wont overwrite existing data.
    >>> tbl.keep_or_put("weird", {"new_data":"wont get added"})
    'keep'

    >>> tbl['weird']
    {'val': 'hello'}

    >>> del tbl['weird']
    >>> print tbl.get('weird')
    None

    >>> import os; os.unlink('doctest.tct')
"""
from ctctable import TCTable, Col, TCException, \
    TDBTLARGE, TDBTDEFLATE, TDBTBZIP, TDBTTCBS, TDBTEXCODEC


