use inc::Module::Install;
name 'Nagare';
all_from 'lib/Nagare.pm';

# requires '';

tests 't/*.t';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
