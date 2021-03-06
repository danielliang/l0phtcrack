#!/usr/bin/perl -w
use strict;
 
my $VERSION = "1.10";
 
#############################################################################
# For the version information list, see the file pass_gen.Manifest
#############################################################################
 
use Authen::Passphrase::DESCrypt;
use Authen::Passphrase::BigCrypt;
use Authen::Passphrase::MD5Crypt;
use Authen::Passphrase::BlowfishCrypt;
use Authen::Passphrase::EggdropBlowfish;
use Authen::Passphrase::LANManager;
use Authen::Passphrase::NTHash;
use Authen::Passphrase::PHPass;
use Digest::MD4 qw(md4 md4_hex md4_base64);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Digest::SHA qw(sha1 sha1_hex sha1_base64);
use Encode;
use Switch 'Perl5', 'Perl6';
use POSIX;
use Getopt::Long;
#use Digest::HMAC_MD5 qw(hmac_md5 hmac_md5_hex);
use Crypt::RC4;
use Crypt::CBC;
use Crypt::DES;
use Crypt::ECB qw(encrypt PADDING_AUTO PADDING_NONE);
use Crypt::PBKDF2;
use Crypt::OpenSSL::PBKDF2;
 
#############################################################################
#
# Here is how to add a new hash subroutine to this script file:
#
# 1.	add a new element to the @funcs array.  The case of this string does
#	not matter.  The only time it is shown is on the usage screen, so make
#	it something recognizable to the user wanting to know what this script
#	can do.
# 2.	add a new  sub to the bottom of this program. The sub MUST be same
#	spelling as what is added here, but MUST be lower case.  Thus, we see
#	DES here in funcs array, but the sub is:   sub des($pass)  This
#	subroutine will be passed a candidate password, and should should output
#	the proper hash.  All salts are randomly selected, either from the perl
#	function doing the script, or by using the randstr()  subroutine.
# 3.	Test to make sure it works properly.  Make sure john can find ALL values
#	your subroutine returns.
# 4.	Update the version of this file (at the top of it)
# 5.	Publish it to the john wiki for others to also use.
#
# These john jumbo formats are not done 'yet':
# AFS/KRB5/dominosec/epi/sapG/sapB/DMD5
#
# lotus5 is done in some custom C code.  If someone wants to take a crack at it here, be my guest :)
#############################################################################
my @funcs = ("DES", "BigCrypt", "BSDI", "MD5_1", "MD5_a", "BF", "BFx", "BFegg", "RawMD5",
             "RawMD5u", "RawSHA1", "RawSHA1u", "msCash", "LM", "NT", "pwdump", "RawMD4", "PHPass",
			 "PO", "hmacMD5", "IPB2", "PHPS", "MD4p", "MD4s", "SHA1p", "SHA1s", "mysqlSHA1",
			 "pixMD5", "MSSql05", "nsldap", "nsldaps", "ns", "XSHA", "mskrb5", "mysql",
			 "mssql", "oracle", "oracle11", "hdaa", "netntlm_ess", "openssha", "l0phtcrack",
			 "netlmv2", "netntlmv2", "mschapv2", "mscash2", "mediawiki", "MD5_gen" );
my $i; my $h; my $u; my $salt;
my @chrAsciiText=('a'..'z','A'..'Z');
my @chrAsciiTextLo=('a'..'z');
my @chrAsciiTextHi=('A'..'Z');
my @chrAsciiTextNum=('a'..'z','A'..'Z','0'..'9');
my @chrAsciiTextNumUnder=('a'..'z','A'..'Z','0'..'9','_');
my @chrHexHiLo=('0'..'9','a'..'f','A'..'F');
my @chrHexLo=('0'..'9','a'..'f');
my @chrHexHi=('0'..'9','A'..'F');
my @i64 = ('.','/','0'..'9','A'..'Z','a'..'z');
my @ns_i64 = ('A'..'Z', 'a'..'z','0'..'9','+','/',);
my @userNames = (
	"admin", "root", "bin", "Joe", "fi15_characters", "Herman", "lexi Conrad", "jack", "John", "sz110",
	"fR14characters", "Thirteenchars", "Twelve_chars", "elev__chars", "teN__chars", "six16_characters",
	"ninechars", "eightchr", "sevench", "barney", "user", "01234", "nineteen_characters", "eight18_characters",
	"seven17characters", "u1", "harvey", "john", "ripper", "a", "Hank", "1", "u2", "u3", "2", "3", "usr",
	"usrx", "usry", "skippy", "Bing", "Johnson", "addams", "anicocls", "twentyXXX_characters",
	"twentyoneX_characters", "twentytwoXX_characters", );
 
#########################################################
# These global vars are used by the md5_gen parsing engine
# to deal with unknown formats.
#########################################################
my $gen_u; my $gen_s; my $gen_soutput, my $gen_stype; my $gen_s2; my $gen_pw; my @gen_c; my @gen_toks; my $gen_num;
my $gen_lastTokIsFunc; my $gen_u_do; my $md5_gen_usernameType; my $md5_gen_passType; my $salt2len; my $saltlen; my $gen_PWCase;
# pcode, and stack needed for pcode.
my @gen_pCode; my @gen_Stack; my @gen_Flags;
my $debug_pcode=0; my $gen_needs; my $gen_needs2; my $gen_needu; my $gen_singlesalt;
my $hash_format; my $arg_utf8 = 0; my $arg_ansi = 0; my $arg_minlen = 0; my $arg_maxlen = 128; my $arg_dictfile = "unknown";
my $arg_count = 1500, my $argsalt, my $arg_nocomment = 0;
 
# code to help decode base64 encoded salts
#use MIME::Base64 2.21 qw(encode_base64 decode_base64);
#sub de_base64($) {
#	my($text) = @_;
#	$text =~ tr#./A-Za-z0-9#A-Za-z0-9+/#;
#	$text .= "=" x (3 - (length($text) + 3) % 4);
#	return decode_base64($text);
#}
#print de_base64("/OK.fbVrR/bpIqNJ5ianF.");  # binary junk
#print de_base64("bETxbD7xWUvycB.vKhKyLO"); # test_saltx012345
#exit;
 
GetOptions(
	'iso-8859-1|ansi!' => \$arg_ansi,
	'utf8!'            => \$arg_utf8,
	'nocomment!'       => \$arg_nocomment,
	'minlength=n'      => \$arg_minlen,
	'maxlength=n'      => \$arg_maxlen,
	'salt=s'           => \$argsalt,
	'count=n'          => \$arg_count,
	'dictfile=s'       => \$arg_dictfile
	) || usage();
 
sub usage {
die <<"UsageHelp";
usage: $0 [-h|-?] [-utf8|-iso-8859-1] [-option[s]] HashType [HashType2 [...]] [ < wordfile ]
    Options can be abbreviated!
    HashType is one or more (space separated) from the following list:
      [ @funcs ]
    Multiple hashtypes are done one after the other. All sample words
    are read from stdin or redirection of a wordfile
 
    Default is to read and write files as binary, no conversions
    -iso-8859-1   Read and write files in ISO-8859-1 encoding
    -utf8         Read and write files in UTF-8 encoding
 
	Options are:
    -minlen <n>   Discard lines shorter than <n> characters  (0)
    -maxlen <n>   Discard lines longer than <n> characters (128)
    -count <n>    Stop when we have produced <n> hashes   (1320)
 
	-salt <s>     Force a single salt (only supported in a few formats)
    -dictfile <s> Put name of dict file into the first line comment
	-nocomment    eliminate the first line comment
 
    -help         shows this help screen.
UsageHelp
}
 
if (@ARGV == 0) {
	die "A format must be specified when running the script";
}
 
if ($arg_utf8 + $arg_ansi > 1) {
	die "Only one encoding can be used";
}
 
#if not a redirected file, prompt the user
if (-t STDIN) {
	print STDERR "\nEnter words to hash, one per line.\n";
	print STDERR "When all entered ^D starts the processing.\n\n";
	$arg_nocomment = 1;  # we do not output 'comment' line if writing to stdout.
}
 
