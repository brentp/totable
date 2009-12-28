rm -f some.tct* doctest.tct*
PYTHONPATH=. python totable/tests/test_totable.py && \
PYTHONPATH=. nosetests --with-doctest totable/__init__.py && \
PYTHONPATH=. nosetests --with-doctest --doctest-extension=.rst README.rst
rm -f some.tct* doctest.tct*
