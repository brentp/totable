#!/usr/bin/env python
# -*- coding: utf-8 -*-

import unittest
from totable import ToTable, Col, transaction
import os

def rm(path):
    try:
        os.unlink(path)
    except:
        pass

PATH = "TEST.tct"

class TestToTable(unittest.TestCase):
    def setUp(self):
        self.path = PATH
        rm(self.path)
        self.table = table = ToTable(self.path, 'w')
        table['Ludwig'] = dict(name='Beethoven', age='220', type='person',
                               profession='composer')
        table['Robert'] = dict(name='Schumann', age='180', type='person',
                               profession='composer')
        table['Frederic']=dict(name='Chopin', age='180', type='person',
                               profession='composer')
        table['Claude'] = dict(name='Debussy', age='100', type='person',
                               profession='composer')
        table['Nando'] = {'name':'Florestan', 'age':'33', 'type':'person',
                          'profession':'Python programmer and dilettante'}
        self.nulls = {'\0a':'a\0', 'profession': 'poser'}
        table['a\0a'] =  self.nulls
    
    def tearDown(self):
        self.table.close()
        import glob
        for f in glob.glob(self.path + ".*"):
            rm(f)
        rm(self.path)
        rm(self.path + '.tune')
    
    def test_len(self):
        t = self.table
        lent = len(t)
        self.assertEquals(lent, 6)

    def test_keys(self):
        t = self.table
        self.assertEquals(t['Nando'],
                          {'name':'Florestan', 'type':'person', 'age':'33',
                           'profession':'Python programmer and dilettante'})
        assert 'non-existing key' not in t
        assert 'Claude' in t

    def test_nulls(self):
        # Must be able to put stuff with byte zero
        # ...although there should be a problem querying columns with
        # names that contain \0
        t = self.table
        self.assertEquals(t['a\0a'], self.nulls)
        t.keep_or_put('a\0a', {'\0a':'a\0'})
        self.assertEquals(t['a\0a'], self.nulls)
        self.assertEquals('keep', t.keep_or_put('a\0a', {'not':'not'}))
        self.assertEquals(t.get('a\0a'), self.nulls)
        # Test get() with default

    def test_defaults(self):
        t = self.table
        self.assertEquals(t.get('doesnt exist', default=dict()), dict())

    def test_del(self):
        t = self.table
        lent = len(t)
        try:
            del t['9']
        except KeyError:
            pass
        else:
            self.fail('del should raise KeyError when key not found.')
            #del t['a\0a']
        # Test len()
        self.assertEquals(lent, len(t))
        self.assertEquals(-1, t.size_of('a key that doesnt exist'))
        del t['a\0a']
        self.assertEquals(len(t), lent - 1)

        t['a\0a'] = self.nulls
        self.assertEquals(len(t), lent)

    def test_select(self):
        t = self.table
        r = t.select(Col('age') == 180)
        self.assertEquals([item['name'] for key, item in r], ['Schumann', 'Chopin'])
        r = t.select(Col('age') == 180, Col('name') == 'Chopin')
        self.assertEquals(r, [('Frederic', {'type': 'person', 'age': '180', 'profession': 'composer', 'name': 'Chopin'})])

    def test_inlist(self):
        t = self.table
        test_names = ['Chopin', 'Florestan']
        r = t.select(Col('name').in_list(test_names))
        names = self.get_cols(r)
        self.assertEquals(names, test_names)

        test_ages = [33, 100]
        r = t.select(Col('age').in_list(test_ages))
        ages = map(int, self.get_cols(r, 'age'))
        self.assertEquals(sorted(set(ages)), test_ages)

    def test_put(self):
        t = self.table
        t.put('a', {'a': '1'}, mode='p')
        self.assertEquals(t.put('a', {'a': '2'}, mode='k'), 'keep')
        self.assertEquals(t['a'], {'a': '1'})

        self.assertEquals(t.put('b', {'a': '3'}, mode='k'), 'put')

        t.put('a', {'b': '99'}, 'c')
        self.assertEquals(t['a'], {'a': '1', 'b': '99'})


    def test_like(self):
        t = self.table

        r = t.select(Col('name').like('an'))
        self.assertEquals([v['name'] for k, v in r], ['Schumann', 'Florestan'])

    def test_matches(self):
        t = self.table
        r = t.select(Col('name').matches('n$'))
        names = sorted(self.get_cols(r))
        self.assertEquals(names, ['Beethoven', 'Chopin', 'Florestan', 'Schumann'] )

        r = t.select(Col('name').matches('e[es]'))
        self.assertEquals(self.get_cols(r), ['Beethoven', 'Florestan'])

    def test_tune(self):
        from totable import TDBTTCBS
        t = ToTable(self.path + ".tune", 'w', bnum=1234, fpow=6, opts=TDBTTCBS)
        t['asdf'] = {'d': '1'}

        t.close()

    def test_mmap_size(self):
        t = ToTable(self.path + ".tune", 'w', mmap_size=256 * 1e6)
        t['asdf'] = {'d': '2'}
        self.assertEquals(t['asdf'], {'d': '2'})
        del t['asdf']
        t.close()

    def test_cache(self):
        t = ToTable(self.path + ".tune", 'w', rcnum=8192)
        t['asdf'] = {'d': '2'}
        self.assertEquals(len(t) > 0, True)
        self.assertEquals(t['asdf'], {'d': '2'})

        t.close()

        t = ToTable(self.path + ".tune", 'w', lcnum=1024, ncnum=200)
        self.assertEquals(t['asdf'], {'d': '2'})
        t.close()

    def test_iter(self):
        t = self.table
        self.assertEquals(len(list(t)), len(t))

        k, v = iter(t).next()
        self.assertEquals(v, t[k])

        for k, v in t:
            self.assertEquals(v, t[k])

    def test_optimize(self):
        from totable import TDBTLARGE, TDBTDEFLATE, TDBTBZIP, TDBTTCBS
        t = ToTable(self.path + ".tune", 'w')

        t.optimize()

        t.optimize(bnum=28, apow=3, fpow=2)
        # more realistic number is > 200K.
        t.optimize(bnum=208000)
        t.optimize(opts=TDBTBZIP)
        t.optimize(opts=TDBTDEFLATE)
        t.optimize(opts=TDBTTCBS)
        t.close()


    def test_select_startswith_ends_with(self):
        t = self.table
        r = t.select(Col('profession').startswith('co'))
        self.assert_(not "a\0a" in [k for k, v in r], r)


        r = t.select(Col('profession').endswith('oser'))
        self.assert_("a\0a" in [k for k, v in r], r)

    def test_between(self):
        t = self.table
        r = t.select(Col('age').between(180, 220))
        self.assertEquals([v['age'] for k, v in r], ['220', '180', '180'])

    def test_clear(self):
        t = self.table
        self.assertEquals(len(t) > 0, True)
        t.clear()
        self.assertEquals(len(t), 0)
        t.close()
        self.setUp()


    def test_transaction(self):
        t = self.table

        try:
            with transaction(t):
                t['otherwise_inserted'] = {'a': '2'}
                t['asdf'] = 2 # error because it's not a dict.
        except:
            pass
        self.assert_(not 'otherwise_inserted' in t)

        with transaction(t):
            t['bbb'] = {'a': '2'}

        self.assert_('bbb' in t)



    def test_limit(self):
        t = self.table

        for i in range(4):
            r = t.select(Col('age').between(0, 220), limit=i)
            self.assertEquals(len(r), i, r)

    def test_values(self):
        t = self.table
        r = t.select(name='Chopin', values_only=True)
        self.assertEquals(r, [{'type': 'person', 'age': '180', 'profession': 'composer', 'name': 'Chopin'}])

    def test_combined(self):
        t = self.table
        r = t.select(Col('age').between(180, 220), Col('name').like('an'))
        self.assertEquals(r, [('Robert', {'type': 'person', 'age': '180', 'profession': 'composer', 'name': 'Schumann'})], r)

        r = t.select(Col('age').between(180, 220), 
                     Col('name').like('an'),
                     Col('type') == 'dog'
                    )
        self.assertEquals(r, [])


    def test_index(self):
        t = self.table

        self.assertEquals(t.create_index('age', 'd'), True)
        self.assertEquals(t.create_index('type', 's'), True)

        self.assertEquals(t.delete_index('type'), True)
        self.assertEquals(t.optimize_index('age'), True)
        self.assertEquals(t.delete_index('age'), True)


    def test_negate(self):
        t = self.table
        r = t.select(~Col('age') == 180)
        self.assert_(not '180' in [v.get('age') for k, v in r], r)

    def test_str_negate(self):
        t = self.table
        r = t.select(Col('name') != 'Chopin')
        self.assertEquals(len(r), 5) # all but chopin
        self.assertEquals('Chopin' in [v.get('name') for k, v in r], False)

        # and add a condition.
        r = t.select(Col('name') != 'Chopin', Col('age') == 180)
        self.assertEquals(len(r), 1)
        k, v = r[0]
        self.assertEquals(k, "Robert")

    def test_count(self):
        t = self.table
        r = t.select(Col('name') != 'Chopin')
        self.assertEquals(len(r), t.count(Col('name') != 'Chopin'))

        self.assertEquals(len(r), t.select(Col('name') != 'Chopin', count=True))

    def get_cols(self, r, col='name'):
        return [v.get(col) for k, v in r if v.get(col)]

    def test_order(self):
        t = self.table
        r = t.select(Col('name') != 'aaa', order='+name')
        names = [v.get('name') for k, v in r if v.get('name')]

        sorted_names = sorted(names)
        self.assertEquals(names, sorted_names)

        # descending.
        r = t.select(Col('name') != 'aaa', order='-name')
        names = [v.get('name') for k, v in r if v.get('name')]
        self.assertEquals(names, sorted_names[::-1])

    def test_kwargs(self):
        t = self.table
        r = t.select(name='Chopin')
        names = self.get_cols(r)
        self.assertEquals(names, ['Chopin'])

        r = t.select(age=180)
        ages = self.get_cols(r, 'age')
        self.assertEquals(ages, ['180', '180'])


    def test_delete(self): 
        t = self.table
        self.assertEquals(len(t), 6)
        r = t.select(Col('name') == 'Chopin')
        self.assertEquals(len(r), 1)
        t.delete(Col('name') == 'Chopin')

        r = t.select(Col('name') == 'Chopin')
        self.assertEquals(len(r), 0)

        self.assertEquals(len(t), 5)


if __name__ == '__main__':
    unittest.main()
