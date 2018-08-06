-- https://github.com/WhyAskWhy/mysql2sqlite
-- https://github.com/WhyAskWhy/mysql2sqlite-dev

-- Create db user
GRANT SELECT,LOCK TABLES ON mailserver.*
    TO 'mysql2sqlite'@'127.0.0.1'
    IDENTIFIED BY 'qwerty';

FLUSH PRIVILEGES;
