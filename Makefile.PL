use inc::Module::Install;

name 'Config-JFDI';
all_from 'lib/Config/JFDI.pm';

build_requires 'Test::More';

requires 'Hash::Merge::Simple';
requires 'Config::Any';
requires 'Carp::Clan';
requires 'Clone';
requires 'List::MoreUtils';
requires 'Moose';
requires 'Path::Class';

auto_install;

WriteAll;

