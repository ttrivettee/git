#!/bin/sh

test_description='Test reffiles backend'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Test adding and deleting D/F-conflicting references in a single
# transaction.
df_test() {
	prefix="$1"
	pack=: symadd=false symdel=false add_del=false addref= delref=
	shift
	while test $# -gt 0
	do
		case "$1" in
		--pack)
			pack="git pack-refs --all"
			shift
			;;
		--sym-add)
			# Perform the add via a symbolic reference
			symadd=true
			shift
			;;
		--sym-del)
			# Perform the del via a symbolic reference
			symdel=true
			shift
			;;
		--del-add)
			# Delete first reference then add second
			add_del=false
			delref="$prefix/r/$2"
			addref="$prefix/r/$3"
			shift 3
			;;
		--add-del)
			# Add first reference then delete second
			add_del=true
			addref="$prefix/r/$2"
			delref="$prefix/r/$3"
			shift 3
			;;
		*)
			echo 1>&2 "Extra args to df_test: $*"
			return 1
			;;
		esac
	done
	git update-ref "$delref" $C &&
	if $symadd
	then
		addname="$prefix/s/symadd" &&
		git symbolic-ref "$addname" "$addref"
	else
		addname="$addref"
	fi &&
	if $symdel
	then
		delname="$prefix/s/symdel" &&
		git symbolic-ref "$delname" "$delref"
	else
		delname="$delref"
	fi &&
	cat >expected-err <<-EOF &&
	fatal: cannot lock ref $SQ$addname$SQ: $SQ$delref$SQ exists; cannot create $SQ$addref$SQ
	EOF
	$pack &&
	if $add_del
	then
		printf "%s\n" "create $addname $D" "delete $delname"
	else
		printf "%s\n" "delete $delname" "create $addname $D"
	fi >commands &&
	test_must_fail git update-ref --stdin <commands 2>output.err &&
	test_cmp expected-err output.err &&
	printf "%s\n" "$C $delref" >expected-refs &&
	git for-each-ref --format="%(objectname) %(refname)" $prefix/r >actual-refs &&
	test_cmp expected-refs actual-refs
}

test_expect_success 'setup' '
	git commit --allow-empty -m Initial &&
	C=$(git rev-parse HEAD) &&
	git commit --allow-empty -m Second &&
	D=$(git rev-parse HEAD) &&
	git commit --allow-empty -m Third &&
	E=$(git rev-parse HEAD)
'

test_expect_success 'pack_refs(PACK_REFS_ALL | PACK_REFS_PRUNE)' '
	N=`find .git/refs -type f | wc -l` &&
	test "$N" != 0 &&
	test-tool ref-store main pack-refs PACK_REFS_PRUNE,PACK_REFS_ALL &&
	N=`find .git/refs -type f` &&
	test -z "$N"
'

test_expect_success 'empty directory should not fool rev-parse' '
	prefix=refs/e-rev-parse &&
	git update-ref $prefix/foo $C &&
	git pack-refs --all &&
	mkdir -p .git/$prefix/foo/bar/baz &&
	echo "$C" >expected &&
	git rev-parse $prefix/foo >actual &&
	test_cmp expected actual
'

test_expect_success 'empty directory should not fool for-each-ref' '
	prefix=refs/e-for-each-ref &&
	git update-ref $prefix/foo $C &&
	git for-each-ref $prefix >expected &&
	git pack-refs --all &&
	mkdir -p .git/$prefix/foo/bar/baz &&
	git for-each-ref $prefix >actual &&
	test_cmp expected actual
'

test_expect_success 'empty directory should not fool create' '
	prefix=refs/e-create &&
	mkdir -p .git/$prefix/foo/bar/baz &&
	printf "create %s $C\n" $prefix/foo |
	git update-ref --stdin
'

test_expect_success 'empty directory should not fool verify' '
	prefix=refs/e-verify &&
	git update-ref $prefix/foo $C &&
	git pack-refs --all &&
	mkdir -p .git/$prefix/foo/bar/baz &&
	printf "verify %s $C\n" $prefix/foo |
	git update-ref --stdin
'

test_expect_success 'empty directory should not fool 1-arg update' '
	prefix=refs/e-update-1 &&
	git update-ref $prefix/foo $C &&
	git pack-refs --all &&
	mkdir -p .git/$prefix/foo/bar/baz &&
	printf "update %s $D\n" $prefix/foo |
	git update-ref --stdin
'

test_expect_success 'empty directory should not fool 2-arg update' '
	prefix=refs/e-update-2 &&
	git update-ref $prefix/foo $C &&
	git pack-refs --all &&
	mkdir -p .git/$prefix/foo/bar/baz &&
	printf "update %s $D $C\n" $prefix/foo |
	git update-ref --stdin
