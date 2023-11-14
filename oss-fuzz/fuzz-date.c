#include "git-compat-util.h"
#include "date.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	int local;
	int num;
	int tz;
	char *str;
	int8_t *tmp_data;
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
	num = *data % DATE_UNIX;
	if (num >= DATE_STRFTIME)
		num++;
	dmtype = (enum date_mode_type)num;
	data++;
	size--;

	tmp_data = (int8_t*)data;
	tz = *tmp_data++;
	tz = (tz << 8) | *tmp_data++;
	tz = (tz << 8) | *tmp_data++;
	data += 3;
	size -= 3;

	str = xmemdupz(data, size);

	ts = approxidate_careful(str, &num);
	free(str);

	dm = date_mode_from_type(dmtype);
	dm->local = local;
	show_date(ts, tz, dm);

	date_mode_release(dm);

	return 0;
}
