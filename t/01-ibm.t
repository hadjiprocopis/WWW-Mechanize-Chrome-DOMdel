#!/usr/bin/env perl

use strict;
use warnings;

use lib 'blib/lib';

use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use Test::More;

use File::Temp;
use Cwd;
use File::Basename;
use Log::Log4perl qw(:easy);

use WWW::Mechanize::Chrome;
use WWW::Mechanize::Chrome::DOMdel qw/remove_element_from_DOM VERBOSE_DOMdel/;

# verbosity can be 0, 1, 2, 3
$WWW::Mechanize::Chrome::DOMdel::VERBOSE_DOMdel = 0;
# the URL to get
my $URL = 'https://www.ibm.com/cy-en/?ar=1';
# then we look for some elements
# WARNING: HTML from URL may change so these tests may start failing at some point!

my ($element_type, $element_id, $element_classname);

# from https://perlmaven.com/logging-in-modules-with-log4perl-the-easy-way
if(not Log::Log4perl->initialized()){
	Log::Log4perl->easy_init(Log::Log4perl::Level::to_priority('ERROR'));
}

my %default_mech_params = (
	headless => 1,
#	log => $mylogger,
	launch_arg => [
		'--window-size=600x800',
		'--password-store=basic', # do not ask me for stupid chrome account password
#		'--remote-debugging-port=9223',
#		'--enable-logging', # see also log above
		'--disable-gpu',
		'--no-sandbox',
		'--ignore-certificate-errors',
		'--disable-background-networking',
		'--disable-client-side-phishing-detection',
		'--disable-component-update',
		'--disable-hang-monitor',
		'--disable-save-password-bubble',
		'--disable-default-apps',
		'--disable-infobars',
		'--disable-popup-blocking',
	],
);

my $mech_obj = WWW::Mechanize::Chrome->new(%default_mech_params);
BAIL_OUT("failed to create WWW::Mechanize::Chrome object") unless defined $mech_obj;

my $console = $mech_obj->add_listener('Runtime.consoleAPICalled', sub {
  warn join ", ",
      map { $_->{value} // $_->{description} }
      @{ $_[0]->{params}->{args} };
});

my $num_tests = 0;

BAIL_OUT("failed to get() url '$URL'") unless $mech_obj->get($URL);

$element_type = 'div';
$element_id = 'ibm-universal-nav';
my $ret = remove_element_from_DOM({
	# removes the top banner with the search and all
	'mech-obj' => $mech_obj,
	'element-id' => $element_id,
	'element-type' => $element_type,
	'&&' => 1, # intersection (which is the default)
});
is($ret, 1, "removed top banner/search box") or print "this test has failed possibly because the HTML of '$URL' has changed, we were looking for element-type='${element_type}', element-id='${element_id}'.\n"; $num_tests++;

$element_type = 'div';
$element_id = 'ibm-leadspace-head';
$element_classname = 'ibm-hidden-bg-small';
$ret = remove_element_from_DOM({
	'mech-obj' => $mech_obj,
	'element-type' => $element_type,
	'element-id' => $element_id,
	'element-classname' => $element_classname,
	'&&' => 1, # intersection (which is the default)
});
is($ret, 1, "background removal verified") or print "this test has failed possibly because the HTML of '$URL' has changed, we were looking for element-type='${element_type}', element-id='${element_id}' and element-classname='${element_classname}'.\n"; $num_tests++;

if(0){
# this needs scrolling down to put in the screenshot
# so forget it
sleep(2);
$mech_obj->infinite_scroll(1);
$mech_obj->infinite_scroll(1);
sleep(1);
$element_type = 'div';
$element_id = 'ibm-footer-module-links';
$element_classname = 'ibm-fluid ibm-word-break';
$ret = remove_element_from_DOM({
	'mech-obj' => $mech_obj,
	'element-type' => $element_type,
	'element-id' => $element_id,
	'element-classname' => $element_classname,
	'&&' => 1, # intersection (which is the default)
});
is($ret, 1, "removed footer verified") or print "this test has failed possibly because the HTML of '$URL' has changed, we were looking for element-type='${element_type}', element-id='${element_id}' and element-classname='${element_classname}'.\n"; $num_tests++;
}
my ($fh, $tmpfile) = File::Temp::tempfile(SUFFIX=>'.png');
take_a_screenshot($mech_obj, $fh);
print "check screenshot at '$tmpfile'\n";
close($fh);
ok(-s $tmpfile, "$tmpfile contains the screenshot") or BAIL_OUT("no screenshot was created, something seriously wrong."); $num_tests++;
unlink($tmpfile);

# ok now delete again the same we will get errors
$element_type = 'div';
$element_id = 'ibm-universal-nav';
$ret = remove_element_from_DOM({
	# removes the top banner with the search and all
	'mech-obj' => $mech_obj,
	'element-id' => $element_id,
	'element-type' => $element_type,
	'&&' => 1, # intersection (which is the default)
});
is($ret, -1, "top banner/search box removal verified") or print "this test has failed possibly because the HTML of '$URL' has changed, we were looking for element-type='${element_type}', element-id='${element_id}'.\n"; $num_tests++;

# now, after removing an element verify that it is not there (return -1)
$element_type = 'div';
$element_id = 'ibm-leadspace-head';
$element_classname = 'ibm-hidden-bg-small';
$ret = remove_element_from_DOM({
	'mech-obj' => $mech_obj,
	'element-type' => $element_type,
	'element-id' => $element_id,
	'element-classname' => $element_classname,
	'&&' => 1, # intersection (which is the default)
});
is($ret, -1, "background removal verified") or print "this test has failed possibly because the HTML of '$URL' has changed, we were looking for element-type='${element_type}', element-id='${element_id}' and element-classname='${element_classname}'.\n"; $num_tests++;

# END
done_testing($num_tests);

# from https://metacpan.org/pod/WWW::Mechanize::Chrome::Examples#Example:-url-to-image.pl
sub take_a_screenshot {
	my ($mech, $fh) = @_;
	my $page_png = $mech->content_as_png();
	binmode $fh, ':raw';
	print $fh $page_png;
};
