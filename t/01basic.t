use strict;
use warnings;

use Test::More;
use Test::Exception;

use Devel::PeekPoke qw/peek poke peek_address poke_address/;
use Devel::PeekPoke::Constants qw/PTR_SIZE PTR_PACK_TYPE/;

my $str = 'for mutilation and mayhem';
my $len = length($str);
my $str_pv_addr = unpack(PTR_PACK_TYPE, pack('p', $str) );

is( peek($str_pv_addr, $len + 1), $str . "\0", 'peek as expected (with NUL termination)' );

is( poke($str_pv_addr+5, 'itig'), 4, 'poke success and correct RV' );
is( $str, 'for mitigation and mayhem', 'original changed' );

is( poke($str_pv_addr+1, 'u'), 1, 'second poke success and correct RV' );
is( $str, 'fur mitigation and mayhem', 'original changed again' );

my $addr = do { no warnings 'portable'; hex('DEADBEEF' x (PTR_SIZE/4)) };
is( poke_address ($str_pv_addr, $addr), PTR_SIZE, 'poke_address works and correct RV' );
is( peek_address ($str_pv_addr), $addr, 'peek_address works' );
is( $str, pack(PTR_PACK_TYPE, $addr) . substr('for mitigation and mayhem', PTR_SIZE), 'Resulting string correct' );

# check exceptions
throws_ok { peek(123) } qr/Peek where and how much/;
throws_ok { peek('18446744073709551616', 4) } qr/Your system does not support addresses larger than 0xFF.../;

throws_ok { poke(123) } qr/Poke where and what/;
throws_ok { poke_address(123, '18446744073709551616') } qr/Your system does not support addresses larger than 0xFF.../;

SKIP: {
  skip 'No unicode testing before 5.8', 1 if $] < 5.008;

  throws_ok { poke(123, "abc\x{14F}") } qr/Expecting a byte string, but received characters/;

  my $itsatrap = "\x{AE}\x{14F}";
  throws_ok { poke(123, substr($itsatrap, 0, 1)) }
    qr/\QExpecting a byte string, but received what looks like *possible* characters, please utf8_downgrade the input/;
}

TODO: {
  local $TODO = "#98745 5.20.1 regression with poke_size 10" if $] > 5.020;
  my $str = 'for mutilation and mayhem';
  my $len = length($str);
  my $str_pv_addr = unpack(PTR_PACK_TYPE, pack('p', $str) );
  my ($poke_start, $poke_size) = (0, 10);
  my $replace_chunk = 'a' . ( '0' x ($poke_size-1) );
  my $expecting = $str;
  substr($expecting, $poke_start, $poke_size, $replace_chunk);
  if ($ENV{DEBUG}) {
    require Devel::Peek;
    Devel::Peek->import;
    warn "str:\n";
    Dump($str);
    warn "expecting:\n";
    Dump($expecting);
    warn sprintf("str_pv_addr=0x%x", $str_pv_addr);
  }
  poke($str_pv_addr+$poke_start, $replace_chunk);
  unless (is($str, $expecting, "poke $poke_start $poke_size #98745")) {
    if ($ENV{DEBUG}) {
      warn "str:\n";
      Dump($str);
      warn "expecting:\n";
      Dump($expecting);
    }
  }
}

done_testing;