'

test_expect_success 'empty directory should not fool 0-arg delete' '
	prefix=refs/e-delete-0 &&
	git update-ref $prefix/foo $C &&
	git pack-refs --all &&
	mkdir -p .git/$prefix/foo/bar/baz &&
	printf "delete %s\n" $prefix/foo |
	git update-ref --stdin
'

test_expect_success 'empty directory should not fool 1-arg delete' '
	prefix=refs/e-delete-1 &&
	git update-ref $prefix/foo $C &&
	git pack-refs --all &&
	mkdir -p .git/$prefix/foo/bar/baz &&
	printf "delete %s $C\n" $prefix/foo |
	git update-ref --stdin
'

test_expect_success 'D/F conflict prevents add long + delete short' '
	df_test refs/df-al-ds --add-del foo/bar foo
'

test_expect_success 'D/F conflict prevents add short + delete long' '
	df_test refs/df-as-dl --add-del foo foo/bar
'

test_expect_success 'D/F conflict prevents delete long + add short' '
	df_test refs/df-dl-as --del-add foo/bar foo
'

test_expect_success 'D/F conflict prevents delete short + add long' '
	df_test refs/df-ds-al --del-add foo foo/bar
'

test_expect_success 'D/F conflict prevents add long + delete short packed' '
	df_test refs/df-al-dsp --pack --add-del foo/bar foo
'

test_expect_success 'D/F conflict prevents add short + delete long packed' '
	df_test refs/df-as-dlp --pack --add-del foo foo/bar
'

test_expect_success 'D/F conflict prevents delete long packed + add short' '
	df_test refs/df-dlp-as --pack --del-add foo/bar foo
'

test_expect_success 'D/F conflict prevents delete short packed + add long' '
	df_test refs/df-dsp-al --pack --del-add foo foo/bar
'

# Try some combinations involving symbolic refs...

test_expect_success 'D/F conflict prevents indirect add long + delete short' '
	df_test refs/df-ial-ds --sym-add --add-del foo/bar foo
'

test_expect_success 'D/F conflict prevents indirect add long + indirect delete short' '
	df_test refs/df-ial-ids --sym-add --sym-del --add-del foo/bar foo
'

test_expect_success 'D/F conflict prevents indirect add short + indirect delete long' '
	df_test refs/df-ias-idl --sym-add --sym-del --add-del foo foo/bar
'

test_expect_success 'D/F conflict prevents indirect delete long + indirect add short' '
	df_test refs/df-idl-ias --sym-add --sym-del --del-add foo/bar foo
'

test_expect_success 'D/F conflict prevents indirect add long + delete short packed' '
	df_test refs/df-ial-dsp --sym-add --pack --add-del foo/bar foo
'

test_expect_success 'D/F conflict prevents indirect add long + indirect delete short packed' '
	df_test refs/df-ial-idsp --sym-add --sym-del --pack --add-del foo/bar foo
'

test_expect_success 'D/F conflict prevents add long + indirect delete short packed' '
	df_test refs/df-al-idsp --sym-del --pack --add-del foo/bar foo
'

test_expect_success 'D/F conflict prevents indirect delete long packed + indirect add short' '
	df_test refs/df-idlp-ias --sym-add --sym-del --pack --del-add foo/bar foo
'

test_expect_success 'non-empty directory blocks create' '
	prefix=refs/ne-create &&
	mkdir -p .git/$prefix/foo/bar &&
	: >.git/$prefix/foo/bar/baz.lock &&
	test_when_finished "rm -f .git/$prefix/foo/bar/baz.lock" &&
	cat >expected <<-EOF &&
	fatal: cannot lock ref $SQ$prefix/foo$SQ: there is a non-empty directory $SQ.git/$prefix/foo$SQ blocking reference $SQ$prefix/foo$SQ
	EOF
	printf "%s\n" "update $prefix/foo $C" |
	test_must_fail git update-ref --stdin 2>output.err &&
	test_cmp expected output.err &&
	cat >expected <<-EOF &&
	fatal: cannot lock ref $SQ$prefix/foo$SQ: unable to resolve reference $SQ$prefix/foo$SQ
	EOF
	printf "%s\n" "update $prefix/foo $D $C" |
	test_must_fail git update-ref --stdin 2>output.err &&
	test_cmp expected output.err
'

