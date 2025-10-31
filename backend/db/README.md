```bash
# Make sure you are running this in your command-line shell, not the psql prompt
DROPDB -U suragch converter
CREATEDB -U suragch -O suragch converter

# Load the variables from the .env file into your shell session
export $(grep -v '^#' .env | xargs)

# Make sure you are in the same directory as your .env file
source .env && psql -U suragch -d converter -f db/init.sql -v db_user_password="$DB_APP_USER_PASSWORD"

psql -U suragch -d converter
```

```sql
-- List users
\du

-- List databases
\l

-- List tables
\dt

exit
```

