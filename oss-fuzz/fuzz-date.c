#include "git-compat-util.h"
#include "date.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	int local;
	int num;
	uint16_t tz;
	char *str;
	timestamp_t ts;
	enum date_mode_type dmtype;
	struct date_mode *dm;

	if (size <= 4)
		/*
		 * we use the first byte to fuzz dmtype and local,
		 * then the next three bytes to fuzz tz	offset,
		 * and the remainder (at least one byte) is fed
		 * as end-user input to approxidate_careful().
		 */
		return 0;

	local = !!(*data & 0x10);
	dmtype = (enum date_mode_type)(*data % DATE_UNIX);
	if (dmtype == DATE_STRFTIME)
		/*
		 * Currently DATE_STRFTIME is not supported.
		 */
		return 0;
	data++;
	size--;

	tz = *data++;
	tz = (tz << 8) | *data++;
	tz = (tz << 8) | *data++;
	size -= 3;

	str = (char *)malloc(size + 1);
	if (!str)
		return 0;
	memcpy(str, data, size);
	str[size] = '\0';

	ts = approxidate_careful(str, &num);
	free(str);

	dm = date_mode_from_type(dmtype);
	dm->local = local;
	show_date(ts, (int16_t)tz, dm);

	date_mode_release(dm);

	return 0;
}