test_expect_success 'broken reference blocks create' '
	prefix=refs/broken-create &&
	mkdir -p .git/$prefix &&
	echo "gobbledigook" >.git/$prefix/foo &&
	test_when_finished "rm -f .git/$prefix/foo" &&
	cat >expected <<-EOF &&
	fatal: cannot lock ref $SQ$prefix/foo$SQ: unable to resolve reference $SQ$prefix/foo$SQ: reference broken
	EOF
	printf "%s\n" "update $prefix/foo $C" |
	test_must_fail git update-ref --stdin 2>output.err &&
	test_cmp expected output.err &&
	cat >expected <<-EOF &&
	fatal: cannot lock ref $SQ$prefix/foo$SQ: unable to resolve reference $SQ$prefix/foo$SQ: reference broken
	EOF
	printf "%s\n" "update $prefix/foo $D $C" |
	test_must_fail git update-ref --stdin 2>output.err &&
	test_cmp expected output.err
'

test_expect_success 'non-empty directory blocks indirect create' '
	prefix=refs/ne-indirect-create &&
	git symbolic-ref $prefix/symref $prefix/foo &&
	mkdir -p .git/$prefix/foo/bar &&
	: >.git/$prefix/foo/bar/baz.lock &&
	test_when_finished "rm -f .git/$prefix/foo/bar/baz.lock" &&
	cat >expected <<-EOF &&
	fatal: cannot lock ref $SQ$prefix/symref$SQ: there is a non-empty directory $SQ.git/$prefix/foo$SQ blocking reference $SQ$prefix/foo$SQ
	EOF
	printf "%s\n" "update $prefix/symref $C" |
	test_must_fail git update-ref --stdin 2>output.err &&
	test_cmp expected output.err &&
	cat >expected <<-EOF &&
	fatal: cannot lock ref $SQ$prefix/symref$SQ: unable to resolve reference $SQ$prefix/foo$SQ
	EOF
	printf "%s\n" "update $prefix/symref $D $C" |
	test_must_fail git update-ref --stdin 2>output.err &&
	test_cmp expected output.err
'

test_expect_success 'broken reference blocks indirect create' '
	prefix=refs/broken-indirect-create &&
	git symbolic-ref $prefix/symref $prefix/foo &&
	echo "gobbledigook" >.git/$prefix/foo &&
	test_when_finished "rm -f .git/$prefix/foo" &&
	cat >expected <<-EOF &&
	fatal: cannot lock ref $SQ$prefix/symref$SQ: unable to resolve reference $SQ$prefix/foo$SQ: reference broken
	EOF
	printf "%s\n" "update $prefix/symref $C" |
	test_must_fail git update-ref --stdin 2>output.err &&
	test_cmp expected output.err &&
	cat >expected <<-EOF &&
	fatal: cannot lock ref $SQ$prefix/symref$SQ: unable to resolve reference $SQ$prefix/foo$SQ: reference broken
	EOF
	printf "%s\n" "update $prefix/symref $D $C" |
	test_must_fail git update-ref --stdin 2>output.err &&
	test_cmp expected output.err
'

test_expect_success 'no bogus intermediate values during delete' '
	prefix=refs/slow-transaction &&
	# Set up a reference with differing loose and packed versions:
	git update-ref $prefix/foo $C &&
	git pack-refs --all &&
	git update-ref $prefix/foo $D &&
	# Now try to update the reference, but hold the `packed-refs` lock
	# for a while to see what happens while the process is blocked:
	: >.git/packed-refs.lock &&
	test_when_finished "rm -f .git/packed-refs.lock" &&
	{
		# Note: the following command is intentionally run in the
		# background. We increase the timeout so that `update-ref`
		# attempts to acquire the `packed-refs` lock for much longer
		# than it takes for us to do the check then delete it:
		git -c core.packedrefstimeout=30000 update-ref -d $prefix/foo &
	} &&
	pid2=$! &&
	# Give update-ref plenty of time to get to the point where it tries
	# to lock packed-refs:
	sleep 1 &&
	# Make sure that update-ref did not complete despite the lock:
	kill -0 $pid2 &&
	# Verify that the reference still has its old value:
	sha1=$(git rev-parse --verify --quiet $prefix/foo || echo undefined) &&
	case "$sha1" in
	$D)
		# This is what we hope for; it means that nothing
		# user-visible has changed yet.
		: ;;
	undefined)
		# This is not correct; it means the deletion has happened
		# already even though update-ref should not have been
		# able to acquire the lock yet.
		echo "$prefix/foo deleted prematurely" &&
		break
		;;
	$C)
		# This value should never be seen. Probably the loose
		# reference has been deleted but the packed reference
		# is still there:
		echo "$prefix/foo incorrectly observed to be C" &&
		break
		;;
	*)
		# WTF?
		echo "unexpected value observed for $prefix/foo: $sha1" &&
		break
		;;
	esac >out &&
	rm -f .git/packed-refs.lock &&
	wait $pid2 &&
	test_must_be_empty out &&
	test_must_fail git rev-parse --verify --quiet $prefix/foo
