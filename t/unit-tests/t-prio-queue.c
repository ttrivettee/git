#include "test-lib.h"
#include "prio-queue.h"

static int intcmp(const void *va, const void *vb, void *data UNUSED)
{
	const int *a = va, *b = vb;
	return *a - *b;
}


#define MISSING  -1
#define DUMP	 -2
#define STACK	 -3
#define GET	 -4
#define REVERSE  -5

static int show(int *v)
{
	return v ? *v : MISSING;
}

static int test_prio_queue(int *input, int *result)
{
	struct prio_queue pq = { intcmp };
	int i = 0;

	while (*input) {
		int *val = input++;
		void *peek, *get;
		switch(*val) {
			case GET:
				peek = prio_queue_peek(&pq);
				get = prio_queue_get(&pq);
				if (peek != get)
					BUG("peek and get results don't match");
				result[i++] = show(get);
				break;
			case DUMP:
				while ((peek = prio_queue_peek(&pq))) {
					get = prio_queue_get(&pq);
					if (peek != get)
						BUG("peek and get results don't match");
					result[i++] = show(get);
				}
				break;
			case STACK:
				pq.compare = NULL;
				break;
			case REVERSE:
				prio_queue_reverse(&pq);
				break;
			default:
				prio_queue_put(&pq, val);
				break;
		}
	}
	clear_prio_queue(&pq);
	return 0;
}

#define BASIC_INPUT 1, 2, 3, 4, 5, 5, DUMP
#define BASIC_EXPECTED 1, 2, 3, 4, 5, 5

#define MIXED_PUT_GET_INPUT 6, 2, 4, GET, 5, 3, GET, GET, 1, DUMP
#define MIXED_PUT_GET_EXPECTED 2, 3, 4, 1, 5, 6

#define EMPTY_QUEUE_INPUT 1, 2, GET, GET, GET, 1, 2, GET, GET, GET
#define EMPTY_QUEUE_EXPECTED 1, 2, MISSING, 1, 2, MISSING

#define STACK_INPUT STACK, 1, 5, 4, 6, 2, 3, DUMP
#define STACK_EXPECTED 3, 2, 6, 4, 5, 1

#define REVERSE_STACK_INPUT STACK, 1, 2, 3, 4, 5, 6, REVERSE, DUMP
#define REVERSE_STACK_EXPECTED 1, 2, 3, 4, 5, 6

#define TEST_INPUT(INPUT, EXPECTED, name)			\
  static void test_##name(void)				\
{								\
	int input[] = {INPUT};					\
	int expected[] = {EXPECTED};				\
	int result[ARRAY_SIZE(expected)];			\
	test_prio_queue(input, result);				\
	check(!memcmp(expected, result, sizeof(expected)));	\
}

TEST_INPUT(BASIC_INPUT, BASIC_EXPECTED, basic)
TEST_INPUT(MIXED_PUT_GET_INPUT, MIXED_PUT_GET_EXPECTED, mixed)
TEST_INPUT(EMPTY_QUEUE_INPUT, EMPTY_QUEUE_EXPECTED, empty)
TEST_INPUT(STACK_INPUT, STACK_EXPECTED, stack)
TEST_INPUT(REVERSE_STACK_INPUT, REVERSE_STACK_EXPECTED, reverse)

int cmd_main(int argc, const char **argv)
{
	TEST(test_basic(), "prio-queue works for basic input");
	TEST(test_mixed(), "prio-queue works for mixed put & get commands");
	TEST(test_empty(), "prio-queue works when queue is empty");
	TEST(test_stack(), "prio-queue works when used as a LIFO stack");
	TEST(test_reverse(), "prio-queue works when LIFO stack is reversed");

	return test_done();
}
