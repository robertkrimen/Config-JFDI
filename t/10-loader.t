use Test::More;
plan qw/no_plan/;

use Config::JFDI;

my $config = Config::JFDI->new(qw{ name xyzzy path t/assets });

ok($config->get);
is($config->get->{'Controller::Foo'}->{foo},         'bar');
is($config->get->{'Controller::Foo'}->{new},         'key');
is($config->get->{'Model::Baz'}->{qux},              'xyzzy');
is($config->get->{'Model::Baz'}->{another},          'new key');
is($config->get->{'view'},                           'View::TT::New');
#is($config->get->{'foo_sub'},                       'x-y');
is($config->get->{'foo_sub'},                        '__foo(x,y)__');
#is($config->get->{'literal_macro'},                 '__DATA__');
is($config->get->{'literal_macro'},                  '__literal(__DATA__)__');

ok(1);

__END__

use Cwd;
$ENV{ CATALYST_HOME } = cwd . '/t/mockapp';

use_ok( 'Catalyst', qw( ConfigLoader ) );


__PACKAGE__->config->{ 'Plugin::ConfigLoader' }->{ substitutions } = {
    foo => sub { shift; join( '-', @_ ); }
};

__PACKAGE__->setup;

ok( __PACKAGE__->config );
is( __PACKAGE__->config->{ 'Controller::Foo' }->{ foo }, 'bar' );
is( __PACKAGE__->config->{ 'Controller::Foo' }->{ new }, 'key' );
is( __PACKAGE__->config->{ 'Model::Baz' }->{ qux },      'xyzzy' );
is( __PACKAGE__->config->{ 'Model::Baz' }->{ another },  'new key' );
is( __PACKAGE__->config->{ 'view' },                     'View::TT::New' );
is( __PACKAGE__->config->{ 'foo_sub' },                  'x-y' );
is( __PACKAGE__->config->{ 'literal_macro' },            '__DATA__' );