###############################################################################################
# modifications to character set used.  This is to get pass_gen.pl working correctly
# with john's -utf8 switch.  Also added is code to do max length of passwords.
###############################################################################################
if ($arg_utf8) {
	binmode(STDIN,":utf8");
	binmode(STDOUT,":utf8");
	if (!$arg_nocomment) { printf("#!comment: Built with pass_gen.pl using -utf8 mode, $arg_minlen to $arg_maxlen characters. dict file=$arg_dictfile\n"); }
} elsif ($arg_ansi) {
	binmode(STDIN,':encoding(iso-8859-1)');
	binmode(STDOUT,':encoding(iso-8859-1)');
	if (!$arg_nocomment) { printf("#!comment: Built with pass_gen.pl in ISO-8859-1 character set mode, $arg_minlen to $arg_maxlen characters dict file=$arg_dictfile\n"); }
} else {
	binmode(STDIN,":raw");
	binmode(STDOUT,":raw");
	if (!$arg_nocomment) { printf("#!comment: Built with pass_gen.pl using RAW mode, $arg_minlen to $arg_maxlen characters dict file=$arg_dictfile\n"); }
}
###############################################################################################
###############################################################################################
#### Data Processing Loop.  We read all candidates here, and send them to the proper hashing
#### function(s) to build into john valid input lines.
###############################################################################################
###############################################################################################
if (@ARGV == 1) {
	# if only one format (how this script SHOULD be used), then we do not slurp the file, but we
	# read STDIN line by line.  Cuts down on memory usage GREATLY within the running of the script.
	$u = 0;
	my $arg = lc $ARGV[0];
	if ($arg eq "md5_gen") { $arg = "md5_gen="; }
	if (substr($arg,0,8) eq "md5_gen=") {
		@funcs = ();
		push(@funcs, $arg = md5_gen_compile(substr($arg,8)));
	}
	foreach (@funcs) {
		if ($arg eq lc $_) {
			if (-t STDOUT) { print "\n  ** Here are the hashes for format $_ **\n"; }
			while (<STDIN>) {
				next if (/^#!comment/);
				chomp;
				s/\r$//;  # strip CR for non-Windows
				my $line_len = length($_);
				next if $line_len > $arg_maxlen || $line_len < $arg_minlen;
				no strict 'refs';
				&$arg($_);
				use strict;
				++$u;
				last if $u >= $arg_count;
			}
			last;
		}
	}
} else {
	#slurp the wordlist words from stdin.  We  have to, to be able to run the same words multiple
	# times, and not interleave the format 'types' in the file.  Doing this allows us to group them.
	my @lines = <STDIN>;
 
	foreach (@ARGV) {
		$u = 0;
		my $arg = lc $_;
		if (substr($arg,0,8) eq "md5_gen=") {
			push(@funcs, $arg = md5_gen_compile(substr($ARGV[0],8)));
		}
		foreach (@funcs) {
			if ($arg eq lc $_) {
				if (-t STDOUT) { print "\n  ** Here are the hashes for format $_ **\n"; }
				foreach (@lines) {
					next if (/^#!comment/);
					chomp;
					s/\r$//;  # strip CR for non-Windows
					my $line_len = length($_);
					next if $line_len > $arg_maxlen || $line_len < $arg_minlen;
					no strict 'refs';
					&$arg($_);
					use strict;
					++$u;
					last if $u >= $arg_count;
				}
				last;
			}
		}
	}
}
 
#############################################################################
# used to get salts.  Call with randstr(count[,array of valid chars] );   array is 'optional'  Default is AsciiText (UPloCase,  nums, _ )
#############################################################################
sub randstr
{
	my @chr = defined($_[1]) ? @{$_[1]} : @chrAsciiTextNum;
	my $s;
	foreach (1..$_[0]) {
		$s.=$chr[rand @chr];
	}
	return $s;
}
sub randbytes {
	my $ret = "";
	foreach(1 .. $_[0]) {
		$ret .= chr(rand(256));
	}
	return $ret;
}
sub randusername {
	my $num = shift;
	my $user = $userNames[rand @userNames];
	if (defined($num) && $num > 0) {
		while (length($user) > $num) {
			$user = $userNames[rand @userNames];
		}
	}
	return $user;
}
# helper function needed by md5_a (or md5_1 if we were doing that one)
sub to64 #unsigned long v, int n)
{
	my $str, my $n = $_[1], my $v = $_[0];
	while (--$n >= 0) {
		$str .= $i64[$v & 0x3F];
		$v >>= 6;
	}
	return $str;
}
# helper function for nsldap and nsldaps
sub ns_base64 {
	my $ret = "";
	my $n; my @ha = split(//,$h);
	for ($i = 0; $i <= $_[0]; ++$i) {
		# the first one gets some unitialized at times.
		#$n = ord($ha[$i*3+2]) | (ord($ha[$i*3+1])<<8)  | (ord($ha[$i*3])<<16);
		$n = ord($ha[$i*3])<<16;
		if (@ha > $i*3+1) {$n |= (ord($ha[$i*3+1])<<8);}
		if (@ha > $i*3+2) {$n |= ord($ha[$i*3+2]);}
		$ret .= "$ns_i64[($n>>18)&0x3F]";
		if ($_[1] == 3 && $i == $_[0]) { $ret .= "="; }
		else {$ret .= "$ns_i64[($n>>12)&0x3F]"; }
		if ($_[1] > 1 && $i == $_[0]) { $ret .= "="; }
		else {$ret .= "$ns_i64[($n>>6)&0x3F]"; }
		if ($_[1] > 0 && $i == $_[0]) { $ret .= "="; }
		else {$ret .= "$ns_i64[$n&0x3F]"; }
	}
	return $ret;
}
#helper function for ns
sub ns_base64_2 {
	my $ret = "";
	my $n; my @ha = split(//,$h);
	for ($i = 0; $i < $_[0]; ++$i) {
		# the first one gets some unitialized at times..  Same as the fix in ns_base64
		#$n = ord($ha[$i*2+1]) | (ord($ha[$i*2])<<8);
		$n = ord($ha[$i*2])<<8;
		if (@ha > $i*2+1) { $n |= ord($ha[$i*2+1]); }
		$ret .= "$ns_i64[($n>>12)&0xF]";
		$ret .= "$ns_i64[($n>>6)&0x3F]";
		$ret .= "$ns_i64[$n&0x3F]";
	}
	return $ret;
}
# helper function to convert binary to hex.  Many formats store salts and such in hex
sub saltToHex {
	my $ret = "";
	my @sa = split(//,$salt);
	for ($i = 0; $i < $_[0]; ++$i) {
		$ret .= $chrHexLo[ord($sa[$i])>>4];
		$ret .= $chrHexLo[ord($sa[$i])&0xF];
	}
	return $ret;
}
#############################################################################
# Here are the encryption subroutines.
#  the format of ALL of these is:    function(password)
#  all salted formats choose 'random' salts, in one way or another.
#############################################################################
sub des {
	$h = Authen::Passphrase::DESCrypt->new(passphrase => $_[0], salt_random => 12);
	print "u$u-DES:", $h->as_crypt, ":$u:0:$_[0]::\n";
}
sub bigcrypt {
	if (length($_[0]) > 8) {
		$h = Authen::Passphrase::BigCrypt->new(passphrase => $_[0], salt_random => 12);
		print "u$u-DES_BigCrypt:", $h->salt_base64_2, $h->hash_base64, ":$u:0:$_[0]::\n";
	}
}
sub bsdi {
	$h = Authen::Passphrase::DESCrypt->new(passphrase => $_[0], fold => 1, nrounds => 725, salt_random => 24);
	print "u$u-BSDI:", $h->as_crypt, ":$u:0:$_[0]::\n";
}
sub md5_1 {
	if (length($_[0]) > 15) { print "Warning, john can only handle 15 byte passwords for this format!\n"; }
	$h = Authen::Passphrase::MD5Crypt->new(passphrase => $_[0], salt_random => 1);
	print "u$u-MD5:", $h->as_crypt, ":$u:0:$_[0]::\n";
}
sub bfx_fix_pass {
	my $pass = $_[0];
	my $i;
	for ($i = 0; $i < length($pass); $i++) {
	   my $s = substr($pass, $i, 1);
	   last if (ord($s) >= 0x80);
	}
	if ($i == length($pass)) { return $pass; } # if no high bits set, then the error would NOT show up.
	my $pass_ret = "";
	# Ok, now do the logic from 'broken' BF_std_set_key().
	# When we get to a 4 byte limb, that has (limb&0xFF) == 0, we return the accumlated string, minus that last null.
	my $BF_word; my $ptr=0;
	for ($i = 0; $i < 18; $i++) {  # BF_Rounds is 16, so 16+2 is 18
		$BF_word = 0;
		for (my $j = 0; $j < 4; $j++) {
			$BF_word <<= 8;
			my $c;
			if ($ptr < length($pass)) {
				$c = substr($pass, $ptr, 1);
				if (ord($c) > 0x80) {
					$BF_word = 0xFFFFFF00;
				}
				$BF_word |= ord($c);
			}
			if ($ptr < length($pass)) { $ptr++; }
			else { $ptr = 0; }
		}
		$pass_ret .= chr(($BF_word&0xFF000000)>>24);
		$pass_ret .= chr(($BF_word&0x00FF0000)>>16);
		$pass_ret .= chr(($BF_word&0x0000FF00)>>8);
		if ( ($BF_word & 0xFF) == 0) {
			# done  (uncomment to see just 'what' the password is.  i.e. the hex string of the password)
			#print unpack("H*", $pass_ret) . "\n";
			return $pass_ret;
		}
		$pass_ret .= chr($BF_word&0xFF);
	}
}
sub bfx {
	my $fixed_pass = bfx_fix_pass($_[0]);
	if ($argsalt && length($argsalt)==16) {
		$h = Authen::Passphrase::BlowfishCrypt->new(passphrase => $fixed_pass, cost => 5, salt => $argsalt);
	}
	else {
		$h = Authen::Passphrase::BlowfishCrypt->new(passphrase => $fixed_pass, cost => 5, salt_random => 1);
	}
	my $hash_str = $h->as_crypt;
	$hash_str =~ s/\$2a\$/\$2x\$/;
	print "u$u-BF:", $hash_str, ":$u:0:$_[0]::\n";
}
sub bf {
	if ($argsalt && length($argsalt)==16) {
		$h = Authen::Passphrase::BlowfishCrypt->new(passphrase => $_[0], cost => 5, salt => $argsalt);
	}
	else {
		$h = Authen::Passphrase::BlowfishCrypt->new(passphrase => $_[0], cost => 5, salt_random => 1);
	}
	print "u$u-BF:", $h->as_crypt, ":$u:0:$_[0]::\n";
}
sub bfegg {
	if (length($_[0]) > 0) {
		$h = Authen::Passphrase::EggdropBlowfish->new(passphrase => $_[0] );
		print "u$u-BFegg:+", $h->hash_base64, ":$u:0:$_[0]::\n";
	}
}
sub rawmd5 {
	print "u$u-RawMD5:", md5_hex($_[0]), ":$u:0:$_[0]::\n";
}
sub rawmd5u {
	print "u$u-RawMD5-unicode:", md5_hex(encode("UTF-16LE",$_[0])), ":$u:0:$_[0]::\n";
}
sub rawsha1 {
	print "u$u-RawSHA1:", sha1_hex($_[0]), ":$u:0:$_[0]::\n";
}
sub rawsha1u {
	print "u$u-RawSHA1-unicode:", sha1_hex(encode("UTF-16LE",$_[0])), ":$u:0:$_[0]::\n";
}
sub mscash {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt = randusername(19);
	}
	print "$salt:", md4_hex(md4(encode("UTF-16LE",$_[0])).encode("UTF-16LE", lc($salt))),
			":$u:0:$_[0]:mscash (uname is salt):\n";
}
sub mscash2 {
	# max username (salt) length is supposed to be 19 characters (in John)
	# max password length is 27 characters (in John)
	# the algorithm lowercases the salt
	my $user;
	if (defined $argsalt) {
		$user = $argsalt;
	} else {
		$user = randusername(22);
	}
	$salt = encode("UTF-16LE", lc($user));
	my $pbkdf2 = Crypt::PBKDF2->new(
		hash_class => 'HMACSHA1',
		iterations => 10240,
		output_len => 16,
		salt_len => length($salt),
		);
	# Crypt::PBKDF2 hex output is buggy, we do it ourselves!
	print "$user:", unpack("H*", $pbkdf2->PBKDF2($salt,md4(md4(encode("UTF-16LE",$_[0])).$salt))),
	":$u:0:$_[0]:mscash2:\n";
}
sub lm {
	my $s = $_[0];
	if (length($s)>14) { $s = substr($s,14);}
	$h = Authen::Passphrase::LANManager->new(passphrase => length($s) <= 14 ? $s : "");
	print "u$u-LM:$u:", $h->hash_hex, ":$u:0:", uc $s, "::\n";
}
sub nt { #$utf8mode=0, $utf8_pass;
	$h = Authen::Passphrase::NTHash->new(passphrase => $_[0]);
	print "u$u-NT:\$NT\$", $h->hash_hex, ":$u:0:$_[0]::\n";
}
sub pwdump {
	my $lm = Authen::Passphrase::LANManager->new(passphrase => length($_[0]) <= 14 ? $_[0] : "");
	my $nt = Authen::Passphrase::NTHash->new(passphrase => $_[0]);
	print "u$u-pwdump:$u:", $lm->hash_hex, ":", $nt->hash_hex, ":$_[0]::\n";
}
sub rawmd4 {
	print "u$u-RawMD4:", md4_hex($_[0]), ":$u:0:$_[0]::\n";
}
sub mediawiki {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt = randstr(8);
	}
	print "u$u-mediawiki:\$B\$" . $salt . "\$" . md5_hex($salt . "-" . md5_hex($_[0])) . ":$u:0:$_[0]::\n";
}
sub phpass {
	$h = Authen::Passphrase::PHPass->new(cost => 11, salt_random => 1, passphrase => $_[0]);
	print "u$u-PHPass:", $h->as_crypt, ":$u:0:$_[0]::\n";
}
sub po {
	if (defined $argsalt) {
		if ($argsalt.length() == 32) { $salt = $argsalt; }
		else { $salt = md5_hex($argsalt); }
	} else {
		$salt=randstr(32, \@chrHexLo);
	}
	print "u$u-PO:", md5_hex($salt . "Y" . $_[0] . "\xF7" . $salt), "$salt:$u:0:$_[0]::\n";
}
sub md5_a_hash {
	# not 'native' in the Authen::MD5Crypt (but should be!!!)
	# NOTE, this function is about 2.5x FASTER than Authen::MD5Crypt !!!!!
	# have to use md5() function to get the 'raw' md5s, and do our 1000 loops.
	# md5("a","b","c") == md5("abc");
	my $b, my $c, my $tmp;
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt=randstr(8);
	}
	#create $b
	$b = md5($_[0],$salt,$_[0]);
	#create $a
	$tmp = $_[0] . q"$apr1$" . $salt;  # if this is $1$ then we have 'normal' BSD MD5
	for ($i = length($_[0]); $i > 0; $i -= 16) {
		if ($i > 16) { $tmp .= $b; }
		else { $tmp .= substr($b,0,$i); }
	}
	for ($i = length($_[0]); $i > 0; $i >>= 1) {
		if ($i & 1) { $tmp .= "\x0"; }
		else { $tmp .= substr($_[0],0,1); }
	}
	$c = md5($tmp);
 
	# now we do 1000 iterations of md5.
	for ($i = 0; $i < 1000; ++$i) {
		if ($i&1) { $tmp = $_[0]; }
		else      { $tmp = $c; }
		if ($i%3) { $tmp .= $salt; }
		if ($i%7) { $tmp .= $_[0]; }
		if ($i&1) { $tmp .= $c; }
		else      { $tmp .= $_[0]; }
		$c = md5($tmp);
	}
	# $c now contains the 'proper' md5 hash.  However, MD5-a (or MD5-BSD), do a strange
	# transposition and base-64 conversion. We do the same here, to get the same hash
	$i = (ord(substr($c,0,1))<<16) | (ord(substr($c,6,1))<<8) | ord(substr($c,12,1));
	$tmp = to64($i,4);
	$i = (ord(substr($c,1,1))<<16) | (ord(substr($c,7,1))<<8) | ord(substr($c,13,1));
	$tmp .= to64($i,4);
	$i = (ord(substr($c,2,1))<<16) | (ord(substr($c,8,1))<<8) | ord(substr($c,14,1));
	$tmp .= to64($i,4);
	$i = (ord(substr($c,3,1))<<16) | (ord(substr($c,9,1))<<8) | ord(substr($c,15,1));
	$tmp .= to64($i,4);
	$i = (ord(substr($c,4,1))<<16) | (ord(substr($c,10,1))<<8) | ord(substr($c,5,1));
	$tmp .= to64($i,4);
	$i =                                                         ord(substr($c,11,1));
	$tmp .= to64($i,2);
	my $ret = "\$apr1\$$salt\$$tmp";
	return $ret;
}
sub md5_a {
	if (length($_[0]) > 15) { print "Warning, john can only handle 15 byte passwords for this format!\n"; }
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt=randstr(8);
	}
	$h = md5_a_hash($_[0], $salt);
	print "u$u-md5a:$h:$u:0:$_[0]::\n";
}
sub binToHex {
	my $bin = shift;
	my $ret = "";
	my @sa = split(//,$bin);
	for ($i = 0; $i < length($bin); ++$i) {
		$ret .= $chrHexLo[ord($sa[$i])>>4];
		$ret .= $chrHexLo[ord($sa[$i])&0xF];
	}
	return $ret;
}
sub _hmacmd5 {
	my ($key, $data) = @_;
	my $ipad; my $opad;
	for ($i = 0; $i < length($key); ++$i) {
		$ipad .= chr(ord(substr($key, $i, 1)) ^ 0x36);
		$opad .= chr(ord(substr($key, $i, 1)) ^ 0x5C);
	}
	while ($i++ < 64) {
		$ipad .= chr(0x36);
		$opad .= chr(0x5C);
	}
	return md5($opad,md5($ipad,$data));
}
sub hmacmd5 {
	# now uses _hmacmd5 instead of being done inline.
	$salt = randstr(32);
	my $bin = _hmacmd5($_[0], $salt);
	print "u$u-hmacMD5:$salt#", binToHex($bin), ":$u:0:$_[0]::\n";
}
sub mskrb5 {
	my $password = shift;
	my $datestring = sprintf('20%02u%02u%02u%02u%02u%02uZ', rand(100), rand(12)+1, rand(31)+1, rand(24), rand(60), rand(60));
	my $timestamp = randbytes(14) . $datestring . randbytes(7);
	my $K = Authen::Passphrase::NTHash->new(passphrase => $password)->hash;
	my $K1 = _hmacmd5($K, pack('N', 0x01000000));
	my $K2 = _hmacmd5($K1, $timestamp);
	my $K3 = _hmacmd5($K1, $K2);
	my $encrypted = RC4($K3, $timestamp);
	printf("%s:\$mskrb5\$\$\$%s\$%s:::%s:%s\n", "u$u-mskrb5", binToHex($K2), binToHex($encrypted), $password, $datestring);
}
sub ipb2 {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt = randstr(5);
	}
	print "u$u-IPB2:\$IPB2\$", saltToHex(5);
	print "\$", md5_hex(md5_hex($salt), md5_hex($_[0])), ":$u:0:$_[0]::\n";
 
}
sub phps {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt = randstr(3);
	}
	print "u$u-PHPS:\$PHPS\$", saltToHex(3);
	print "\$", md5_hex(md5_hex($_[0]), $salt), ":$u:0:$_[0]::\n";
}
sub md4p {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt = randstr(8);
	}
	print "u$u-MD4p:\$MD4p\$$salt\$", md4_hex($salt, $_[0]), ":$u:0:$_[0]::\n";;
}
sub md4s {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt = randstr(8);
	}
	print "u$u-MD4s:\$MD4s\$$salt\$", md4_hex($_[0], $salt), ":$u:0:$_[0]::\n";;
}
sub sha1p {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt = randstr(8);
	}
	print "u$u-SHA1p:\$SHA1p\$$salt\$", sha1_hex($salt, $_[0]), ":$u:0:$_[0]::\n";;
}
sub sha1s {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt = randstr(8);
	}
	print "u$u-SHA1s:\$SHA1s\$$salt\$", sha1_hex($_[0], $salt), ":$u:0:$_[0]::\n";;
}
sub mysqlsha1 {
	print "u$u-mysqlSHA1:*", sha1_hex(sha1($_[0])), ":$u:0:$_[0]::\n";
}
sub mysql{
	my $nr=0x50305735;
	my $nr2=0x12345671;
	my $add=7;
	for (my $i = 0; $i < length($_[0]); ++$i) {
		my $ch = substr($_[0], $i, 1);
		if ( !($ch eq ' ' || $ch eq '\t') ) {
			my $charNum = ord($ch);
			# since perl is big num, we need to force some 32 bit truncation
			# at certain 'points' in the algorithm, by doing &= 0xffffffff
			$nr ^= ((($nr & 63)+$add)*$charNum) + (($nr << 8)&0xffffffff);
			$nr2 += ( (($nr2 << 8)&0xffffffff) ^ $nr);
			$add += $charNum;
		}
	}
	printf("u%d-mysq:%08x%08x:%d:0:%s::\n", $u, ($nr & 0x7fffffff), ($nr2 & 0x7fffffff), $u, $_[0]);
}
sub pixmd5 {
	my $pass = $_[0];
	if (length($pass)>16) { $pass = substr($pass,0,16); }
	my $pass_padd = $pass;
	while (length($pass_padd) < 16) { $pass_padd .= "\x0"; }
	my $c = md5($pass_padd);
	$h = "";
	for ($i = 0; $i < 16; $i+=4) {
		my $n = ord(substr($c,$i,1))|(ord(substr($c,$i+1,1))<<8)|(ord(substr($c,$i+2,1))<<16);
		$h .= $i64[$n       & 0x3f];
		$h .= $i64[($n>>6)  & 0x3f];
		$h .= $i64[($n>>12) & 0x3f];
		$h .= $i64[($n>>18) & 0x3f];
	}
	print "u$u-pixmd5:$h:$u:0:", $pass, "::\n";
}
sub mssql05 {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt=randstr(4);
	}
	print "u$u-mssql05:0x0100", uc saltToHex(4);
	print uc sha1_hex(encode("UTF-16LE", $_[0]).$salt), ":$u:0:$_[0]::\n";
}
sub mssql {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt=randstr(4);
	}
	print "u$u-mssql:0x0100", uc saltToHex(4);
	print uc sha1_hex(encode("UTF-16LE", $_[0]).$salt) . uc sha1_hex(encode("UTF-16LE", uc $_[0]).$salt), ":$u:0:" . uc $_[0] . ":" . $_[0] . ":\n";
}
sub nsldap {
	$h = sha1($_[0]);
	print "u$u-nsldap:{SHA}", ns_base64(6,1), ":$u:0:$_[0]::\n";
}
sub nsldaps {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt=randstr(8);
	}
	$h = sha1($_[0],$salt);
	$h .= $salt;
	print "u$u-nsldap:{SSHA}", ns_base64(9,2), ":$u:0:$_[0]::\n";
}
sub openssha {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt=randstr(4);
	}
	$h = sha1($_[0],$salt);
	$h .= $salt;
	print "u$u-openssha:{SSHA}", ns_base64(7,0), ":$u:0:$_[0]::\n";
}
sub ns {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt=randstr(3 + rand 4, \@chrHexLo);
	}
	$h = md5($salt, ":Administration Tools:", $_[0]);
	my $hh = ns_base64_2(8);
	substr($hh, 0, 0) = 'n';
	substr($hh, 6, 0) = 'r';
	substr($hh, 12, 0) = 'c';
	substr($hh, 17, 0) = 's';
	substr($hh, 23, 0) = 't';
	substr($hh, 29, 0) = 'n';
	print "u$u-ns:$salt\$", $hh, ":$u:0:$_[0]::\n";
}
sub xsha {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt=randstr(4);
	}
	print "u$u-xsha:", uc saltToHex(4), uc sha1_hex($salt, $_[0]), ":$u:0:$_[0]::\n";
}
sub oracle {
	# snagged perl source from http://users.aber.ac.uk/auj/freestuff/orapass.pl.txt
	my $username;
	if (defined $argsalt) {
		$username = $argsalt;
	} else {
		$username = randusername(16);
	}
	my $pass = $_[0];
#	print "orig = " . $username . $pass . "\n";
#	print "upcs = " . uc($username.$pass) . "\n\n";
	my $userpass = pack('n*', unpack('C*', uc($username.$pass)));
	$userpass .= pack('C', 0) while (length($userpass) % 8);
	my $key = pack('H*', "0123456789ABCDEF");
	my $iv = pack('H*', "0000000000000000");
	my $cr1 = new Crypt::CBC(	-literal_key => 1, -cipher => "DES", -key => $key, -iv => $iv, -header => "none" );
	my $key2 = substr($cr1->encrypt($userpass), length($userpass)-8, 8);
	my $cr2 = new Crypt::CBC( -literal_key => 1, -cipher => "DES", -key => $key2, -iv => $iv, -header => "none" );
	my $hash = substr($cr2->encrypt($userpass), length($userpass)-8, 8);
	print "$username:", uc(unpack('H*', $hash)), ":$u:0:$pass:oracle_des_hash:\n";
}
sub oracle11 {
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt=randbytes(10);
	}
	print "u$u-oracle11:", uc sha1_hex($_[0], $salt), uc saltToHex(10), ":$u:0:$_[0]::\n";
}
sub hdaa {
	# same as md5_gen(21)
	#  	{"$response$679066476e67b5c7c4e88f04be567f8b$user$myrealm$GET$/$8c12bd8f728afe56d45a0ce846b70e5a$00000001$4b61913cec32e2c9$auth", "nocode"},
	my $user = randusername(20);
	my $nonce = randstr(32, \@chrHexLo);
	my $clientNonce = randstr(16, \@chrHexLo);
	my $h1 = md5_hex($user, ":myrealm:", $_[0]);
	my $h2 = md5_hex("GET:/");
	my $resp = md5_hex($h1, ":", $nonce, ":00000001:", $clientNonce, ":auth:", $h2);
	print "u$u-HDAA:\$response\$$resp\$$user\$myrealm\$GET\$/\$$nonce\$00000001\$$clientNonce\$auth:$u:0:$_[0]::\n";
}
 
