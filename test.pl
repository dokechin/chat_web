use strict;
use warnings;
use Mojo::Redis;

my $redis = Mojo::Redis->new;
$redis->ioloop->start;
$redis->hset(chat => {ytnobody=>"perlbeginners"});
$redis->hset(chat => {dokechin=>"mishimapm"});
$redis->hset(chat => {yusukebe=>"yokohamapm"});
$redis->set(hot => "aaa");

$redis->get(hot=> sub{
    my ($redis, $val) = @_;
    print "$val";  
});

$redis->hvals(chat=> sub{
    my ($redis, $vals) = @_;
    for my $val(@$vals){
       say $val;
    } 
    print "eee";  
});
sleep (5);
