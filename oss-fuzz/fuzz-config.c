#include "git-compat-util.h"
#include "config.h"

#include <stdio.h>
#include <string.h>

int LLVMFuzzerTestOneInput(const uint8_t *, size_t);
static int config_parser_callback(const char *, const char *,
					const struct config_context *, void *);

static int config_parser_callback(const char *key, const char *value,
					const struct config_context *ctx UNUSED,
					void *data UNUSED)
{
	/* Visit every byte of memory we are given to make sure the parser
	 * gave it to us appropriately. Ensure a return of 0 to indicate
	 * success so the parsing continues. */
	int c = strlen(key);
	if (value)
		c += strlen(value);
	return c < 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, const size_t size)
{
	struct config_options config_opts = { 0 };
	config_opts.error_action = CONFIG_ERROR_SILENT;
	git_config_from_mem(config_parser_callback, CONFIG_ORIGIN_BLOB,
				"fuzztest-config", (const char *)data, size, NULL,
				CONFIG_SCOPE_UNKNOWN, &config_opts);
	return 0;
}