sub setup_des_key
{
	my @key_56 = split(//, shift);
	my $key = "";
	$key = $key_56[0];
	$key .= chr(((ord($key_56[0]) << 7) | (ord($key_56[1]) >> 1)) & 255);
	$key .= chr(((ord($key_56[1]) << 6) | (ord($key_56[2]) >> 2)) & 255);
	$key .= chr(((ord($key_56[2]) << 5) | (ord($key_56[3]) >> 3)) & 255);
	$key .= chr(((ord($key_56[3]) << 4) | (ord($key_56[4]) >> 4)) & 255);
	$key .= chr(((ord($key_56[4]) << 3) | (ord($key_56[5]) >> 5)) & 255);
	$key .= chr(((ord($key_56[5]) << 2) | (ord($key_56[6]) >> 6)) & 255);
	$key .= chr((ord($key_56[6]) << 1) & 255);
	return $key;
}
# This produces only NETNTLM ESS hashes, in L0phtcrack format
sub netntlm_ess {
	my $password = shift;
	my $domain = randstr(rand(15)+1);
	my $nthash = Authen::Passphrase::NTHash->new(passphrase => $password)->hash;
	$nthash .= "\x00"x5;
	my $s_challenge = randbytes(8);
	my $c_challenge = randbytes(8);
	my $challenge = substr(md5($s_challenge.$c_challenge), 0, 8);
	my $ntresp = Crypt::ECB::encrypt(setup_des_key(substr($nthash, 0, 7)), 'DES', $challenge, PADDING_NONE);
	$ntresp .= Crypt::ECB::encrypt(setup_des_key(substr($nthash, 7, 7)), 'DES', $challenge, PADDING_NONE);
	$ntresp .= Crypt::ECB::encrypt(setup_des_key(substr($nthash, 14, 7)), 'DES', $challenge, PADDING_NONE);
	my $type = "ntlm ESS";
	my $lmresp = $c_challenge . "\0"x16;
	printf("%s\\%s:::%s:%s:%s::%s:%s\n", $domain, "u$u-netntlm", binToHex($lmresp), binToHex($ntresp), binToHex($s_challenge), $password, $type);
}
# This produces NETHALFLM, NETLM and non-ESS NETNTLM hashes in L0pthcrack format
sub l0phtcrack {
    my $password = shift;
	my $domain = randstr(rand(15)+1);
	my $nthash = Authen::Passphrase::NTHash->new(passphrase => $password)->hash;
	$nthash .= "\x00"x5;
	my $lmhash; my $lmresp;
	my $challenge = randbytes(8);
	my $ntresp = Crypt::ECB::encrypt(setup_des_key(substr($nthash, 0, 7)), 'DES', $challenge, PADDING_NONE);
	$ntresp .= Crypt::ECB::encrypt(setup_des_key(substr($nthash, 7, 7)), 'DES', $challenge, PADDING_NONE);
	$ntresp .= Crypt::ECB::encrypt(setup_des_key(substr($nthash, 14, 7)), 'DES', $challenge, PADDING_NONE);
	my $type;
	if ($arg_utf8 or length($password) > 14) {
		$type = "ntlm only";
		$lmresp = $ntresp;
	} else {
		$type = "lm and ntlm";
		$lmhash = Authen::Passphrase::LANManager->new(passphrase => $password)->hash;
		$lmhash .= "\x00"x5;
		$lmresp = Crypt::ECB::encrypt(setup_des_key(substr($lmhash, 0, 7)), 'DES', $challenge, PADDING_NONE);
		$lmresp .= Crypt::ECB::encrypt(setup_des_key(substr($lmhash, 7, 7)), 'DES', $challenge, PADDING_NONE);
		$lmresp .= Crypt::ECB::encrypt(setup_des_key(substr($lmhash, 14, 7)), 'DES', $challenge, PADDING_NONE);
	}
	printf("%s\\%s:::%s:%s:%s::%s:%s\n", $domain, "u$u-netntlm", binToHex($lmresp), binToHex($ntresp), binToHex($challenge), $password, $type);
}
sub netlmv2 {
	my $pwd = shift;
	my $nthash = Authen::Passphrase::NTHash->new(passphrase => $pwd)->hash;
	my $domain = randstr(rand(15)+1);
	my $user = randusername(20);
	my $identity = Encode::encode("UTF-16LE", uc($user).$domain);
	my $s_challenge = randbytes(8);
	my $c_challenge = randbytes(8);
	my $lmresponse = _hmacmd5(_hmacmd5($nthash, $identity), $s_challenge.$c_challenge);
	printf("%s\\%s:::%s:%s:%s::%s:netlmv2\n", $domain, $user, binToHex($s_challenge), binToHex($lmresponse), binToHex($c_challenge), $pwd);
}
sub netntlmv2 {
	my $pwd = shift;
	my $nthash = Authen::Passphrase::NTHash->new(passphrase => $pwd)->hash;
	my $domain = randstr(rand(15)+1);
	my $user = randusername(20);
	my $identity = Encode::encode("UTF-16LE", uc($user).$domain);
	my $s_challenge = randbytes(8);
	my $c_challenge = randbytes(8);
	my $temp = '\x01\x01' . "\x00"x6 . randbytes(8) . $c_challenge . "\x00"x4 . randbytes(20*rand()+1) . '\x00';
	my $ntproofstr = _hmacmd5(_hmacmd5($nthash, $identity), $s_challenge.$temp);
	# $ntresponse = $ntproofstr.$temp but we separate them with a :
	printf("%s\\%s:::%s:%s:%s::%s:netntlmv2\n", $domain, $user, binToHex($s_challenge), binToHex($ntproofstr), binToHex($temp), $pwd);
}
sub mschapv2 {
	my $pwd = shift;
	my $nthash = Authen::Passphrase::NTHash->new(passphrase => $pwd)->hash;
	my $user = "u-$u-mschapv2"; #randusername() did not work here! Something with user '01234' being treated as a number in $ctx->add() it seems.
	my $a_challenge = randbytes(16);
	my $p_challenge = randbytes(16);
	my $ctx = Digest::SHA->new('sha1');
	$ctx->add($p_challenge);
	$ctx->add($a_challenge);
	$ctx->add($user);
	my $challenge = substr($ctx->digest, 0, 8);
	my $response = Crypt::ECB::encrypt(setup_des_key(substr($nthash, 0, 7)), 'DES', $challenge, PADDING_NONE);
	$response .= Crypt::ECB::encrypt(setup_des_key(substr($nthash, 7, 7)), 'DES', $challenge, PADDING_NONE);
	$response .= Crypt::ECB::encrypt(setup_des_key(substr($nthash . "\x00" x 5, 14, 7)), 'DES', $challenge, PADDING_NONE);
	printf("%s:::%s:%s:%s::%s:netntlmv2\n", $user, binToHex($a_challenge), binToHex($response), binToHex($p_challenge), $pwd);
}
 
############################################################
#  MD5_Gen code.  Quite a large block.  Many 'fixed' formats, and then a parser
############################################################
sub md5_gen_7 { #md5_gen(7) --> md5(md5($p).$s)
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt = randstr(3);
	}
	print "u$u-md5gen(7)"."\x1F"."md5_gen(7)", md5_hex(md5_hex($_[0]), $salt), "\$$salt"."\x1F"."$u"."\x1F"."0"."\x1F"."$_[0]"."\x1F"."\x1F"."\n";
}
sub md5_gen_17 { #md5_gen(17) --> phpass ($P$ or $H$)	phpass
	$h = Authen::Passphrase::PHPass->new(cost => 11, salt_random => 1, passphrase => $_[0]);
	my $hh = $h->as_crypt;
	$salt = substr($hh,3,9);
	print "u$u-md5gen(17):md5_gen(17)", substr($hh,12), "\$$salt:$u:0:$_[0]::\n";
}
sub md5_gen_19 { #md5_gen(19) --> Cisco PIX (MD5)
	my $pass;
	if (length($_[0])>16) { $pass = substr($_[0],0,16); } else { $pass = $_[0]; }
	my $pass_padd = $pass;
	while (length($pass_padd) < 16) { $pass_padd .= "\x0"; }
	my $c = md5($pass_padd);
	$h = "";
	for ($i = 0; $i < 16; $i+=4) {
		my $n = ord(substr($c,$i,1))|(ord(substr($c,$i+1,1))<<8)|(ord(substr($c,$i+2,1))<<16);
		$h .= $i64[$n       & 0x3f];
		$h .= $i64[($n>>6)  & 0x3f];
		$h .= $i64[($n>>12) & 0x3f];
		$h .= $i64[($n>>18) & 0x3f];
	}
	print "u$u-md5gen(19):md5_gen(19)$h:$u:0:", $pass, "::\n";
}
sub md5_gen_20 { #md5_gen(20) --> Cisco PIX (MD5 salted)
	if (defined $argsalt) {
		$salt = $argsalt;
		if (length($salt) > 4) { $salt = substr($salt,0,4); }
	} else {
		$salt = randstr(4);
	}
	my $pass;
	if (length($_[0])>12) { $pass = substr($_[0],0,12); } else { $pass = $_[0]; }
	my $pass_padd = $pass . $salt;
	while (length($pass_padd) < 16) { $pass_padd .= "\x0"; }
	my $c = md5($pass_padd);
	$h = "";
	for ($i = 0; $i < 16; $i+=4) {
		my $n = ord(substr($c,$i,1))|(ord(substr($c,$i+1,1))<<8)|(ord(substr($c,$i+2,1))<<16);
		$h .= $i64[$n       & 0x3f];
		$h .= $i64[($n>>6)  & 0x3f];
		$h .= $i64[($n>>12) & 0x3f];
		$h .= $i64[($n>>18) & 0x3f];
	}
	print "u$u-md5gen(20):md5_gen(20)$h\$$salt:$u:0:", $pass, "::\n";
}
sub md5_gen_21 { #HDAA HTTP Digest  access authentication
	#md5_gen(21)679066476e67b5c7c4e88f04be567f8b$8c12bd8f728afe56d45a0ce846b70e5a$$Uuser$$F2myrealm$$F3GET$/$$F400000001$4b61913cec32e2c9$auth","nocode"},
	#
	#digest authentication scheme :
	#H1 = md5(user:realm:password)
	#H2 = md5(method:digestURI)
	#response = H3 = md5(h1:nonce:nonceCount:ClientNonce:qop:h2)
	my $user = randusername(20);
	my $nonce = randstr(32, \@chrHexLo);
	my $clientNonce = randstr(16, \@chrHexLo);
	my $h1 = md5_hex($user, ":myrealm:", $_[0]);
	my $h2 = md5_hex("GET:/");
	my $resp = md5_hex($h1, ":", $nonce, ":00000001:", $clientNonce, ":auth:", $h2);
	print "$user:md5_gen(21)$resp\$$nonce\$\$U$user\$\$F2myrealm\$\$F3GET\$/\$\$F400000001\$$clientNonce\$auth:$u:0:$_[0]::\n";
}
sub md5_gen_27 { #md5_gen(27) --> OpenBSD MD5
	if (length($_[0]) > 15) { print "Warning, john can only handle 15 byte passwords for this format!\n"; }
	$h = Authen::Passphrase::MD5Crypt->new(salt_random => 1, passphrase => $_[0]);
	my $hh = $h->as_crypt;
	$salt = substr($hh,3,8);
	print "u$u-md5gen(27):md5_gen(27)", substr($hh,12), "\$$salt:$u:0:$_[0]::\n";
}
sub md5_gen_28 { # Apache MD5
	if (length($_[0]) > 15) { print "Warning, john can only handle 15 byte passwords for this format!\n"; }
	if (defined $argsalt) {
		$salt = $argsalt;
	} else {
		$salt=randstr(8);
	}
	$h = md5_a_hash($_[0], $salt);
	print "u$u-md5gen(28):md5_gen(28)", substr($h,15), "\$$salt:$u:0:$_[0]::\n";
}
sub md5_gen_compile {
	my $md5_gen_args = $_[0];
	if (length($md5_gen_args) == 0) {
		print "usage: $0 [-h|-?] HashType ... [ < wordfile ]\n";
		print "\n";
		print "NOTE, for md5_gen usage:   here are the possible formats:\n";
		print "    md5_gen=#   # can be any of the built in md5_gen values. So,\n";
		print "                md5_gen=0 will output for md5(\$p) format\n";
		print "\n";
		print "    md5_gen=num=#,format=FMT_EXPR[,saltlen=#][,salt=true|ashex|tohex]\n";
		print "         [,pass=uni][,salt2len=#][,const#=value][,usrname=true|lc|uc|uni]\n";
		print "         [,single_salt=1][passcase=uc|lc]]\n";
		print "\n";
		print "The FMT_EXPR is somewhat 'normal' php type format, with some extensions.\n";
		print "    A format such as md5(\$p.\$s.md5(\$p)) is 'normal'.  Dots must be used\n";
		print "    where needed. Also, only a SINGLE expression is valid.  Using an\n";
		print "    expression such as md5(\$p).md5(\$s) is not valid.\n";
		print "    The extensions are:\n";
		print "        Added \$s2 (if 2nd salt is defined),\n";
		print "        Added \$c1 to \$c9 for constants (must be defined in const#= values)\n";
		print "        Added \$u if user name (normal, upper/lower case or unicode convert)\n";
		print "        Handle md5, sha1, and md4 algorithms.\n";
		print "        Handle MD5, SHA1 and MD4 which are hex output in uppercase.\n";
		print "        Handle md5_64, sha1_64 and md4_64 which output in 'standard'\n";
		print "          base-64 which is \"./0-9A-Za-z\"\n";
		print "        Handle md5_64e, sha1_64e and md4_64e which output in 'standard'\n";
		print "          base-64 which is \"./0-9A-Za-z\" with '=' padding up to even\n";
		print "          4 character (similar to mime-base64\n";
		print "        Handle md5_raw, sha1_raw and md4_raw which output is the 'binary'\n";
		print "          16 or 20 bytes of data.  CAN not be used as 'outside' function\n";
		print "    User names are handled by usrname=  if true, then \'normal\' user names\n";
		print "    used, if lc, then user names are converted to lowercase, if uc then\n";
		print "    they are converted to UPPER case. if uni they are converted into unicode\n";
		print "    If constants are used, then they have to start from const1= and can \n";
		print "    go up to const9= , but they need to be in order, and start from one (1).\n";
		print "    So if there are 3 constants in the expression, then the line needs to\n";
		print "    contain const1=v1,const2=v2,const3=v3 (v's replaced by proper constants)\n";
		print "    if pw=uni is used, the passwords are converted into unicode before usage\n";
		die;
	}
	if ($md5_gen_args =~ /^[+\-]?\d*.?\d+$/) { # is $md5_gen_args a 'simple' number?
		#my $func = "md5_gen_" . $md5_gen_args;
		#return $func;
 
		# before we had custom functions for 'all' of the builtin's.  Now we use the compiler
		# for most of them (in the below switch statement) There are only a handful where
		# we keep the 'original' hard coded function (7,17,19,20,21,27,28)
 
 		my $func = "md5_gen_" . $md5_gen_args;
		my $prefmt = "num=$md5_gen_args,optimize=1,format=";
		my $fmt;
 
		SWITCH:	{
			$md5_gen_args==0  && do {$fmt='md5($p)';					last SWITCH; };
			$md5_gen_args==1  && do {$fmt='md5($p.$s),saltlen=32';		last SWITCH; };
			$md5_gen_args==2  && do {$fmt='md5(md5($p))';				last SWITCH; };
			$md5_gen_args==3  && do {$fmt='md5(md5(md5($p)))';			last SWITCH; };
			$md5_gen_args==4  && do {$fmt='md5($s.$p),saltlen=2';		last SWITCH; };
			$md5_gen_args==5  && do {$fmt='md5($s.$p.$s)';				last SWITCH; };
			$md5_gen_args==6  && do {$fmt='md5(md5($p).$s)';			last SWITCH; };
			$md5_gen_args==8  && do {$fmt='md5(md5($s).$p)';			last SWITCH; };
			$md5_gen_args==9  && do {$fmt='md5($s.md5($p))';			last SWITCH; };
			$md5_gen_args==10 && do {$fmt='md5($s.md5($s.$p))';			last SWITCH; };
			$md5_gen_args==11 && do {$fmt='md5($s.md5($p.$s))';			last SWITCH; };
			$md5_gen_args==12 && do {$fmt='md5(md5($s).md5($p))';		last SWITCH; };
			$md5_gen_args==13 && do {$fmt='md5(md5($p).md5($s))';		last SWITCH; };
			$md5_gen_args==14 && do {$fmt='md5($s.md5($p).$s)';			last SWITCH; };
			$md5_gen_args==15 && do {$fmt='md5($u.md5($p).$s)';			last SWITCH; };
			$md5_gen_args==16 && do {$fmt='md5(md5(md5($p).$s).$s2)';	last SWITCH; };
			$md5_gen_args==18 && do {$fmt='md5($s.$c1.$p.$c2.$s),const1=Y,const2='."\xf7".',salt=ashex'; last SWITCH; };
			$md5_gen_args==22 && do {$fmt='md5(sha1($p))';				last SWITCH; };
			$md5_gen_args==23 && do {$fmt='sha1(md5($p))';				last SWITCH; };
			$md5_gen_args==24 && do {$fmt='sha1($p.$s)';				last SWITCH; };
			$md5_gen_args==25 && do {$fmt='sha1($s.$p)';				last SWITCH; };
			$md5_gen_args==26 && do {$fmt='sha1($p)';					last SWITCH; };
			# 7, 17, 19, 20, 21, 27, 28 are still handled by 'special' functions.
			return $func;
		}
		# allow the generic compiler to handle these types.
		$md5_gen_args = $prefmt.$fmt;
 
	}
 
	# now compile.
	md5_gen_compile_to_pcode($md5_gen_args);
 
	#return the name of the function to run the compiled pcode.
	return "md5_gen_run_compiled_pcode";
}
sub do_md5_gen_GetToken {
	# parses next token.
	# the token is placed on the gen_toks array as the 'new' token.
	#  the return is the rest of the string (not tokenized yet)
	# if there is an error, then "tok_bad" (X) is pushed on to the top of the gen_toks array.
	$gen_lastTokIsFunc = 0;
	my $exprStr = $_[0];
	if (!defined($exprStr) || length($exprStr) == 0) { push(@gen_toks, "X"); return $exprStr; }
	my $stmp = substr($exprStr, 0, 1);
 	if ($stmp eq ".") { push(@gen_toks, "."); return substr($exprStr, 1); }
	if ($stmp eq "(") { push(@gen_toks, "("); return substr($exprStr, 1); }
	if ($stmp eq ")") { push(@gen_toks, ")"); return substr($exprStr, 1); }
	if ($stmp eq '$') {
		$stmp = substr($exprStr, 0, 2);
		if ($stmp eq '$p') { push(@gen_toks, "p"); return substr($exprStr, 2); }
		if ($stmp eq '$u') { push(@gen_toks, "u"); return substr($exprStr, 2); }
		if ($stmp eq '$s') {
			if (substr($exprStr, 0, 3) eq '$s2')
			{
				push(@gen_toks, "S");
				return substr($exprStr, 3);
			}
			push(@gen_toks, "s");
			return substr($exprStr, 2);
		}
		if ($stmp ne '$c') { push(@gen_toks, "X"); return $exprStr; }
		$stmp = substr($exprStr, 2, 1);
		if ($stmp eq "1") { push(@gen_toks, "1"); if (!defined($gen_c[0])) {print "\$c1 found, but no constant1 loaded\n"; die; } return substr($exprStr, 3); }
		if ($stmp eq "2") { push(@gen_toks, "2"); if (!defined($gen_c[1])) {print "\$c2 found, but no constant2 loaded\n"; die; } return substr($exprStr, 3); }
		if ($stmp eq "3") { push(@gen_toks, "3"); if (!defined($gen_c[2])) {print "\$c3 found, but no constant3 loaded\n"; die; } return substr($exprStr, 3); }
		if ($stmp eq "4") { push(@gen_toks, "4"); if (!defined($gen_c[3])) {print "\$c4 found, but no constant4 loaded\n"; die; } return substr($exprStr, 3); }
		if ($stmp eq "5") { push(@gen_toks, "5"); if (!defined($gen_c[4])) {print "\$c5 found, but no constant5 loaded\n"; die; } return substr($exprStr, 3); }
		if ($stmp eq "6") { push(@gen_toks, "6"); if (!defined($gen_c[5])) {print "\$c6 found, but no constant6 loaded\n"; die; } return substr($exprStr, 3); }
		if ($stmp eq "7") { push(@gen_toks, "7"); if (!defined($gen_c[6])) {print "\$c7 found, but no constant7 loaded\n"; die; } return substr($exprStr, 3); }
		if ($stmp eq "8") { push(@gen_toks, "8"); if (!defined($gen_c[7])) {print "\$c8 found, but no constant8 loaded\n"; die; } return substr($exprStr, 3); }
		if ($stmp eq "9") { push(@gen_toks, "9"); if (!defined($gen_c[8])) {print "\$c9 found, but no constant9 loaded\n"; die; } return substr($exprStr, 3); }
		push(@gen_toks, "X");
		return $exprStr;
	}
 
	$gen_lastTokIsFunc=1;
	$stmp = uc substr($exprStr, 0, 3);
	if ($stmp eq "MD5") {
		if (substr($exprStr, 0, 7) eq "md5_64e") { push(@gen_toks, "f5e"); return substr($exprStr, 7); }
		if (substr($exprStr, 0, 6) eq "md5_64")  { push(@gen_toks, "f56"); return substr($exprStr, 6); }
		if (substr($exprStr, 0, 3) eq "md5")     { push(@gen_toks, "f5h"); return substr($exprStr, 3); }
		if (substr($exprStr, 0, 3) eq "MD5")     { push(@gen_toks, "f5H"); return substr($exprStr, 3); }
	} elsif ($stmp eq "SHA") {
		if (substr($exprStr, 0, 8) eq "sha1_64e"){ push(@gen_toks, "f1e"); return substr($exprStr, 8); }
		if (substr($exprStr, 0, 7) eq "sha1_64") { push(@gen_toks, "f16"); return substr($exprStr, 7); }
		if (substr($exprStr, 0, 4) eq "SHA1")    { push(@gen_toks, "f1H"); return substr($exprStr, 4); }
		if (substr($exprStr, 0, 4) eq "sha1")    { push(@gen_toks, "f1h"); return substr($exprStr, 4); }
	} elsif ($stmp eq "MD4") {
		if (substr($exprStr, 0, 7) eq "md4_64e") { push(@gen_toks, "f4e"); return substr($exprStr, 7); }
		if (substr($exprStr, 0, 6) eq "md4_64")  { push(@gen_toks, "f46"); return substr($exprStr, 6); }
		if (substr($exprStr, 0, 3) eq "md4")     { push(@gen_toks, "f4h"); return substr($exprStr, 3); }
		if (substr($exprStr, 0, 3) eq "MD4")     { push(@gen_toks, "f4H"); return substr($exprStr, 3); }
	}
 
	$gen_lastTokIsFunc=2; # a func, but can NOT be the 'outside' function.
	if (substr($exprStr, 0, 7) eq "md5_raw")  { push(@gen_toks, "f5r"); return substr($exprStr, 7); }
	if (substr($exprStr, 0, 8) eq "sha1_raw") { push(@gen_toks, "f1r"); return substr($exprStr, 8); }
	if (substr($exprStr, 0, 7) eq "md4_raw")  { push(@gen_toks, "f4r"); return substr($exprStr, 7); }
 
	$gen_lastTokIsFunc=0;
	push(@gen_toks, "X");
	return $exprStr;
}
sub do_md5_gen_LexiError {
	print STDERR "Syntax Error around this part of expression:\n";
	print STDERR "$hash_format\n";
	my $v = (length($hash_format) - length($_[0]));
	if ($gen_toks[@gen_toks - 1] ne "X") { --$v; }
	print STDERR " " x $v;
	print STDERR "^\n";
	if ($gen_toks[@gen_toks - 1] eq "X") { print STDERR "Invalid token found\n"; }
	elsif (defined $_[1]) { print STDERR "$_[1]\n"; }
}
sub do_md5_gen_Lexi {
	# tokenizes the string, and syntax validates that it IS valid.
	@gen_toks=();
	my $fmt = do_md5_gen_GetToken($hash_format);
	if ($gen_lastTokIsFunc!=1) {
		print "The expression MUST start with an md5/md4/sha1 type function.  This one starts with: $_[0]\n";  die;
	}
	my $paren = 0;
	while ($gen_toks[@gen_toks - 1] ne "X") {
		if ($gen_lastTokIsFunc) {
			$fmt = do_md5_gen_GetToken($fmt);
			if ($gen_toks[@gen_toks - 1] ne "(") {
				do_md5_gen_LexiError($fmt, "A ( MUST follow one of the hash function names"); die;
			}
			next;
		}
		if ($gen_toks[@gen_toks - 1] eq "(") {
			$fmt = do_md5_gen_GetToken($fmt);
			if ($gen_toks[@gen_toks - 1] eq "X" || $gen_toks[@gen_toks - 1] eq "." || $gen_toks[@gen_toks - 1] eq "(" || $gen_toks[@gen_toks - 1] eq ")") {
				do_md5_gen_LexiError($fmt, "Invalid character following the ( char"); die;
			}
			++$paren;
			next;
		}
		if ($gen_toks[@gen_toks - 1] eq ")") {
			--$paren;
			if ( length($fmt) == 0) {
				if ($paren == 0) {
					# The format is VALID, and proper syntax checking fully done.
 
					# if we want to dump the token table:
					#for (my $i = 0; $i < @gen_toks; ++$i) {
					#   print "$gen_toks[$i]\n";
					#}
					return @gen_toks; # return the count
				}
				do_md5_gen_LexiError($fmt, "Error, not enough ) characters at end of expression"); die;
			}
			if ($paren == 0) {
				do_md5_gen_LexiError($fmt, "Error, reached the matching ) to the initial (, but there is still more expression left."); die;
			}
			$fmt = do_md5_gen_GetToken($fmt);
			unless ($gen_toks[@gen_toks - 1] eq "." || $gen_toks[@gen_toks - 1] eq ")") {
				do_md5_gen_LexiError($fmt, "The only things valid to follow a ) char, are a . or another )"); die;
			}
			next;
		}
		if ($gen_toks[@gen_toks - 1] eq ".") {
			$fmt = do_md5_gen_GetToken($fmt);
			if ($gen_toks[@gen_toks - 1] eq "X" || $gen_toks[@gen_toks - 1] eq "." || $gen_toks[@gen_toks - 1] eq "(" || $gen_toks[@gen_toks - 1] eq ")") {
				do_md5_gen_LexiError($fmt, "invalid character following the . character"); die;
			}
			next;
		}
		# some 'string op
		$fmt = do_md5_gen_GetToken($fmt);
		unless ($gen_toks[@gen_toks - 1] eq ")" || $gen_toks[@gen_toks - 1] eq ".") {
			do_md5_gen_LexiError($fmt, "Only a dot '.' or a ) can follow a string type token"); die;
		}
	}
}
sub md5_gen_compile_to_pcode {
	$gen_s = ""; $gen_u = ""; $gen_s2 = "";
 
	my $md5_gen_args = $_[0];
	# ok, not a specific version, so we use 'this' format:
	# md5_gen=num=1,salt=true,saltlen=8,format=md5(md5(md5($p.$s).$p).$s)
	# which at this point, we would 'see' in md5_gen_args:
	# num=1,salt=true,saltlen=8,format=md5(md5(md5($p.$s).$p).$s)
 
	# get all of the params into a hash table.
	my %hash;
	my @opts = split(/,/,$md5_gen_args);
	foreach my $x (@opts) {
	   my @opt = split(/=/,$x);
	   $hash {$opt[0]} = $opt[1];
	}
 
	@gen_pCode = ();
	@gen_Flags = ();
 
	########################
	# load the values
	########################
 
	# Validate that the 'required' params are at least here.
	$gen_num = $hash{"num"};
	if (!defined ($gen_num )) { print "Error, num=# is REQUIRED for md5_gen\n"; die; }
	my $v = $hash{"format"};
	if (!defined ($v)) { print "Error, format=# is REQUIRED for md5_gen\n"; die; }
 
	$gen_singlesalt = $hash{"single_salt"};
	if (!defined($gen_singlesalt)) {$gen_singlesalt=0;}
 
	# load PW
	$gen_pw = $_[0];
 
	# load a salt.  If this is unused, then we will clear it out after parsing Lexicon
	$saltlen = $hash{"saltlen"};
	unless (defined($saltlen) && $saltlen =~ /^[+\-]?\d*.?\d+$/) { $saltlen = 8; }
	$gen_stype = $hash{"salt"};
	unless (defined($gen_stype)) { $gen_stype = "true"; }
 
	# load salt #2
	$salt2len = $hash{"salt2len"};
	unless (defined($salt2len) && $salt2len =~ /^[+\-]?\d*.?\d+$/) { $salt2len = 6; }
 
	# load user name
	$md5_gen_usernameType = $hash{"usrname"};
	if (!$md5_gen_usernameType) { $md5_gen_usernameType=0; }
	$md5_gen_passType = $hash{"pass"};
	if (!defined ($md5_gen_passType) || $md5_gen_passType ne "uni") {$md5_gen_passType="";}
	my $pass_case = $hash{"passcase"};
	if (defined($pass_case)) {
		if ( (lc $pass_case) eq "lc") { $gen_PWCase = "L"; }
		if ( (lc $pass_case) eq "uc") { $gen_PWCase = "U"; }
	}
 
	# load constants
	@gen_c=();
	for (my $n = 1; $n <= 9; ++$n) {
		my $c = "const" . $n;
		$v = $hash{$c};
		if (defined($v)) { push(@gen_c, $v); }
		else {last;}
	}
 
	$debug_pcode = $hash{"debug"};
	if (!$debug_pcode) { $debug_pcode=0; }
 
	$hash_format = $hash{"format"};
	my $optimize = $hash{"optimize"};
	if (defined($optimize) && $optimize > 0) {md5_gen_compile_Optimize1();}
 
	######################################
	# syntax check, and load the expression into our token table.
	######################################
	do_md5_gen_Lexi();
	unless (@gen_toks > 3) { print "Error, the format= of the expression was missing, or NOT valid\n"; die; }
 
 	# now clean up salt, salt2, user, etc if they were NOT part of the expression:
	$v = $saltlen; $saltlen=0;
	foreach(@gen_toks) { if ($_ eq "s") {$saltlen=$v;last;} }
	$gen_u_do=0;
	foreach(@gen_toks) { if ($_ eq "u") {$gen_u_do=1;last;} }
	$v = $salt2len; $salt2len=0;
	foreach(@gen_toks) { if ($_ eq "S") {$salt2len=$v;last;} }
 
	# this function actually BUILDS the pcode.
	$gen_needs = 0; $gen_needs2 = 0; $gen_needu = 0;
	md5_gen_compile_expression_to_pcode(0, @gen_toks-1);
 
	if (defined($optimize) && $optimize > 1) {md5_gen_compile_Optimize2();}
 
	# dump pcode
	if ($debug_pcode) {	foreach (@gen_Flags) { print STDERR "Flag=$_\n"; } }
	if ($debug_pcode) {	foreach (@gen_pCode) { print STDERR "$_\n"; } }
}
sub md5_gen_compile_Optimize2() {
}
sub md5_gen_compile_Optimize1() {
	# Look for 'salt as hash'  or 'salt as hash in salt2'
	# If ALL instances of $s are md5($s), then then we can use
	# 'salt as hash'.  If there are some md5($s), but some
	# extra $s's scattered in, and we do NOT have any $s2 then
	# we can use the 'salt as hash in salt2' optimization.
	my @positions; my $pos=0;
	while (1) {
		$pos = index($hash_format, 'md5($s)', $pos);
		last if($pos < 0);
		push(@positions, $pos++);
	}
	if (@positions) {
		# found at least 1 md5($s)
		# now, count number of $s's, and if same, then ALL $s's are in md5($s)
		my $count = 0;
		$pos = 0;
		while (1) {
			$pos = index($hash_format, '$s', $pos) + 1;
			last if($pos < 1);
			++$count;
		}
		if ($count == @positions) {
			my $from = quotemeta 'md5($s)'; my $to = '$s';
			$gen_stype = "tohex";
			push (@gen_Flags, "MGF_SALT_AS_HEX");
			if ($debug_pcode == 1) {
				print STDERR "Performing Optimization(Salt_as_hex). Changing format from\n";
				print STDERR "$hash_format\n";
			}
			$hash_format =~ s/$from/$to/g;
			if ($debug_pcode == 1) { print STDERR "to\n$hash_format\n"; }
		}
		else {
			# we still 'might' be able to optimize.  if there is no $s2, then
			# we can still have a salt, and use salt2 as our md5($s) preload.
			if (index($hash_format, '$s2') < 0) {
				$gen_stype = "toS2hex";
				$gen_needs2 = 1;
				my $from = quotemeta 'md5($s)'; my $to = '$s2';
				push (@gen_Flags, "MGF_SALT_AS_HEX_TO_SALT2");
				if ($debug_pcode == 1) {
					print STDERR "Performing Optimization(Salt_as_hex_to_salt2). Changing format from\n";
					print STDERR "$hash_format\n";
				}
				$hash_format =~ s/$from/$to/g;
				if ($debug_pcode == 1) { print STDERR "to\n$hash_format\n"; }
			}
		}
	}
}
sub md5_gen_compile_expression_to_pcode {
	#
	# very crappy, recursive decent parser, but 'it works', lol.
	#
	# Now, same parser, but converted into a pcode generator
	# which were very simple changes, using a stack.
	#
	my $cur = $_[0];
	my $curend = $_[1];
	my $curTok;
 
	# we 'assume' it is likely that we have ( and ) wrapping the expr. We trim them off, and ignore them.
	if ($gen_toks[$cur] eq "(" && $gen_toks[$curend] eq ")") { ++$cur; --$curend; }
 
	while ($cur <= $curend) {
		$curTok = $gen_toks[$cur];
		if ($curTok eq ".") {
			# in this expression builder, we totally ignore these.
			++$cur;
			next;
		}
		if (length($curTok) > 1 && substr($curTok,0,1) eq "f")
		{
			# find the closing ')' for this md5.
			my $tail; my $count=1;
			++$cur;
			$tail = $cur;
			while ($count) {
				++$tail;
				if ($gen_toks[$tail] eq "(") {++$count;}
				elsif ($gen_toks[$tail] eq ")") {--$count;}
			}
 
			# OUTPUT CODE  Doing 'some'   md5($value) call   First, push a 'new' var'.  Build it, then perform the crypt
			push(@gen_pCode, "md5_gen_push");
 
			# recursion.
			my $cp = md5_gen_compile_expression_to_pcode($cur,$tail);
			$cur = $tail+1;
 
			# OUTPUT CODE  Now perform the 'correct' crypt.   This will do:
			#   1.  Pop the stack
			#   2. Perform crypt,
			#   3. Perform optional work (like up case, appending '=' chars, etc)
			#   4. Append the computed (and possibly tweaked) hash string to the last string in the stack.
			#   5. return the string.
			push(@gen_pCode, "md5_gen_".$curTok);
			next;
		}
		if ($curTok eq "s") {
			# salt could be 'normal' or might be the md5 hex of the salt
			# OUTPUT CODE
			if ($gen_stype eq "tohex") { push(@gen_pCode, "md5_gen_app_sh"); }
			else { push(@gen_pCode, "md5_gen_app_s"); }
			++$cur;
			$gen_needs = 1;
			next;
		}
		if ($curTok eq "p") { push(@gen_pCode, "md5_gen_app_p" . $gen_PWCase); ++$cur; next; }
		if ($curTok eq "S") { push(@gen_pCode, "md5_gen_app_S"); ++$cur; $gen_needs2 = 1; next; }
		if ($curTok eq "u") { push(@gen_pCode, "md5_gen_app_u"); ++$cur; $gen_needu = 1; next; }
 		if ($curTok eq "1") { push(@gen_pCode, "md5_gen_app_1"); ++$cur; next; }
		if ($curTok eq "2") { push(@gen_pCode, "md5_gen_app_2"); ++$cur; next; }
		if ($curTok eq "3") { push(@gen_pCode, "md5_gen_app_3"); ++$cur; next; }
		if ($curTok eq "4") { push(@gen_pCode, "md5_gen_app_4"); ++$cur; next; }
		if ($curTok eq "5") { push(@gen_pCode, "md5_gen_app_5"); ++$cur; next; }
		if ($curTok eq "6") { push(@gen_pCode, "md5_gen_app_6"); ++$cur; next; }
		if ($curTok eq "7") { push(@gen_pCode, "md5_gen_app_7"); ++$cur; next; }
		if ($curTok eq "8") { push(@gen_pCode, "md5_gen_app_8"); ++$cur; next; }
		if ($curTok eq "9") { push(@gen_pCode, "md5_gen_app_9"); ++$cur; next; }
 
		print "Error, invalid, can NOT create this expression (trying to build sample test buffer\n";
		die;
	}
}
sub md5_gen_run_compiled_pcode {
	######################################
	# now, RUN the expression, to generate our final hash.
	######################################
 
	if ($gen_needu == 1) { md5_gen_load_username(); }
	if ($gen_needs == 1) { md5_gen_load_salt(); if ($gen_singlesalt==1) {$gen_needs=2;} }
	if ($gen_needs2 == 1) { md5_gen_load_salt2(); if ($gen_singlesalt==1) {$gen_needs=2;} }
 
	if ($md5_gen_passType eq "uni") { $gen_pw = encode("UTF-16LE",$_[0]); }
	else { $gen_pw = $_[0]; }
	@gen_Stack = ();
	# we have to 'preload' this, since the md5() pops, then modifies top element, then returns string.
	# Thus, for the 'last' modification, we need a dummy var there.
	push(@gen_Stack,"");
	foreach my $fn (@gen_pCode) {
		no strict 'refs';
		$h = &$fn();
		use strict;
	}
	if ($gen_needu == 1) { print "$gen_u:md5_gen($gen_num)$h"; }
	else { print "u$u-md5gen($gen_num):md5_gen($gen_num)$h"; }
	if ($gen_needs > 0) { print "\$$gen_soutput"; }
	if ($gen_needs2 > 0) { if (!defined($gen_stype) || $gen_stype ne "toS2hex") {print "\$\$2$gen_s2";} }
	print ":$u:0:$_[0]::\n";
	return $h;  # might as well return the value.
}
sub md5_gen_load_username {
	# load user name
	my @gen_userNames = randusername();
	if (defined($md5_gen_usernameType)) {
		if ($md5_gen_usernameType eq "lc") { $gen_u = lc $gen_u; }
		elsif ($md5_gen_usernameType eq "uc") { $gen_u = uc $gen_u; }
		elsif ($md5_gen_usernameType eq "uni") { $gen_u = encode("UTF-16LE",$gen_u); }
	}
}
sub md5_gen_load_salt {
	if (defined $argsalt) {
		if ($gen_stype eq "ashex") { $gen_s=md5_hex($argsalt); }
		else { $gen_s=$argsalt; }
		$gen_soutput = $gen_s;
		$saltlen = $gen_s.length();
		if ($gen_stype eq "tohex") { $gen_s=md5_hex($gen_s); }
	} else {
		if ($gen_stype eq "ashex") { $gen_s=randstr(32, \@chrHexLo); }
		else { $gen_s=randstr($saltlen); }
		$gen_soutput = $gen_s;
		if ($gen_stype eq "tohex") { $gen_s=md5_hex($gen_s); }
	}
}
sub md5_gen_load_salt2() {
	if (defined($gen_stype) && $gen_stype eq "toS2hex") { $gen_s2 = md5_hex($gen_s);  }
	else { $gen_s2 = randstr($salt2len); }
}
##########################################################################
#  Here are the ACTUAL pCode primative functions.  These handle pretty
# much everything dealing with hashing expressions for md5/md4/sha1. There
# are some variables which will be properly prepared prior to any of these
# pCode functions.  These are $gen_pw (the password, possibly in unicode
# format).  $gen_s (the salt), $gen_s2 (the 2nd salt), $gen_u the username
# (possibly in unicode), and @gen_c (array of constants).  Also, prior to
# running against a number, the @gen_Stack is cleaned (but a blank variable
# is pushed to preload it).  To perform this function  md5(md5($p.$s).$p)
# here is the code that WILL be run:
# md5_gen_push
# md5_gen_push
# md5_gen_app_p
# md5_gen_app_s
# md5_gen_f5h
# md5_gen_app_p
# md5_gen_f5h
##########################################################################
sub md5_gen_push   { push @gen_Stack,""; }
sub md5_gen_pop    { return pop @gen_Stack; }  # not really needed.
sub md5_gen_app_s  { $gen_Stack[@gen_Stack-1] .= $gen_s; }
sub md5_gen_app_sh { $gen_Stack[@gen_Stack-1] .= $gen_s; } #md5_hex($gen_s); }
sub md5_gen_app_S  { $gen_Stack[@gen_Stack-1] .= $gen_s2; }
sub md5_gen_app_u  { $gen_Stack[@gen_Stack-1] .= $gen_u; }
sub md5_gen_app_p  { $gen_Stack[@gen_Stack-1] .= $gen_pw; }
sub md5_gen_app_pU { $gen_Stack[@gen_Stack-1] .= uc $gen_pw; }
sub md5_gen_app_pL { $gen_Stack[@gen_Stack-1] .= lc $gen_pw; }
sub md5_gen_app_1  { $gen_Stack[@gen_Stack-1] .= $gen_c[0]; }
sub md5_gen_app_2  { $gen_Stack[@gen_Stack-1] .= $gen_c[1]; }
sub md5_gen_app_3  { $gen_Stack[@gen_Stack-1] .= $gen_c[2]; }
sub md5_gen_app_4  { $gen_Stack[@gen_Stack-1] .= $gen_c[3]; }
sub md5_gen_app_5  { $gen_Stack[@gen_Stack-1] .= $gen_c[4]; }
sub md5_gen_app_6  { $gen_Stack[@gen_Stack-1] .= $gen_c[5]; }
sub md5_gen_app_7  { $gen_Stack[@gen_Stack-1] .= $gen_c[6]; }
sub md5_gen_app_8  { $gen_Stack[@gen_Stack-1] .= $gen_c[7]; }
sub md5_gen_app_9  { $gen_Stack[@gen_Stack-1] .= $gen_c[8]; }
sub md5_gen_f5h    { $h = pop @gen_Stack; $h = md5_hex($h);  $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f1h    { $h = pop @gen_Stack; $h = sha1_hex($h); $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f4h    { $h = pop @gen_Stack; $h = md4_hex($h);  $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f5H    { $h = pop @gen_Stack; $h = uc md5_hex($h);	 $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f1H    { $h = pop @gen_Stack; $h = uc sha1_hex($h); $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f4H    { $h = pop @gen_Stack; $h = uc md4_hex($h);  $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f56    { $h = pop @gen_Stack; $h = md5_base64($h);	 $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f16    { $h = pop @gen_Stack; $h = sha1_base64($h); $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f46    { $h = pop @gen_Stack; $h = md4_base64($h);  $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f5e    { $h = pop @gen_Stack; $h = md5_base64($h);  while (length($h)%4) { $h .= "="; } $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f1e    { $h = pop @gen_Stack; $h = sha1_base64($h); while (length($h)%4) { $h .= "="; } $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f4e    { $h = pop @gen_Stack; $h = md4_base64($h);  while (length($h)%4) { $h .= "="; } $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f5r    { $h = pop @gen_Stack; $h = md5($h);  $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f1r    { $h = pop @gen_Stack; $h = sha1($h); $gen_Stack[@gen_Stack-1] .= $h; return $h; }
sub md5_gen_f4r    { $h = pop @gen_Stack; $h = md4($h);  $gen_Stack[@gen_Stack-1] .= $h; return $h; }
