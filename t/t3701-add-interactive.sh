if test_have_prereq !PERL
test_expect_success 'warn about add.interactive.useBuiltin' '
	cat >expect <<-\EOF &&
	warning: the add.interactive.useBuiltin setting has been removed!
	See its entry in '\''git help config'\'' for details.
	No changes.
	EOF

	for v in = =true =false
	do
		git -c "add.interactive.useBuiltin$v" add -p >out 2>actual &&
		test_must_be_empty out &&
		test_cmp expect actual || return 1
	done
'

test_expect_success 'split hunk "add -p (no, yes, edit)"' '
test_expect_success 'edit, adding lines to the first hunk' '