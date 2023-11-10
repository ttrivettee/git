#include "git-compat-util.h"
#include "date.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	int type;
	int time;
	int num;
	char *str;
	timestamp_t ts;
	enum date_mode_type dmtype;
	struct date_mode *dm;

	if (size <= 8)
	{
		return 0;
	}

	type = (*((int *)data)) % 8;
	data += 4;
	size -= 4;

	time = abs(*((int *)data));
	data += 4;
	size -= 4;

	str = (char *)malloc(size+1);
	if (!str)
	{
		return 0;
	}
	memcpy(str, data, size);
	str[size] = '\0';

	ts = approxidate_careful(str, &num);
	free(str);

	switch(type)
	{
		case 0: default:
			dmtype = DATE_NORMAL;
			break;
		case 1:
			dmtype = DATE_HUMAN;
			break;
		case 2:
			dmtype = DATE_SHORT;
			break;
		case 3:
			dmtype = DATE_ISO8601;
			break;
		case 4:
			dmtype = DATE_ISO8601_STRICT;
			break;
		case 5:
			dmtype = DATE_RFC2822;
			break;
		case 6:
			dmtype = DATE_RAW;
			break;
		case 7:
			dmtype = DATE_UNIX;
			break;
	}

	dm = date_mode_from_type(dmtype);
	dm->local = 1;
	show_date(ts, time, dm);

	date_mode_release(dm);

	return 0;
}