'

test_expect_success 'delete fails cleanly if packed-refs file is locked' '
	prefix=refs/locked-packed-refs &&
	# Set up a reference with differing loose and packed versions:
	git update-ref $prefix/foo $C &&
	git pack-refs --all &&
	git update-ref $prefix/foo $D &&
	git for-each-ref $prefix >unchanged &&
	# Now try to delete it while the `packed-refs` lock is held:
	: >.git/packed-refs.lock &&
	test_when_finished "rm -f .git/packed-refs.lock" &&
	test_must_fail git update-ref -d $prefix/foo >out 2>err &&
	git for-each-ref $prefix >actual &&
	test_grep "Unable to create $SQ.*packed-refs.lock$SQ: " err &&
	test_cmp unchanged actual
'

test_expect_success 'delete fails cleanly if packed-refs.new write fails' '
	# Setup and expectations are similar to the test above.
	prefix=refs/failed-packed-refs &&
	git update-ref $prefix/foo $C &&
	git pack-refs --all &&
	git update-ref $prefix/foo $D &&
	git for-each-ref $prefix >unchanged &&
	# This should not happen in practice, but it is an easy way to get a
	# reliable error (we open with create_tempfile(), which uses O_EXCL).
	: >.git/packed-refs.new &&
	test_when_finished "rm -f .git/packed-refs.new" &&
	test_must_fail git update-ref -d $prefix/foo &&
	git for-each-ref $prefix >actual &&
	test_cmp unchanged actual
'

RWT="test-tool ref-store worktree:wt"
RMAIN="test-tool ref-store worktree:main"

test_expect_success 'setup worktree' '
	test_commit first &&
	git worktree add -b wt-main wt &&
	(
		cd wt &&
		test_commit second
	)
'

# Some refs (refs/bisect/*, pseudorefs) are kept per worktree, so they should
# only appear in the for-each-reflog output if it is called from the correct
# worktree, which is exercised in this test. This test is poorly written for
# mulitple reasons: 1) it creates invalidly formatted log entres. 2) it uses
# direct FS access for creating the reflogs. 3) PSEUDO-WT and refs/bisect/random
# do not create reflogs by default, so it is not testing a realistic scenario.
test_expect_success 'for_each_reflog()' '
	echo $ZERO_OID > .git/logs/PSEUDO-MAIN &&
	mkdir -p     .git/logs/refs/bisect &&
	echo $ZERO_OID > .git/logs/refs/bisect/random &&

	echo $ZERO_OID > .git/worktrees/wt/logs/PSEUDO-WT &&
	mkdir -p     .git/worktrees/wt/logs/refs/bisect &&
	echo $ZERO_OID > .git/worktrees/wt/logs/refs/bisect/wt-random &&

	$RWT for-each-reflog | cut -d" " -f 2- | sort >actual &&
	cat >expected <<-\EOF &&
	HEAD 0x1
	PSEUDO-WT 0x0
	refs/bisect/wt-random 0x0
	refs/heads/main 0x0
	refs/heads/wt-main 0x0
	EOF
	test_cmp expected actual &&

	$RMAIN for-each-reflog | cut -d" " -f 2- | sort >actual &&
	cat >expected <<-\EOF &&
	HEAD 0x1
	PSEUDO-MAIN 0x0
	refs/bisect/random 0x0
	refs/heads/main 0x0
	refs/heads/wt-main 0x0
	EOF
	test_cmp expected actual
'

# Triggering the bug detected by this test requires a newline to fall
# exactly BUFSIZ-1 bytes from the end of the file. We don't know
# what that value is, since it's platform dependent. However, if
# we choose some value N, we also catch any D which divides N evenly
# (since we will read backwards in chunks of D). So we choose 8K,
# which catches glibc (with an 8K BUFSIZ) and *BSD (1K).
#
# Each line is 114 characters, so we need 75 to still have a few before the
# last 8K. The 89-character padding on the final entry lines up our
# newline exactly.
test_expect_success SHA1 'parsing reverse reflogs at BUFSIZ boundaries' '
	git checkout -b reflogskip &&
	zf=$(test_oid zero_2) &&
	ident="abc <xyz> 0000000001 +0000" &&
	for i in $(test_seq 1 75); do
		printf "$zf%02d $zf%02d %s\t" $i $(($i+1)) "$ident" &&
		if test $i = 75; then
			for j in $(test_seq 1 89); do
				printf X || return 1
			done
		else
			printf X
		fi &&
		printf "\n" || return 1
	done >.git/logs/refs/heads/reflogskip &&
	git rev-parse reflogskip@{73} >actual &&
	echo ${zf}03 >expect &&
	test_cmp expect actual
