#if not defined("DB_NAME")
#define DB_NAME banking
#endif

#include "utils/main.sql"

#include "common/error.sql"
#include "common/status.sql"

#include "constants.sql"
#include "types.sql"

#include "accounts.sql"
#include "black_list.sql"
#include "journal.sql"
#include "payments.sql"
#include "statistics.sql"
#include "withdraw_queue.sql"
#include "utils/changelog.sql"
