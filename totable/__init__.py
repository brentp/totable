"""
    # see the docs.

    >>> from totable import ToTable, Col
    >>> tbl = ToTable('doctest.tct', mode='w')
    >>> tbl, len(tbl)
    (ToTable('doctest.tct'), 0)

    >>> tbl['a'] = {'a': '23', 'b': 'asdf'}

    >>> import os; os.unlink('doctest.tct')
"""
from ctotable import ToTable, Col, TCException, transaction, \
    TDBTLARGE, TDBTDEFLATE, TDBTBZIP, TDBTTCBS, TDBTEXCODEC


