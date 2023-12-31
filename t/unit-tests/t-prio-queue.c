#include "test-lib.h"
#include "prio-queue.h"

static int intcmp(const void *va, const void *vb, void *data UNUSED)
{
	const int *a = va, *b = vb;
	return *a - *b;
}

static int show(int *v)
{
	int ret = -1;
	if (v)
		ret = *v;
	free(v);
	return ret;
}

static int test_prio_queue(const char **input, int *result)
{
	struct prio_queue pq = { intcmp };
	int i = 0;

	while (*input) {
		if (!strcmp(*input, "get")) {
			void *peek = prio_queue_peek(&pq);
			void *get = prio_queue_get(&pq);
			if (peek != get)
				BUG("peek and get results do not match");
			result[i++] = show(get);
		} else if (!strcmp(*input, "dump")) {
			void *peek;
			void *get;
			while ((peek = prio_queue_peek(&pq))) {
				get = prio_queue_get(&pq);
				if (peek != get)
					BUG("peek and get results do not match");
				result[i++] = show(get);
			}
		} else if (!strcmp(*input, "stack")) {
			pq.compare = NULL;
		} else if (!strcmp(*input, "reverse")) {
			prio_queue_reverse(&pq);
		} else {
			int *v = xmalloc(sizeof(*v));
			*v = atoi(*input);
			prio_queue_put(&pq, v);
		}
		input++;
	}

	clear_prio_queue(&pq);

	return 0;
}

#define INPUT_SIZE 6

#define BASIC_INPUT "1", "2", "3", "4", "5", "5", "dump"
#define BASIC_EXPECTED 1, 2, 3, 4, 5, 5

#define MIXED_PUT_GET_INPUT "6", "2", "4", "get", "5", "3", "get", "get", "1", "dump"
#define MIXED_PUT_GET_EXPECTED 2, 3, 4, 1, 5, 6

#define EMPTY_QUEUE_INPUT "1", "2", "get", "get", "get", "1", "2", "get", "get", "get"
#define EMPTY_QUEUE_EXPECTED 1, 2, -1, 1, 2, -1

#define STACK_INPUT "stack", "1", "5", "4", "6", "2", "3", "dump"
#define STACK_EXPECTED 3, 2, 6, 4, 5, 1

#define REVERSE_STACK_INPUT "stack", "1", "2", "3", "4", "5", "6", "reverse", "dump"
#define REVERSE_STACK_EXPECTED 1, 2, 3, 4, 5, 6

#define TEST_INPUT(INPUT, EXPECTED, name)			\
  static void test_##name(void)					\
{								\
	const char *input[] = {INPUT};				\
	int expected[] = {EXPECTED};				\
	int result[INPUT_SIZE];					\
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
