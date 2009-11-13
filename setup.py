#!/usr/bin/env python
# -*- coding: utf-8 -*-

from distutils.core import setup
from distutils.extension import Extension
import os, sys

if not os.path.exists('src/ctctable.c'):
    print "run cython src/ctctable.c"
    sys.exit()

setup(
    ext_modules = [Extension("ctctable", ["src/ctctable.c"],
                             libraries=['tokyocabinet'],
                            )
                  ],
    name = 'tctable',
    version = '0.0.1',
    description = 'Cython wrapper for tokyo cabinet table',
    long_description = open('README.rst').read(),
    url          = '',
    download_url = '',
    classifiers  = ['Development Status :: 3 - Alpha',
                    'Intended Audience :: Developers',
                    'License :: OSI Approved :: BSD License',
                    'Operating System :: OS Independent',
                    'Programming Language :: Python',
                    'Programming Language :: C',
                    'Topic :: Database :: Database Engines/Servers',
                   ],
    package_dir = {'': 'tctable'},
    packages = ['tctable'],
)
