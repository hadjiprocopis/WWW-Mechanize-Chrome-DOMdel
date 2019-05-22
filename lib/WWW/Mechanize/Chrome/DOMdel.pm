package WWW::Mechanize::Chrome::DOMdel;

use 5.006;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(
	remove_element_from_DOM
	VERBOSE_DOMdel
);

use Try::Tiny;
 
our $VERSION = '0.01';

our $VERBOSE_DOMdel = 0;


# The input is a hashref of parameters
# the 'element-*' parameters specify some condition to be matched
# for example id to be such and such.
# The conditions can be combined either as a union (OR)
# or an intersection (AND). Default is intersection.
# The param || => 1 changes this to Union.
# 
# returns -2 if javascript failed
# returns -1 if one or more of the specified selectors failed to match
# returns >=0 : the number of elements deleted
sub remove_element_from_DOM {
	my $params = $_[0];
	my $amech_obj = $params->{'mech-obj'};

	my $element_name = $params->{'element-name'};
	my $element_classname = $params->{'element-classname'};
	my $element_type = $params->{'element-type'};
	my $element_id = $params->{'element-id'};
	# each specifier yields a list each, how to combine this list?
	# intersection (default) or union:
	my $Union = (defined $params->{'||'} && $params->{'||'} == 1) || (defined $params->{'&&'} && $params->{'&&'} == 0);

	if( ! $amech_obj ){ print STDERR 'remove_element_from_DOM()'." : a mech-object is required via 'mech-obj'.\n"; return 0 }
	if( ! defined $element_classname && ! defined $element_type && ! defined $element_id ){ print STDERR 'remove_element_from_DOM()'." : at least one of 'element-classname', 'element-type', 'element-name' and/or 'element-id' must be specified (or a combination).\n"; return 0 }
	if( $VERBOSE_DOMdel > 1 ){ print 'remove_element_from_DOM()'." : using ".($Union?'UNION':'INTERSECTION')." to combine the matched elements.\n"; }
	# there is no way to break a JS eval'ed via perl and return something back unless
	# one uses gotos or an anonymous function, see
	#    https://www.perlmonks.org/index.pl?node_id=1232479
	my $jsexec = <<'EOJ';
// the return value of this anonymous function is what perl's eval will get back
(function(){
	var retval = -1; // this is what we return
	// returns -1 for when one of the element searches matched nothing
	// returns 0 if after intersection/union nothing was found to delete
	// returns >0 : the number of elements deleted
	var anelem, anelems, i, j;
	var allfound = [];
	var elems = [];
	elems['byname'] = null;
	elems['byid'] = null; // only one but...
	elems['bytype'] = null;
	elems['byclassname'] = null;
EOJ
	if( defined $element_classname ){
		$jsexec .= "\t// an element classname was specified: '${element_classname}' ...\n";
		$jsexec .= "\t".'anelems = Array.prototype.slice.call(document.getElementsByClassName("'.$element_classname.'"));'."\n";
		$jsexec .= "\t".'if( anelems == null ){ console.log("remove_element_from_DOM() via js-eval : element(s) with classname \''.$element_classname.'\' not found, this specifier has failed and will not continue with the rest.\n"); return -1;}'."\n";
		$jsexec .= "\t".'if( anelems.length == 0 ){ console.log("remove_element_from_DOM() via js-eval : element(s) with classname \''.$element_classname.'\' not found, this specifier has matched nothing and will not continue with the rest.\n"); return -1;}'."\n";
		$jsexec .= "\t".'elems["byclassname"] = anelems;'."\n";
		$jsexec .= "\t".'allfound.push(anelems);'."\n";
		if( $VERBOSE_DOMdel > 1 ){
			$jsexec .= "\t".'console.log("remove_element_from_DOM() via js-eval : found "+elems["byclassname"].length+" elements with class-name \''.$element_classname.'\':\n");'."\n";
			if( $VERBOSE_DOMdel > 2 ){
				$jsexec .= "\t".'for(i=0;i<elems["byclassname"].length;i++){ console.dir(elems["byclassname"][i]); }'."\n";
				$jsexec .= "\t".'console.log("--- end of the elements found.\n");'."\n";
			}
		}
	}
	if( defined $element_type ){
		$jsexec .= "\t// an element type was specified: '${element_type}' ...\n";
		$jsexec .= "\t".'anelems = Array.prototype.slice.call(document.getElementsByTagName("'.$element_type.'"));'."\n";
		$jsexec .= "\t".'if( anelems == null ){ console.log("remove_element_from_DOM() via js-eval : element(s) with type \''.$element_type.'\' not found, this specifier has failed and will not continue with the rest.\n"); return -1;}'."\n";
		$jsexec .= "\t".'if( anelems.length == 0 ){ console.log("remove_element_from_DOM() via js-eval : element(s) with type \''.$element_type.'\' not found, this specifier has matched nothing and will not continue with the rest.\n"); return -1;}'."\n";
		$jsexec .= "\t".'elems["bytype"] = anelems;'."\n";
		$jsexec .= "\t".'allfound.push(anelems);'."\n";
		if( $VERBOSE_DOMdel > 1 ){
			$jsexec .= "\t".'console.log("remove_element_from_DOM() via js-eval : found "+elems["bytype"].length+" elements with element-type \''.$element_type.'\':\n");'."\n";
			if( $VERBOSE_DOMdel > 2 ){
				$jsexec .= "\t".'for(i=0;i<elems["bytype"].length;i++){ console.dir(elems["bytype"][i]); }'."\n";
				$jsexec .= "\t".'console.log("--- end of the elements found.\n");'."\n";
			}
		}
	}
	if( defined $element_name ){ # element name (not class-name)
		$jsexec .= "\t// an element name was specified: '${element_name}' ...\n";
		$jsexec .= "\t".'anelems = Array.prototype.slice.call(document.getElementsByName("'.$element_name.'"));'."\n";
		$jsexec .= "\t".'if( anelems == null ){ console.log("remove_element_from_DOM() via js-eval : element(s) with name \''.$element_name.'\' not found, this specifier has failed and will not continue with the rest.\n"); return -1;}'."\n";
		$jsexec .= "\t".'if( anelems.length == 0 ){ console.log("remove_element_from_DOM() via js-eval : element(s) with name \''.$element_name.'\' not found, this specifier has matched nothing and will not continue with the rest.\n"); return -1;}'."\n";
		$jsexec .= "\t".'elems["byname"] = anelems;'."\n";
		$jsexec .= "\t".'allfound.push(anelems);'."\n";
		if( $VERBOSE_DOMdel > 1 ){
			$jsexec .= "\t".'console.log("remove_element_from_DOM() via js-eval : found "+elems["byname"].length+" elements with name \''.$element_name.'\':\n");'."\n";
			if( $VERBOSE_DOMdel > 2 ){
				$jsexec .= "\t".'for(i=0;i<elems["byname"].length;i++){ console.dir(elems["byname"][i]); }'."\n";
				$jsexec .= "\t".'console.log("--- end of the elements found.\n");'."\n";
			}
		}
	}
	if( defined $element_id ){
		$jsexec .= "\t// an element id was specified: '${element_id}' ...\n";
		$jsexec .= "\t".'anelem = document.getElementById("'.$element_id.'");'."\n";
		$jsexec .= "\t".'if( anelem == null ){ console.log("remove_element_from_DOM() via js-eval : element with id \''.$element_id.'\' not found, this specifier has matched nothing and will not continue with the rest.\n"); return -1;}'."\n";
		$jsexec .= "\t".'elems["byid"] = [anelem];'."\n";
		$jsexec .= "\t".'allfound.push(anelem);'."\n";
		if( $VERBOSE_DOMdel > 1 ){
			$jsexec .= "\t".'console.log("remove_element_from_DOM() : found element with id '.$element_id.'.\n");'."\n";
			if( $VERBOSE_DOMdel > 2 ){
				$jsexec .= "\t".'for(i=0;i<elems["byid"].length;i++){ console.dir(elems["byid"][i]); }'."\n";
				$jsexec .= "\t".'console.log("--- end of the elements found.\n");'."\n";
			}
		}
	}
	# if even one specified has failed, we do not reach this point, it returns -1
	if( $Union ){
		# union of all elements matched individually without duplicates:
		# we just remove the duplicates from the allfound
		# from https://stackoverflow.com/questions/9229645/remove-duplicate-values-from-js-array (by Christian Landgren)
		$jsexec .= "\t// calculating the UNION of all elements found...\n";
		if( $VERBOSE_DOMdel > 1 ){ $jsexec .= "\t".'console.log("calculating the UNION of all elements found (without duplicates).\n");'."\n"; }
		$jsexec .= "\t".'allfound.slice().sort(function(a,b){return a > b}).reduce(function(a,b){if (a.slice(-1)[0] !== b) a.push(b);return a;},[]);'."\n";
	} else {
		# intersection of all the elements matched individually
		$jsexec .= "\t// calculating the INTERSECTION of all elements found...\n";
		if( $VERBOSE_DOMdel > 1 ){ $jsexec .= "\t".'console.log("calculating the INTERSECTION of all elements found per selector category (if any).\n");'."\n"; }
		$jsexec .= <<'EOJ';
	allfound = null;
	opts= ['byid','bytype','byclassname','byname']; var nopts = opts.length;
	var n1, n2;
	for(i=0;i<nopts;i++){
		n1 = opts[i];
		if( elems[n1] != null ){ allfound = elems[n1].slice(0); break; }
	}
	for(j=0;j<nopts;j++){
		if( j == i ) continue;
		n2 = opts[j];
		if( elems[n2] != null ){
			var array2 = elems[n2];
			// intersection of total and current
			allfound = allfound.filter(function(n) {
				return array2.indexOf(n) !== -1;
			});
		}
	}
EOJ
	} # if Union/Intersection

	$jsexec .= "\t".'var todel = allfound;'."\n";
	# will "return" this eventually and get it in $val of eval() below
	$jsexec .= "\t".'retval = todel.length;'."\n";
	if( $VERBOSE_DOMdel > 1 ){
		$jsexec .= "\t".'console.log("Will delete "+todel.length+" elements:\n");'."\n";
		if( $VERBOSE_DOMdel > 2 ){
			$jsexec .= "\t".'for(i=0;i<todel.length;i++){ console.log("---begin element to delete:\n"); console.dir(todel[i]); console.log("---end element to delete\n\n"); }'."\n";
		}
	}
	$jsexec .= "\t".'for(i=0;i<todel.length;i++){ if( todel[i] != null ){ todel[i].parentNode.removeChild(todel[i]); } }'."\n";
	if( $VERBOSE_DOMdel > 1 ){ $jsexec .= "\t".'console.log("remove_element_from_DOM() via js-eval : done removed "+todel.length+" elements from the DOM.\n");'."\n"; }
	$jsexec .= "\t".'return retval;'."\n})(); // end of function\n";
	# this is the end of the anonymous function
	# its retval will be what the perl eval will get back

	if( $VERBOSE_DOMdel > 2 ){ print 'remove_element_from_DOM()'." : evaluating the following javascript:\n".$jsexec."\n--- end javascript.\n"; }
	my ($retval, $typ);
	try {
		($retval, $typ) = $amech_obj->eval($jsexec);
	} catch {
		print STDERR 'remove_element_from_DOM()'." : eval failed: $_\n";
		return -2;
	};
	if( ! defined $retval ){ print STDERR 'remove_element_from_DOM()'." : eval of:\n $jsexec\nhas failed.\n"; return -2 }

	return $retval; # success
}

## POD starts here

=head1 NAME

WWW::Mechanize::Chrome::DOMdel - delete an element from the DOM

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Deletes one or more elements from the DOM which is
currently loaded on a L<WWW::Mechanize::Chrome> object,
matched by one of the following specifiers or a combination:

=over 4

=item * Element class name (as in C<E<lt>div class='a-class-name' ...E<gt>>).

=item * Element type (as in C<E<lt>div ...E<gt>>, i.e. all the I<div> elements).

=item * Element name (as in C<E<lt>input type='checkbox' name='aname' ...E<gt>>), only for some HTML constructs (form etc.)

=item * Element id (as in C<E<lt>div id='an-element-id' ...E<gt>>). NOTE: this
        matches only one item.

=back

If a combination of the above specifiers is used, then the resultant
set can be either an intersection or a union by using the parameter
C<|| =E<gt> 1>

Here are some usage scenaria:

    use WWW::Mechanize::Chrome::DOMdel qw/remove_element_from_DOM/;

    my $mechobj = WWW::Mechanize::Chrome->new();
    $mechobj->get('https://www.xyz.com');

    # remove from the DOM just fetched these elements:
    my $ret = remove_element_from_DOM({
       'mech-obj' => $mechobj,
       # remove all elements whose classname is this:
       'element-classname' => 'slanted-paragraph',
       # *OR* their type is this:
       'element-type' => 'p',
       # specifies that we should use the union of the above sets
       || => 1
       # this says to remove all elements whose classname
       # is such-and-such AND element type is such-and-such
       # || => 0 # this is the default mode btw
    });
    # or specify an element id
    $ret = remove_element_from_DOM({
       'mech-obj' => $mechobj,
       'element-id' => 'paragraph-123'
    });
    # check if success
    if( $ret > 0 ){ print "success, $ret elements deleted.\n" }
    elsif( $ret == 0 ){ print "no element was matched with your criteria.\n" }
    elsif( $ret == -1 ){ print "one of your specifiers has failed.\n" }
    else { print "something is very wrong: javascript has failed.\n" }

=head1 EXPORT

the sub to remove an element from the DOM

    remove_element_from_DOM()

and the flag to denote verbosity (default is 0, no verbosity)

    $VERBOSE_DOMdel


=head1 SUBROUTINES/METHODS


=head2 remove_element_from_DOM($params)

It removes an element from the DOM currently loaded on the
parameters-specified L<WWW::Mechanize::Chrome> object. The params
are:

=over 4

=item * C<mech-obj> : supply a L<WWW::Mechanize::Chrome>, required

=item * C<class-name> : delete all DOM elements matching this class name

=item * C<element-type> : delete all DOM elements matching this element type

=item * C<element-id> : delete the DOM element matching this element id

=back

One of the last 3 parameters is required. The combination of C<element-type>
and C<class-name> is also valid and the resulting set will be
calculated using either a union (OR) or an intersection (AND).
Intersection (AND) is the default mode.

To change to the union (OR) mode use the parameter

    || => 1

Note: the union/intersection applies to the first two element selectors.
It does not apply to C<element-id>, which is theoretically, unique
in the DOM.

Here is an example:

    use WWW::Mechanize::Chrome::DOMdel qw/remove_element_from_DOM/;

    my $mechobj = WWW::Mechanize::Chrome->new();
    $mechobj->get('https://www.xyz.com');

    # remove from the DOM just fetched these elements:
    my $ret = remove_element_from_DOM({
       'mech-obj' => $mechobj,
       # remove all elements whose classname is this:
       'element-classname' => 'slanted-paragraph',
       # *OR* their type is this:
       'element-type' => 'p',
       # specifies that we should use the union of the above sets
       || => 1
       # this says to remove all elements whose classname
       # is such-and-such AND element type is such-and-such
       # || => 0 # this is the default mode btw
    });


B<RETURN VALUE>:

=over 4

=item * -2 if javascript to remove the element(s) has failed

=item * -1 if one or more of the specified selectors did not match, for
	example no element matched the specified element-type. However,
	other selectors (if specified) may have matched something.

=item * the number of elements deleted which can be zero or more, success.

=back


=head1 AUTHOR

Andreas Hadjiprocopis, C<< <bliako at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-mechanize-chrome-domdel at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Mechanize-Chrome-DOMdel>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Mechanize::Chrome::DOMdel


You can also look for information at:

=over 4

=item * L<WWW::Mechanize::Chrome>

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Mechanize-Chrome-DOMdel>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Mechanize-Chrome-DOMdel>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/WWW-Mechanize-Chrome-DOMdel>

=item * Search CPAN

L<https://metacpan.org/release/WWW-Mechanize-Chrome-DOMdel>

=back

=head1 DEDICATIONS

Almaz


=head1 ACKNOWLEDGEMENTS

L<CORION> for publishing  L<WWW::Mechanize::Chrome>


=head1 LICENSE AND COPYRIGHT

Copyright 2019 Andreas Hadjiprocopis.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of WWW::Mechanize::Chrome::DOMdel
