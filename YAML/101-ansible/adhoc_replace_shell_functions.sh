$ vi adhoc_replace_shell_functions.sh
#!/bin/bash
if $(ansible localhost, -m ping)
then
  ansible localhost, -m copy -a "dest=/var/www/html/index.html, content='This is World'"
else
  ansible localhost, -m copy -a "dest=/root/README.md, content='This file is wrong'"
fi
