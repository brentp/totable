rm -f some.tct doctest.tct
PYTHONPATH=. python tctable/tests/test_tctable.py
PYTHONPATH=. nosetests --with-doctest tctable/__init__.py
PYTHONPATH=. nosetests --with-doctest --doctest-extension=.rst README.rst
rm -f some.tct doctest.tct