'

# This test takes a lock on an individual ref; this is not supported in
# reftable.
test_expect_success 'reflog expire operates on symref not referrent' '
	git branch --create-reflog the_symref &&
	git branch --create-reflog referrent &&
	git update-ref referrent HEAD &&
	git symbolic-ref refs/heads/the_symref refs/heads/referrent &&
	test_when_finished "rm -f .git/refs/heads/referrent.lock" &&
	touch .git/refs/heads/referrent.lock &&
	git reflog expire --expire=all the_symref
'

test_expect_success 'empty reflog' '
	test_when_finished "rm -rf empty" &&
	git init empty &&
	test_commit -C empty A &&
	>empty/.git/logs/refs/heads/foo &&
	git -C empty reflog expire --all 2>err &&
	test_must_be_empty err
'

# The 'packed-refs' file is stored directly in .git/. This means it is global
# to the repository, and can only contain refs that are shared across all
# worktrees.
test_expect_success 'refs/worktree must not be packed' '
	test_commit initial &&
	test_commit wt1 &&
	test_commit wt2 &&
	git worktree add wt1 wt1 &&
	git worktree add wt2 wt2 &&
	git checkout initial &&
	git update-ref refs/worktree/foo HEAD &&
	git -C wt1 update-ref refs/worktree/foo HEAD &&
	git -C wt2 update-ref refs/worktree/foo HEAD &&
	git pack-refs --all &&
	test_path_is_missing .git/refs/tags/wt1 &&
	test_path_is_file .git/refs/worktree/foo &&
	test_path_is_file .git/worktrees/wt1/refs/worktree/foo &&
	test_path_is_file .git/worktrees/wt2/refs/worktree/foo
'

test_expect_success SYMLINKS 'ref resolution not confused by broken symlinks' '
       ln -s does-not-exist .git/refs/heads/broken &&
       test_must_fail git rev-parse --verify broken
'

test_expect_success 'drop stash reflog updates refs/stash with rewrite' '
	git init repo &&
	(
		cd repo &&
		setup_stash
	) &&
	echo 9 >repo/file &&

	old_oid="$(git -C repo rev-parse stash@{0})" &&
	git -C repo stash &&
	new_oid="$(git -C repo rev-parse stash@{0})" &&

	cat >expect <<-EOF &&
	$(test_oid zero) $old_oid
	$old_oid $new_oid
	EOF
	cut -d" " -f1-2 repo/.git/logs/refs/stash >actual &&
	test_cmp expect actual &&

	git -C repo stash drop stash@{1} &&
	cut -d" " -f1-2 repo/.git/logs/refs/stash >actual &&
	cat >expect <<-EOF &&
	$(test_oid zero) $new_oid
	EOF
	test_cmp expect actual
'

test_expect_success 'log diagnoses bogus HEAD hash' '
	git init empty &&
	test_when_finished "rm -rf empty" &&
	echo 1234abcd >empty/.git/refs/heads/main &&
	test_must_fail git -C empty log 2>stderr &&
	test_grep broken stderr
'

test_expect_success 'log diagnoses bogus HEAD symref' '
	git init empty &&
	test-tool -C empty ref-store main create-symref HEAD refs/heads/invalid.lock &&
	test_must_fail git -C empty log 2>stderr &&
	test_grep broken stderr &&
	test_must_fail git -C empty log --default totally-bogus 2>stderr &&
	test_grep broken stderr
'

# we do not want to count on running pack-refs to
# actually pack it, as it is perfectly reasonable to
# skip processing a broken ref
test_expect_success 'create packed-refs file with broken ref' '
	test_tick && git commit --allow-empty -m one &&
	recoverable=$(git rev-parse HEAD) &&
	test_tick && git commit --allow-empty -m two &&
	missing=$(git rev-parse HEAD) &&
	rm -f .git/refs/heads/main &&
	cat >.git/packed-refs <<-EOF &&
	$missing refs/heads/main
	$recoverable refs/heads/other
	EOF
	echo $missing >expect &&
	git rev-parse refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'pack-refs does not silently delete broken packed ref' '
	git pack-refs --all --prune &&
	git rev-parse refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success  'pack-refs does not drop broken refs during deletion' '
	git update-ref -d refs/heads/other &&
	git rev-parse refs/heads/main >actual &&
	test_cmp expect actual
'

test_done
