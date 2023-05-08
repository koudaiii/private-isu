#!/bin/bash

# データベースの初期データを用意する
if [ ! -f "webapp/sql/dump.sql.bz2" ]; then
  cd webapp/sql
  curl -L -O https://github.com/catatsuy/private-isu/releases/download/img/dump.sql.bz2
  bunzip2 dump.sql.bz2
fi
