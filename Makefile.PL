use inc::Module::Install;

name 'Config-JFDI';
all_from 'lib/Config/JFDI.pm';

build_requires 'Test::More';

auto_install;

WriteAll;

