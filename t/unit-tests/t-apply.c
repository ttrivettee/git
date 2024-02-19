#include "test-lib.h"
#include "apply.h"

#define FAILURE -1

static void setup_static(const char *line, int len, int offset,
						 const char *expect, int assert_result,
						 unsigned long assert_p1,
						 unsigned long assert_p2)
{
	unsigned long p1 = 9999;
	unsigned long p2 = 9999;
	int result = parse_fragment_range(line, len, offset, expect, &p1, &p2);
	check_int(result, ==, assert_result);
	check_int(p1, ==, assert_p1);
	check_int(p2, ==, assert_p2);
}

int cmd_main(int argc, const char **argv)
{
	char* text;
	int expected_result;

	/* Success */
	text = "@@ -4,4 +";
	expected_result = 9;
	TEST(setup_static(text, strlen(text), 4, " +", expected_result, 4, 4),
		 "well-formed range");

	text = "@@ -4 +8 @@";
	expected_result = 7;
	TEST(setup_static(text, strlen(text), 4, " +", expected_result, 4, 1),
		 "non-comma range");

	/* Failure */
	text = "@@ -X,4 +";
	expected_result = FAILURE;
	TEST(setup_static(text, strlen(text), 4, " +", expected_result, 9999, 9999),
		 "non-digit range (first coordinate)");

	text = "@@ -4,X +";
	expected_result = FAILURE;
	TEST(setup_static(text, strlen(text), 4, " +", expected_result, 4, 1), // p2 is 1, a little strange but not catastrophic
		 "non-digit range (second coordinate)");

	text = "@@ -4,4 -";
	expected_result = FAILURE;
	TEST(setup_static(text, strlen(text), 4, " +", expected_result, 4, 4),
		 "non-expected trailing text");

	text = "@@ -4,4";
	expected_result = FAILURE;
	TEST(setup_static(text, strlen(text), 4, " +", expected_result, 4, 4),
		 "not long enough for expected trailing text");

	text = "@@ -4,4";
	expected_result = FAILURE;
	TEST(setup_static(text, strlen(text), 7, " +", expected_result, 9999, 9999),
		 "not long enough for offset");

	text = "@@ -4,4";
	expected_result = FAILURE;
	TEST(setup_static(text, strlen(text), -1, " +", expected_result, 9999, 9999),
		 "negative offset");

	return test_done();
}
